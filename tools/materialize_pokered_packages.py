"""Copy checksum-verified source inputs from the pinned checkout outside Git."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ('npc-trades','saffron-guards')
def reference_root(package):
    assert package in PACKAGES
    return Path(os.environ.get('POKEMON_ENV', Path.home()/'Developer/Pokemon-PlayDate-env'))/'references'/package

def materialize(package, checkout):
    manifest = ROOT/'tools/references'/package/'manifest.json'
    pins = json.loads(manifest.read_bytes())
    target = reference_root(package)
    for name,digest in pins['files'].items():
        relative = Path(name)
        assert not relative.is_absolute() and '..' not in relative.parts
        raw = subprocess.check_output(['git','-C',str(checkout),'show',pins['revision']+':'+name])
        assert hashlib.sha256(raw).hexdigest()==digest,name
        path = target/relative
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(raw)
    (target/'manifest.json').write_bytes(manifest.read_bytes())
    return target
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pokered',type=Path,required=True)
    args=parser.parse_args()
    for package in PACKAGES:print(materialize(package,args.pokered))
