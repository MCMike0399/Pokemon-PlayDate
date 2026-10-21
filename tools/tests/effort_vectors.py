"""Unchanged primary per-stat setter bodies; host-only cap/order oracle."""
from pathlib import Path
import hashlib,json,subprocess,tempfile
P=Path(__file__).resolve().parents[1]/'references'
FIELDS=['HP','ATTACK','DEFENSE','SPEED','SP_ATTACK','SP_DEFENSE']
def oracle():
 expected=json.loads((P/'individuals-sources.json').read_text())['files']['poke_tool.c']['sha256']
 assert hashlib.sha256((P/'individuals/poke_tool.c').read_bytes()).hexdigest()==expected,'primary source changed'
 source=(P/'individuals/poke_tool.c').read_text();start=source.index('    case PKM_PARAM_EV_HP: {',source.index('static void PML_PkmSetParamCore(BoxPkm *pkm, u32 field, u32 value) {'));end=source.index('    case PKM_PARAM_CONTEST_COOL:',start)
 cases=source[start:end]
 code='''#include <stdio.h>
typedef unsigned int u32;
#define PKM_EV_TOTAL_MAX 510
#define PKM_EV_MAX 255
'''+ 'enum {'+','.join('PKM_PARAM_EV_'+x for x in FIELDS)+'};\n'+'''typedef struct {int hpEV,atkEV,defEV,speEV,spaEV,spdEV;} Data;
void set(Data*blockA,int field,u32 value){switch(field){'''+cases+'''}}
int main(){Data d;int field,value;while(scanf("%d%d%d%d%d%d%d%d",&d.hpEV,&d.atkEV,&d.defEV,&d.speEV,&d.spaEV,&d.spdEV,&field,&value)==8){set(&d,field,value);printf("%d %d %d %d %d %d\\n",d.hpEV,d.atkEV,d.defEV,d.speEV,d.spaEV,d.spdEV);}}
'''
 # Literal expectations, in NATIVE hp/atk/def/spe/spa/spd order.
 rows=[([0,0,0,0,0,0],0,255,[255,0,0,0,0,0]),([254,0,0,0,0,0],0,257,[255,0,0,0,0,0]),([255,254,0,0,0,0],2,2,[255,254,1,0,0,0]),([255,255,0,0,0,0],5,3,[255,255,0,0,0,0]),([255,255,0,0,0,0],0,250,[250,255,0,0,0,0]),([250,255,0,0,0,0],3,6,[250,255,0,5,0,0]),([0,0,0,0,0,0],5,3,[0,0,0,0,0,3])]
 inputs='\n'.join(' '.join(map(str,old+[field,value]))for old,field,value,expected in rows)+'\n'
 with tempfile.TemporaryDirectory(prefix='ev-setter-reference-',dir='/private/tmp')as tmp:
  c=Path(tmp)/'oracle.c';c.write_text(code);exe=Path(tmp)/'oracle';subprocess.run(['cc','-std=c99','-Wall','-Werror',str(c),'-o',str(exe)],check=True);lines=subprocess.check_output([str(exe)],input=inputs.encode()).decode().splitlines()
 assert len(lines)==len(rows)
 for line,row in zip(lines,rows):assert list(map(int,line.split()))==row[3],(row,line)
 return {'ok':True,'vectors':len(rows),'oracle':'unchanged B2W2 six EV setter cases, native HP/Atk/Def/Spe/SpA/SpD order'}
if __name__=='__main__':print(json.dumps(oracle(),indent=2))
