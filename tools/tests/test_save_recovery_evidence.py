"""Offline tests of independent native-evidence qualification, not a fake SDK."""
import json
from pathlib import Path
import tempfile
import unittest
from tools.harness import save_recovery_evidence as evidence


def encoded(value):return json.dumps(value,separators=(',',':'),ensure_ascii=True).encode()
def sidecar(value):
    payload=encoded(value).decode()
    return encoded({'format':'pokemon-playdate-save-archive','version':1,'payload':payload,'checksum':evidence.fnv(payload.encode())})
def desc(raw):return {'present':raw is not None,'length':len(raw)if raw is not None else 0,'checksum':evidence.fnv(raw)if raw is not None else '00000000'}


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        payload=encoded({'fixture':'host evidence-validator unit case; not a runtime session'}).decode()
        self.proposal=encoded({'format':'pokemon-playdate-save','schema':1,'sequence':'1','payload':payload,
                               'checksum':evidence.fnv(b'1\n1\n'+payload.encode())})
        self.manifest={'index':'1','mode':'replacement','target':'a','roles':{role:desc(raw)for role,raw in evidence.SEED.items()},'proposal':desc(self.proposal)}
        for role,raw in evidence.SEED.items():(self.root/('adventure-archive-1.'+role+'.json')).write_bytes(raw)
        (self.root/'adventure-archive-1.proposal.json').write_bytes(self.proposal)
        (self.root/'adventure.a.json').write_bytes(self.proposal)
        (self.root/'adventure.b.json').write_bytes(evidence.SEED['b'])
        self.publish_manifest()
    def publish_manifest(self):
        manifest=sidecar(self.manifest)
        (self.root/'adventure-archive-1.manifest.json').write_bytes(manifest)
        (self.root/'adventure-archive-1.receipt.json').write_bytes(sidecar({'index':'1','manifestChecksum':evidence.fnv(manifest),'proposalChecksum':evidence.fnv(self.proposal)}))
    def verify(self):return evidence.verify_archive(self.root,expected=evidence.SEED)
    def test_known_fnv_vectors_and_exact_binary_archive(self):
        for raw,expected in [(b'','811c9dc5'),(b'a','e40c292c'),(b'foobar','bf9cf968')]:self.assertEqual(evidence.fnv(raw),expected)
        self.assertEqual(self.verify()['archive_index'],1)
    def test_every_raw_role_corruption_is_rejected(self):
        for role in evidence.ROLES:
            with self.subTest(role=role):
                path=self.root/('adventure-archive-1.'+role+'.json');old=path.read_bytes();path.write_bytes(old+b'!')
                with self.assertRaises(ValueError):self.verify()
                path.write_bytes(old)
    def test_receipt_missing_and_binary_corruption_rejected(self):
        path=self.root/'adventure-archive-1.receipt.json';path.write_bytes(b'\xff\x00')
        with self.assertRaises(UnicodeDecodeError):self.verify()
        path.unlink()
        with self.assertRaises(FileNotFoundError):self.verify()
    def test_unknown_fields_and_derived_path_target_are_rejected(self):
        for field,value in [('path','../outside'),('index','01'),('target','../a')]:
            with self.subTest(field=field):
                before=dict(self.manifest);self.manifest[field]=value;self.publish_manifest()
                with self.assertRaises(ValueError):self.verify()
                self.manifest=before
    def test_descriptor_bounds_preserved_even_with_fresh_checksums(self):
        self.manifest['roles']['b']['length']=1048577;self.publish_manifest()
        with self.assertRaises(ValueError):self.verify()
    def test_unknown_new_primary_leftover_is_never_archived_authority(self):
        (self.root/'adventure.b.json').write_bytes(b'new unknown corruption')
        with self.assertRaisesRegex(ValueError,'unknown leftover'):self.verify()
    def test_proposal_must_be_exact_planned_published_bytes(self):
        (self.root/'adventure.a.json').write_bytes(self.proposal+b' ')
        with self.assertRaisesRegex(ValueError,'planned target'):self.verify()
    def test_receipt_manifest_and_proposal_binding(self):
        (self.root/'adventure-archive-1.receipt.json').write_bytes(sidecar({'index':'1','manifestChecksum':'00000000','proposalChecksum':evidence.fnv(self.proposal)}))
        with self.assertRaisesRegex(ValueError,'receipt binding'):self.verify()
    def test_payload_checksum_remains_independent_of_sidecar_checksums(self):
        raw=json.loads(self.proposal);raw['payload']='{}';self.proposal=encoded(raw)
        (self.root/'adventure-archive-1.proposal.json').write_bytes(self.proposal)
        self.manifest['proposal']=desc(self.proposal);self.publish_manifest()
        with self.assertRaisesRegex(ValueError,'save checksum'):self.verify()
    def test_duplicate_json_fields_and_decimal_overflow_are_rejected(self):
        with self.assertRaisesRegex(ValueError,'duplicate'):evidence.decode(b'{"a":1,"a":2}')
        for value in ['01','+1','1.0','2147483648',1,True]:
            with self.subTest(value=value):
                with self.assertRaises(ValueError):evidence.decimal(value,1,2147483647)


