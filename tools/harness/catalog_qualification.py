"""Mandatory host proof for the one named native catalog-invariance suite.

Image dependencies are lazy: ordinary functional scenarios remain Pillow-free.
"""
import json
import hashlib
from pathlib import Path
import re
import shutil
from tools.harness.protocol import ProtocolError, atomic_json

SUITE = 'comprehensive-catalog'
QUALIFIER = 'catalog-invariance-v1'
COUNT = 859
PHASES = ('before', 'after')
FEATURE = 'dev/comprehensiveCatalogContracts.lua'


def feature_present(output):
    return (Path(output)/'Source'/FEATURE).is_file()


def requests_contracts(scenario):
    if 'processes' in scenario:
        return any(requests_contracts(group) for group in scenario['processes'])
    for commands in scenario.get('requests', [scenario.get('commands', [])]):
        for command in commands:
            if isinstance(command,str) and command.split()[:1]==['contracts']:
                return True
            if isinstance(command,dict) and command.get('op')=='contracts':
                return True
    return False


def image_dependencies():
    try:
        from PIL import Image
        from tools.visual.compare import compare_image
    except ImportError as error:
        raise ProtocolError('catalog-invariance requires Pillow; install tools/requirements-dev.txt before launching') from error
    return Image, compare_image


def prepare(output, scenario=None, *, launching=False):
    if not feature_present(output): return
    for phase in PHASES:
        directory=Path(output)/'frames'/('catalog-invariance-'+phase)
        if directory.is_symlink():raise ProtocolError('unsafe catalog-invariance directory')
        directory.mkdir(parents=True,exist_ok=True)
        if any(directory.iterdir()):raise ProtocolError('stale catalog-invariance artifacts before launch')
    if launching and scenario is not None and requests_contracts(scenario):image_dependencies()


def expected_inventory(source):
    source=Path(source)
    def read(name):return json.loads((source/name).read_text())
    sprites=read('data/pewterSlice/sprites.json')
    tiles=read('data/pewterSlice/tile-grids.json')['tiles']
    protected=read('dev/catalogProtected.json')['tiles']
    maps=read('data/pewterSlice/descriptors.json')['maps']
    out={}
    def add(stem,width,height,category,mask=False):
        path=stem+'.png'
        if path in out:raise ProtocolError('duplicate expected catalog path')
        out[path]=dict(path=path,width=width,height=height,category=category,mask=mask)
    def asset(stem,category,backgrounds=False):
        add(stem,32,32,category);add(stem+'__mask',32,32,category,True)
        if backgrounds:
            for background in ('white','black','texture'):add(stem+'__'+background,32,32,category+'-background')
    for name,strip in sprites['sprites'].items():
        for frame in strip['frames']:
            add('pewter-sprite-'+name+'-'+frame,32,32,'sprite')
            add('pewter-mask-'+name+'-'+frame,32,32,'mask',True)
    for key in set(tiles)-set(protected):asset('tile_imported_'+key.encode().hex(),'imported-tile')
    for name,descriptor in maps.items():
        for kind in ('terrain','collision','actors','events'):
            add('pewter-'+name+'-'+kind,descriptor['width']*32,descriptor['height']*32,'events-warps-connections' if kind=='events' else kind)
        add('pewter-'+name+'-viewport',400,240,'map-viewport')
    add('pewter-exclamation',32,32,'sprite');add('pewter-exclamation-mask',32,32,'mask',True)
    for background in ('white','black','texture'):add('pewter-exclamation__'+background,32,32,'sprite-background')
    for binding in sprites['mapping'].values():
        strip=sprites['sprites'][binding['name']]
        for pose in ('stand','walk','alternate'):
            if pose!='stand' and not strip['walking']:continue
            for direction in ('down','up','left','right'):
                asset('pewter-pose-'+binding['name']+'-'+pose+'-'+direction,'pewter-character',True)
    if len(maps)!=8 or len(out)!=COUNT:raise ProtocolError('catalog-invariance source inventory changed')
    return out


