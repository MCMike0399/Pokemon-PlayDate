"""Real-SDK integer wire proof; called only by the root-owned runner."""
import json
from pathlib import Path
import time
import uuid

from tools.harness.protocol import ProtocolError, atomic_json, INT32_TAG


def run(client, output, sdk):
    output = Path(output)
    report = {'ok':True,'tests':[]}
    def case(name, action):
        try:
            value = action()
        except BaseException as error:
            report['ok']=False
            report['tests'].append({'name':name,'ok':False,'error':str(error)})
            atomic_json(output/'integer-qualification.json',report)
            raise
        report['tests'].append({'name':name,'ok':True,'detail':value})
        atomic_json(output/'integer-qualification.json',report)
    def seed_case(seed, command=None):
        modulus_minus_one=2147483646
        expected=seed % modulus_minus_one
        if expected<=0:expected+=modulus_minus_one
        commands=[command or {'op':'fixture','options':{'seed':seed}},
                  {'op':'assert','path':'rng.seed','equals':expected},
                  {'op':'assert','path':'rng.state','equals':expected},
                  {'op':'assert','path':'rng.rolls','equals':0}]
        result=client.send(commands)
        exact=result['rng_data']
        assert exact['seed']==str(expected) and exact['state']==str(expected) and exact['rolls']=='0',exact
        return {'input_seed':str(seed),'exact_rng':exact,'request_id':result['id']}
    for seed in (2147483647,-2147483648,-2147483647,16777216,16777217,-16777216,-16777217):
        case('exact fixture seed '+str(seed),lambda seed=seed:seed_case(seed))
    for seed in (2147483647,-2147483648):
        case('exact legacy seed text '+str(seed),lambda seed=seed:seed_case(seed,'seed '+str(seed)))
    case('exact structured seed argument',lambda:seed_case(-2147483648,{'op':'seed','args':[-2147483648]}))

    def reject_raw(label, bad_value):
        # Prove all malformed values reject BEFORE the preceding fixture can run.
        client.send([{'op':'fixture','options':{'seed':37}}])
        assert client._pending_id is None
        client._check_owner()
        request_id='integer-probe-'+uuid.uuid4().hex
        bad_command='{"op":"assert","path":"rng.state","equals":'+bad_value+'}'
        commands='[{"op":"fixture","options":{"seed":42}},'+bad_command+']'
        envelope=client.envelope(id=request_id,commands='__RAW_COMMANDS__',max_frames=1800)
        wire=json.dumps(envelope).replace('"__RAW_COMMANDS__"',commands)
        (output/(request_id+'-request.json')).write_text(wire+'\n')
        temporary=client.data/'integer-probe.tmp'
        temporary.write_text(wire+'\n');temporary.replace(client.data/'request.json')
        deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            result=client.read('result.json')
            if result and result.get('id')==request_id:
                atomic_json(output/(request_id+'-result.json'),result)
                assert result.get('status')=='error' and result.get('error_code')=='invalid-integer-wire',result
                assert not result.get('results'), 'a command partially executed before tag rejection'
                exact=result['rng_data']
                assert exact['seed']=='37' and exact['state']=='37' and exact['rolls']=='0',exact
                client.send([{'op':'assert','path':'rng.seed','equals':37}])
                return {'label':label,'error':result['error'],'request_id':request_id,'unchanged_rng':exact}
            time.sleep(.025)
        raise ProtocolError('raw integer proof request never reached terminal reply; runner must terminate owned runtime')
    malformed={
        'positive overflow':'{"'+INT32_TAG+'":"2147483648"}',
        'negative overflow':'{"'+INT32_TAG+'":"-2147483649"}',
        'noncanonical decimal':'{"'+INT32_TAG+'":"01"}',
        'negative zero':'{"'+INT32_TAG+'":"-0"}',
        'float text':'{"'+INT32_TAG+'":"1.0"}',
        'numeric tag value':'{"'+INT32_TAG+'":2147483647}',
        'bool tag value':'{"'+INT32_TAG+'":true}',
        'null tag value':'{"'+INT32_TAG+'":null}',
        'extra false field':'{"'+INT32_TAG+'":"37","extra":false}',
        'extra erased null field':'{"'+INT32_TAG+'":"37","extra":null}',
        'duplicate tag field':'{"'+INT32_TAG+'":"37","'+INT32_TAG+'":"38"}',
        'unknown reserved version':'{"__harness_int32_v2":"37"}',
        'escaped reserved field plus null':'{"\\u005f_harness_int32_v1":"37","extra":null}',
        'untagged exact boundary':'16777216',
        'untagged downward-rounding integer':'16777217',
        'untagged negative boundary':'-16777216',
    }
    for label,value in malformed.items():
        case('reject '+label,lambda label=label,value=value:reject_raw(label,value))
    report['passed']=len(report['tests'])
    return report