class EnvelopeHeaderTests(unittest.TestCase):
    def make(self,payload=None,**changes):
        text=encoded({'ok':True}).decode() if payload is None else payload
        value={'format':'pokemon-playdate-save','schema':1,'sequence':'1','payload':text,
               'checksum':evidence.fnv(b'1\n1\n'+text.encode())if isinstance(text,str)else '00000000'}
        value.update(changes)
        return encoded(value)
    def test_boolean_schema_is_not_integer_one_even_with_normal_checksum(self):
        for schema in (True,False,1.0,'1',None,2):
            with self.subTest(schema=schema):
                with self.assertRaisesRegex(ValueError,'save schema'):evidence.envelope(self.make(schema=schema))
    def test_exact_envelope_fields_unknown_and_missing(self):
        value=json.loads(self.make())
        for field in value:
            bad=dict(value);del bad[field]
            with self.subTest(missing=field):
                with self.assertRaisesRegex(ValueError,'unexpected object fields'):evidence.envelope(encoded(bad))
        value['unknown']='not silently accepted'
        with self.assertRaisesRegex(ValueError,'unexpected object fields'):evidence.envelope(encoded(value))
    def test_non_string_payloads_raise_controlled_value_error(self):
        for payload in (True,1,1.5,{},[],None):
            value=json.loads(self.make());value['payload']=payload
            with self.subTest(payload=payload):
                with self.assertRaisesRegex(ValueError,'save payload type'):evidence.envelope(encoded(value))
    def test_file_limit_is_bytes_and_inclusive(self):
        valid=self.make();padded=valid+b' '*(1048576-len(valid))
        self.assertEqual(evidence.envelope(padded),{'ok':True})
        with self.assertRaisesRegex(ValueError,'save file bound'):evidence.envelope(padded+b' ')
        for invalid in (b'',None,'not bytes'):
            with self.assertRaisesRegex(ValueError,'save file bound'):evidence.envelope(invalid)
    def test_payload_limit_is_utf8_bytes_and_inclusive(self):
        text='{"padding":"'+'x'*(262144-len('{"padding":""}'))+'"}'
        self.assertEqual(len(text.encode()),262144);self.assertEqual(len(evidence.envelope(self.make(text))['padding']),len(text)-14)
        with self.assertRaisesRegex(ValueError,'save payload bound'):evidence.envelope(self.make(text+' '))
        unicode_text='{"padding":"'+'é'*131067+'"}'
        with self.assertRaisesRegex(ValueError,'save payload bound'):evidence.envelope(self.make(unicode_text))
    def test_payload_json_primitives_match_generic_store_bounds(self):
        for text in ('null','true','1','"a"','{"value":null}','{"n":2147483648}','{"n":-2147483648}','{"n":NaN}','{"n":'+('9'*1000)+'}'):
            with self.subTest(payload=text):
                with self.assertRaises(ValueError):evidence.envelope(self.make(text))
        self.assertEqual(evidence.envelope(self.make('{"n":2147483647,"m":-2147483647}')),{'n':2147483647,'m':-2147483647})
    def test_checksum_stays_bound_to_exact_schema_sequence_payload(self):
        raw=json.loads(self.make());raw['sequence']='2'
        with self.assertRaisesRegex(ValueError,'save checksum'):evidence.envelope(encoded(raw))
        raw=json.loads(self.make());raw['payload']+=' '
        with self.assertRaisesRegex(ValueError,'save checksum'):evidence.envelope(encoded(raw))

if __name__=='__main__':unittest.main()