def executed_suites(evidence, identity):
    executions=[];contracts_seen=False
    for path in sorted(Path(evidence).glob('*-result.json')):
        if not re.fullmatch(r'[0-9]{5}-result.json',path.name):continue
        if path.is_symlink():raise ProtocolError('unsafe numbered protocol result')
        request_path=path.with_name(path.name[:5]+'-request.json')
        if not request_path.is_file():continue
        request=json.loads(request_path.read_text())
        if not requests_contracts({'commands':request.get('commands',[])}):continue
        if request_path.is_symlink():raise ProtocolError('unsafe catalog request evidence')
        packet=json.loads(path.read_text())
        if any(packet.get(key)!=identity[key] or request.get(key)!=identity[key] for key in ('protocol','build_id','session_id')) or packet.get('id')!=request.get('id'):
            raise ProtocolError('wrong-build/session/request catalog execution evidence')
        contracts_seen=True
        for entry in packet.get('results',[]):
            if entry.get('op')!='contracts':continue
            contracts_seen=True;report=entry.get('contracts')
            if not isinstance(report,dict) or not isinstance(report.get('suites'),list):
                raise ProtocolError('contracts missing executed stable suite metadata')
            ids=[]
            for suite in report['suites']:
                if not isinstance(suite,dict) or not isinstance(suite.get('id'),str) or suite['id'] in ids:
                    raise ProtocolError('invalid executed suite metadata')
                ids.append(suite['id'])
                if suite['id']==SUITE:
                    if suite.get('artifact_qualifier')!=QUALIFIER or suite.get('ok') is not True or report.get('ok') is not True:
                        raise ProtocolError('catalog-invariance native suite did not succeed')
                    executions.append({'result':path.name,'request_id':packet.get('id'),'request_sequence':int(path.name[:5]),'command_index':entry.get('command'),'request_sha256':hashlib.sha256(request_path.read_bytes()).hexdigest(),'result_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'suite':suite})
                elif suite.get('artifact_qualifier')==QUALIFIER:
                    raise ProtocolError('catalog qualifier attached to wrong suite')
    return contracts_seen,executions


def check_manifest(packet, expected):
    if not isinstance(packet,dict) or packet.get('schema')!=1 or packet.get('image_root')!='.' or packet.get('missing') not in ([],{}):
        raise ProtocolError('invalid native catalog-invariance manifest')
    images=packet.get('images')
    if not isinstance(images,list) or len(images)!=COUNT:raise ProtocolError('incomplete native catalog-invariance inventory')
    indexed={}
    for image in images:
        if not isinstance(image,dict) or image.get('path') not in expected or image['path'] in indexed:
            raise ProtocolError('duplicate/unknown native catalog-invariance image')
        if image!=expected[image['path']]:raise ProtocolError('native catalog dimensions/category/mask metadata mismatch')
        indexed[image['path']]=image
    if indexed!=expected:raise ProtocolError('native catalog-invariance inventory differs from staged source')
    return indexed


def finalize(output, data, evidence, identity):
    """Caller must first obtain producer quiescence. Copy native reports, then prove."""
    output,data,evidence=Path(output),Path(data),Path(evidence)
    if not feature_present(output):return None
    report={'schema':1,'qualifier':QUALIFIER,'build_id':identity['build_id'],'session_id':identity['session_id'],'ok':False,'quiescent':True}
    target=evidence/'catalog-invariance-qualification.json'
    try:
        seen,executions=executed_suites(evidence,identity)
        if not seen:return None
        if len(executions)!=1:raise ProtocolError('expected exactly one executed comprehensive-catalog suite')
        report['executions']=executions
        build=json.loads((output/'build.json').read_text())
        if any(build.get(key)!=identity[key] for key in ('build_id','session_id')):raise ProtocolError('qualifier build metadata identity mismatch')
        process_path=evidence/'process.json' if (evidence/'process.json').is_file() else output/'run.json'
        process=json.loads(process_path.read_text());pid=process.get('pid',process.get('simulator_pid'))
        if type(pid) is not int or pid<=0:raise ProtocolError('catalog qualifier missing owned process identity')
        report.update(process_pid=pid,process_generation=process.get('generation',1),evidence_directory=str(evidence.relative_to(output)),
            source_sha256=build.get('source_sha256'),compiled_source_sha256=build.get('compiled_source_sha256'),sdk_version=build.get('sdk_version'),
            image_directories={phase:'frames/catalog-invariance-'+phase for phase in PHASES})
        expected=expected_inventory(output/'Source');Image,compare_image=image_dependencies()
        archive=evidence/'catalog-invariance-native';archive.mkdir(exist_ok=True)
        manifests=[]
        for phase in PHASES:
            native=data/('catalog-invariance-'+phase+'.json')
            if native.is_symlink() or not native.is_file():raise ProtocolError('missing native catalog-invariance manifest: '+phase)
            shutil.copyfile(native,archive/native.name)
            packet=json.loads((archive/native.name).read_text());manifests.append(packet)
            check_manifest(packet,expected)
            directory=output/'frames'/('catalog-invariance-'+phase)
            if directory.is_symlink() or not directory.is_dir():raise ProtocolError('missing catalog-invariance image directory')
            files={p.name for p in directory.iterdir() if p.suffix.lower()=='.png'}
            if files!=set(expected):raise ProtocolError('actual catalog-invariance PNG inventory differs')
            for name,entry in expected.items():
                path=directory/name
                if path.is_symlink() or not path.is_file():raise ProtocolError('missing/unsafe catalog PNG: '+name)
                try:
                    with Image.open(path) as image:
                        image.verify()
                    with Image.open(path) as image:
                        if image.format!='PNG' or image.size!=(entry['width'],entry['height']):raise ValueError('format/dimensions')
                        image.load()
                        if entry['mask']:
                            colors=image.convert('RGB').getcolors(maxcolors=3)
                            if image.convert('RGBA').getchannel('A').getextrema()!=(255,255) or colors is None or any(color not in ((0,0,0),(255,255,255)) for _,color in colors):
                                raise ValueError('invalid standalone mask')
                except (OSError,ValueError) as error:raise ProtocolError('corrupt catalog PNG: '+name)from error
            atomic_json(directory/'catalog.json',packet)
        if manifests[0]!=manifests[1]:raise ProtocolError('before/after native catalog metadata changed')
        comparisons=[]
        for name in sorted(expected):
            result=compare_image(output/'frames/catalog-invariance-before'/name,output/'frames/catalog-invariance-after'/name)
            comparisons.append(dict(path=name,**result))
        report.update(checked_pairs=len(comparisons),actual_pngs=COUNT*2,failures=[r for r in comparisons if not r['equal']])
        if report['failures']:raise ProtocolError('catalog-invariance RGBA/mask pixel drift')
        report['ok']=True;atomic_json(target,report);return report
    except BaseException as error:
        report['error']=str(error);atomic_json(target,report)
        if isinstance(error,ProtocolError):raise
        raise ProtocolError('catalog-invariance qualification failed: '+str(error))from error
