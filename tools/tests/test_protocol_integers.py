import json
import math
from pathlib import Path
import tempfile
import threading
import time
import unittest

from tools.harness.protocol import (Client, ProtocolError, INT32_TAG, INT32_MIN,
    INT32_MAX, EXACT_SMALL_INTEGER_LIMIT, atomic_json, encode_commands, encode_wire_values)


class IntegerWireTests(unittest.TestCase):
    def test_signed_boundaries_and_inclusive_float32_cutoff(self):
        limit = EXACT_SMALL_INTEGER_LIMIT
        for value in (INT32_MIN, INT32_MIN+1, -limit-1, -limit, limit, limit+1, INT32_MAX):
            with self.subTest(value=value):
                self.assertEqual(encode_wire_values(value), {INT32_TAG:str(value)})
        for value in (-limit+1, -1, 0, 1, limit-1):
            self.assertEqual(encode_wire_values(value), value)

    def test_bool_string_list_and_nested_objects_keep_types(self):
        source={'normal':'2147483647','flag':True,'off':False,'nil':None,
                'nested':[INT32_MAX, {'equals':INT32_MIN}, 3, 1.5]}
        expected={'normal':'2147483647','flag':True,'off':False,'nil':None,
                  'nested':[{INT32_TAG:str(INT32_MAX)}, {'equals':{INT32_TAG:str(INT32_MIN)}},3,1.5]}
        self.assertEqual(encode_wire_values(source),expected)
        self.assertIs(encode_wire_values(True),True)
        self.assertIs(encode_wire_values(False),False)
        self.assertEqual(source['nested'][0],INT32_MAX) # no caller mutation

    def test_out_of_native_bounds_and_nonfinite_values_reject(self):
        for value in (INT32_MIN-1, INT32_MAX+1, 1<<63, -(1<<63), math.nan, math.inf, -math.inf):
            with self.subTest(value=value), self.assertRaises(ProtocolError):
                encode_wire_values({'nested':[value]})
        for value in (float(1<<24), -float(1<<24), float(INT32_MAX)):
            with self.assertRaisesRegex(ProtocolError,'floating'):
                encode_wire_values(value)

    def test_reserved_tag_collisions_and_unknown_versions_fail_closed(self):
        for value in ({INT32_TAG:'1'}, {INT32_TAG:1}, {INT32_TAG:'1','extra':False},
                      {'__harness_int32_v2':'1'}, {'nested':[{INT32_TAG:'2147483648'}]}):
            with self.subTest(value=value), self.assertRaisesRegex(ProtocolError,'reserved'):
                encode_wire_values(value)
        self.assertEqual(encode_wire_values(INT32_TAG),INT32_TAG)
        with self.assertRaisesRegex(ProtocolError,'keys must be strings'):
            encode_wire_values({1:'bad'})

    def test_fixture_and_seed_args_never_coerce_float_bool_or_text(self):
        for seed in (1.0,1.5,True,False,'42',None):
            with self.subTest(seed=seed), self.assertRaisesRegex(ProtocolError,'native Python integer'):
                encode_commands([{'op':'fixture','options':{'seed':seed}}])
        for seed in (1.0,1.5,True,False,None):
            with self.assertRaisesRegex(ProtocolError,'seed argument'):
                encode_commands([{'op':'seed','args':[seed]}])
        self.assertEqual(encode_commands(['seed -2147483648']),['seed -2147483648'])
        self.assertEqual(encode_commands([{'op':'seed','args':['-2147483648']}]),[{'op':'seed','args':['-2147483648']}])

    def test_sender_records_actual_wire_and_keeps_ownership_barriers(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);data=root/'data';evidence=root/'evidence'
            source=[{'op':'fixture','options':{'seed':INT32_MIN}},
                    {'op':'assert','path':'rng.state','equals':INT32_MAX}]
            with Client(data,'build','session',evidence) as client:
                errors=[]
                def peer():
                    try:
                        deadline=time.monotonic()+2
                        while not (data/'request.json').exists():
                            if time.monotonic()>deadline: raise AssertionError('no wire packet')
                            time.sleep(.005)
                        request=json.loads((data/'request.json').read_text())
                        saved=json.loads((evidence/'00001-request.json').read_text())
                        self.assertEqual(saved,request)
                        self.assertEqual(request['commands'][0]['options']['seed'],{INT32_TAG:str(INT32_MIN)})
                        self.assertEqual(request['commands'][1]['equals'],{INT32_TAG:str(INT32_MAX)})
                        self.assertEqual(request['build_id'],'build')
                        self.assertEqual(request['session_id'],'session')
                        atomic_json(data/'result.json',client.envelope(id=request['id'],status='ok',
                            results=[{'command':1,'status':'ok'},{'command':2,'status':'ok'}],snapshot={}))
                    except BaseException as error:
                        errors.append(error)
                thread=threading.Thread(target=peer);thread.start()
                try: client.send(source,timeout=2)
                finally: thread.join(3)
                self.assertEqual(errors,[])
                self.assertEqual(source[0]['options']['seed'],INT32_MIN)
                self.assertIsNone(client._pending_id)

    def test_bad_outgoing_value_has_no_partial_request_or_pending_command(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            with Client(root/'data','build','session',root/'evidence') as client:
                with self.assertRaises(ProtocolError):
                    client.send([{'op':'fixture','options':{'seed':INT32_MAX+1}}])
                self.assertFalse((root/'data/request.json').exists())
                self.assertFalse((root/'evidence').exists())
                self.assertEqual(client.sequence,0)
                self.assertIsNone(client._pending_id)
                with self.assertRaisesRegex(ProtocolError,'max_frames'):
                    client.send(['snapshot'],max_frames=1800.0)
                self.assertIsNone(client._pending_id)
