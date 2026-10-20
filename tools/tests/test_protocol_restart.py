import importlib
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from tools.harness import restarting
from tools.harness.protocol import Client, OwnerLock, ProtocolError, atomic_json
from tools.tests.test_protocol_captures import png

runner = importlib.import_module('tools.harness.run')


class MailboxProcess:
    """Host protocol producer test double, not a Playdate/game implementation."""
    counter = 0
    instances = []
    ready_enabled = True
    fail_generation = None
    pending_generation = None
    tamper_generation = None

    def __init__(self, command, stdout, stderr):
        type(self).counter += 1
        self.generation = type(self).counter
        if self.generation == self.fail_generation:
            raise OSError('controlled launch failure')
        self.pid = 10000 + self.generation
        self.command = command
        self.returncode = None
        self.stop = threading.Event()
        self.events = []
        self.errors = []
        self.thread = threading.Thread(target=self.serve)
        type(self).instances.append(self)
        self.thread.start()

    def envelope(self, **values):
        return dict(protocol=1, build_id='build', session_id='session', **values)

    def serve(self):
        try:
            if self.generation == self.tamper_generation:
                (self.data / 'adventure.a.json').write_bytes(b'unexpected boot mutation')
            if self.generation == 1 or self.ready_enabled:
                atomic_json(self.data / 'ready.json', self.envelope(status='ready', tick=1))
            seen = set()
            while not self.stop.wait(.002):
                request_path = self.data / 'request.json'
                if not request_path.exists():
                    continue
                request = json.loads(request_path.read_text())
                if request['id'] in seen:
                    continue
                seen.add(request['id'])
                if self.generation == self.pending_generation:
                    # Deliberately ignore both request and cancel: poisoned client.
                    continue
                commands = request['commands']
                for command in commands:
                    if command == 'write-save':
                        (self.data / 'adventure.a.json').write_bytes(b'exact durable save\x00\xff')
                    if command == 'shot repeated':
                        (self.output / 'frames/repeated.png').write_bytes(png())
                        (self.output / 'frames/repeated-display.png').write_bytes(png())
                with (self.data / 'trace.jsonl').open('a') as trace:
                    trace.write(json.dumps({'process':self.generation, 'id':request['id']}) + '\n')
                quiescent = commands == ['quiesce']
                if quiescent:
                    atomic_json(self.data / 'captures-final.json', self.envelope(quiescent=True, captures=[], capture_count=0, recent_frames=[], recent_count=0))
                atomic_json(self.data / 'result.json', self.envelope(id=request['id'], status='ok',
                    results=[{'command':i+1,'status':'ok'} for i in range(len(commands))], snapshot={}, quiescent=quiescent))
        except BaseException as error:
            self.errors.append(error)

    def poll(self): return self.returncode
    def terminate(self): self.events.append('terminate'); self.stop.set()
    def kill(self): self.events.append('kill'); self.stop.set()
    def wait(self, timeout):
        self.thread.join(timeout)
        if self.thread.is_alive(): raise subprocess.TimeoutExpired(self.command, timeout)
        self.events.append('exit-confirmed'); self.returncode = -15
        return self.returncode


class RestartTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name);self.data = self.root / 'data';self.data.mkdir()
        self.output = self.root / 'output';self.output.mkdir();(self.output / 'frames').mkdir()
        self.owner = OwnerLock(self.data / 'owner.lock');self.owner.__enter__();self.addCleanup(self.owner.__exit__)
        self.args = SimpleNamespace(timeout=.25,max_frames=1800,ready_timeout=.1)
        self.metadata = {'build_id':'build','session_id':'session','simulator':'owned-simulator','bundle':'same-private.pdx'}
        MailboxProcess.counter=0;MailboxProcess.instances=[];MailboxProcess.ready_enabled=True
        MailboxProcess.fail_generation=None;MailboxProcess.pending_generation=None;MailboxProcess.tamper_generation=None
        MailboxProcess.data=self.data;MailboxProcess.output=self.output

    def run_job(self, groups):
        scenario={'processes':groups};restarting.validate(scenario)
        with patch.object(restarting.subprocess,'Popen',MailboxProcess):
            result=restarting.run(self.args,scenario,self.metadata,self.output,self.data,self.owner,runner)
        for process in MailboxProcess.instances:
            self.assertFalse(process.thread.is_alive());self.assertEqual(process.errors,[])
        return result

    def test_explicit_schema_rejects_ambiguous_or_unbounded_jobs(self):
        valid={'processes':[{'requests':[['snapshot']]},{'restart':True,'requests':[['snapshot']]}]}
        restarting.validate(valid)
        for scenario in ({'processes':[]},{'processes':[{'requests':[['x']]}]*9},
                         dict(valid,commands=['x']),{'processes':[{'restart':True,'requests':[['x']]},{'requests':[['x']]}]},
                         {'processes':[{'requests':[['x']]},{'restart':True,'requests':[['x']],'outputs':['../bad']}] }):
            with self.assertRaises(ProtocolError):restarting.validate(scenario)
        with self.assertRaises(ProtocolError):restarting.validate(valid,qualification=True)

    def test_clear_handshake_cannot_accept_stale_ready_and_preserves_saves(self):
        save=self.data/'adventure.a.json';save.write_bytes(b'original\0save')
        atomic_json(self.data/'ready.json',dict(protocol=1,build_id='build',session_id='session',status='ready'))
        (self.data/'result.json.tmp').write_text('old');(self.data/'trace.jsonl').write_text('old trace\n')
        before=restarting.durable_hashes(self.data)
        restarting.clear_handshake(self.data,self.owner)
        self.assertEqual(restarting.durable_hashes(self.data),before);self.assertEqual(save.read_bytes(),b'original\0save')
        self.assertTrue((self.data/'trace.jsonl').exists())
        client=Client(self.data,'build','session',self.output,owner=self.owner)
        with self.assertRaisesRegex(ProtocolError,'handshake timed out'):client.ready(.01)

    def test_owner_required_before_signal_or_cleanup(self):
        class Unowned:
            path=self.data/'other.lock'
            stream=None
        class Untouchable:
            def poll(self):raise AssertionError('must not inspect/signal unowned process')
        with self.assertRaises(ProtocolError):restarting.stop_owned(Untouchable(),Unowned(),self.data)
        with self.assertRaises(ProtocolError):restarting.clear_handshake(self.data,Unowned())
        with self.assertRaises(ProtocolError):
            with OwnerLock(self.data/'owner.lock'):pass

    def test_runner_retains_private_data_if_owned_exit_is_unconfirmed(self):
        scenario=self.root/'scenario.json'
        scenario.write_text(json.dumps({'processes':[{'requests':[['snapshot']]},{'restart':True,'requests':[['snapshot']]}]}))
        data=self.root/'retained-data'
        metadata=dict(self.metadata,data_dir=str(data))
        args=SimpleNamespace(sdk=None,output=str(self.root/'retained-output'),scenario=str(scenario),commands=[],build_only=False)
        with patch.object(runner,'sdk_path',return_value=self.root), patch.object(runner,'prepare',return_value=metadata), \
             patch.object(restarting,'run',side_effect=restarting.UnconfirmedExit('controlled unconfirmed exit')):
            with self.assertRaises(restarting.UnconfirmedExit):runner._run(args)
        self.assertTrue(data.is_dir())
        with OwnerLock(data/'owner.lock'):pass

    def test_unconfirmed_owned_exit_fails_without_signalling_another_process(self):
        class Stuck:
            returncode=None
            def __init__(self):self.events=[]
            def poll(self):return None
            def terminate(self):self.events.append('terminate')
            def kill(self):self.events.append('kill')
            def wait(self,timeout):raise subprocess.TimeoutExpired('owned',timeout)
        process=Stuck()
        with self.assertRaises(restarting.UnconfirmedExit):restarting.stop_owned(process,self.owner,self.data)
        self.assertEqual(process.events,['terminate','kill'])

    def test_symlink_protocol_substitution_is_rejected(self):
        original=self.root/'original';original.write_text('retained')
        (self.data/'ready.json').symlink_to(original)
        with self.assertRaisesRegex(ProtocolError,'invalid transient'):restarting.clear_handshake(self.data,self.owner)
        self.assertEqual(original.read_text(),'retained')

    def test_two_generations_keep_save_lock_ids_frames_and_trace(self):
        result=self.run_job([{'requests':[['write-save','shot repeated']]},
                             {'restart':True,'requests':[['snapshot','shot repeated']]}])
        self.assertEqual(result,0)
        self.assertEqual((self.data/'adventure.a.json').read_bytes(),b'exact durable save\x00\xff')
        records=json.loads((self.output/'run.json').read_text())['processes']
        self.assertEqual([r['pid'] for r in records],[10001,10002])
        self.assertTrue(all(r['fresh_ready'] and r['previous_exit_confirmed'] for r in records))
        ids=[]
        for generation in (1,2):
            directory=self.output/'processes'/f'{generation:04d}'
            self.assertEqual((directory/'frames/repeated.png').read_bytes(),png())
            self.assertTrue((directory/'captures.json').exists())
            trace=[json.loads(line) for line in (directory/'trace.jsonl').read_text().splitlines()]
            self.assertTrue(all(row['process']==generation for row in trace))
            requests=[json.loads(p.read_text()) for p in sorted(directory.glob('*-request.json'))]
            ids += [row['id'] for row in requests]
        self.assertEqual(len(ids),4);self.assertEqual(len(set(ids)),4)
        self.assertTrue(ids[2].startswith('00003-'))
        self.assertTrue(all(p.command==['owned-simulator','same-private.pdx'] for p in MailboxProcess.instances))
        self.assertTrue(all(p.events==['terminate','exit-confirmed'] for p in MailboxProcess.instances))
        self.assertFalse(self.owner.stream.closed)

    def test_failed_second_launch_retains_first_evidence_and_save(self):
        MailboxProcess.fail_generation=2
        self.assertEqual(self.run_job([{'requests':[['write-save','shot repeated']]},
                                       {'restart':True,'requests':[['snapshot']]}]),1)
        outcome=json.loads((self.output/'outcome.json').read_text())
        self.assertIn('controlled launch failure',outcome['error'])
        self.assertTrue((self.output/'processes/0001/frames/repeated.png').exists())
        self.assertTrue((self.output/'processes/0002/runtime-data/adventure.a.json').exists())

    def test_no_fresh_ready_does_not_reuse_prior_handshake(self):
        MailboxProcess.ready_enabled=False
        self.assertEqual(self.run_job([{'requests':[['write-save']]},{'restart':True,'requests':[['snapshot']]}]),1)
        self.assertIn('ready handshake timed out',json.loads((self.output/'outcome.json').read_text())['error'])
        self.assertFalse((self.output/'processes/0002/ready.json').exists())
        self.assertTrue((self.data/'adventure.a.json').exists())

    def test_unexpected_boot_save_mutation_fails_and_retains_old_evidence(self):
        MailboxProcess.tamper_generation=2
        self.assertEqual(self.run_job([{'requests':[['write-save']]},{'restart':True,'requests':[['snapshot']]}]),1)
        self.assertIn('boot changed durable files',json.loads((self.output/'outcome.json').read_text())['error'])
        self.assertEqual((self.output/'processes/0001/runtime-data/adventure.a.json').read_bytes(),b'exact durable save\x00\xff')

    def test_unconfirmed_cancellation_stops_owned_runtime_without_recovery_or_restart(self):
        MailboxProcess.pending_generation=1
        self.assertEqual(self.run_job([{'requests':[['snapshot']]},{'restart':True,'requests':[['snapshot']]}]),1)
        self.assertEqual(len(MailboxProcess.instances),1)
        self.assertTrue((self.output/'processes/0001/runtime-data/cancel.json').exists())
        requests=list((self.output/'processes/0001').glob('*-request.json'))
        self.assertEqual(len(requests),1)
        self.assertIn('cancellation unconfirmed',json.loads((self.output/'outcome.json').read_text())['error'])


if __name__=='__main__':unittest.main()
