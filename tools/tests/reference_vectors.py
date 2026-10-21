"""Host-only independent primary C oracle. No project Lua implementation used."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,tempfile
P=Path(__file__).resolve().parents[1]/'references'
FIELDS=['LEVEL','MAX_HP','HP','IV_HP','EV_HP','IV_ATTACK','EV_ATTACK','IV_DEFENSE','EV_DEFENSE','IV_SPEED','EV_SPEED','IV_SP_ATTACK','EV_SP_ATTACK','IV_SP_DEFENSE','EV_SP_DEFENSE','FORM','SPECIES','ATTACK','DEFENSE','SPEED','SP_ATTACK','SP_DEFENSE']
def function(text,name):
 m=re.search(r'[^\n;]*\b'+name+r'\([^;\n]*\) \{',text);assert m,name
 start=m.start();end=m.end();depth=1
 while depth:
  if text[end]=='{':depth+=1
  elif text[end]=='}':depth-=1
  end+=1
 return text[start:end]
def oracle():
 expected=json.loads((P/'individuals-sources.json').read_text())['files']['poke_tool.c']['sha256']
 assert hashlib.sha256((P/'individuals/poke_tool.c').read_bytes()).hexdigest()==expected,'primary source changed'
 text=(P/'individuals/poke_tool.c').read_text();table=text[text.index('static const s8 natureStat['):];table=table[:table.index('};')+2]
 enum='enum {'+','.join('PKM_PARAM_'+x for x in FIELDS)+'};\n'
 code='''#include <stdio.h>
#include <stdint.h>
typedef int8_t s8;typedef uint8_t u8;typedef uint16_t u16;typedef uint32_t u32;
#define NATURE_COUNT 25
#define NATURE_STAT_COUNT 5
#define SPECIES_SHEDINJA 292
'''+enum+'''typedef struct { int hp,attack,defense,spAttack,spDefense,speed; } PersonalData;
typedef struct {int p[32];int nature;} PartyPkm;
static PersonalData personal;
int PokeParty_GetParam(PartyPkm*p,int field,void* unused){return p->p[field];}
void PokeParty_SetParam(PartyPkm*p,int field,int value){p->p[field]=value;}
int PokeParty_GetNature(PartyPkm*p){return p->nature;}
PersonalData* PML_PersonalLoadBW2(int species,int form){return &personal;}
'''+table+'\n'+function(text,'adjustStatForNature')+'\n'+function(text,'PokeParty_RecalcStatsCore')+'''\nint main(){PartyPkm p={0};int iv[6],ev[6];
while(scanf("%d%d%d%d%d%d%d%d%d%d",&p.p[PKM_PARAM_LEVEL],&p.nature,&p.p[PKM_PARAM_MAX_HP],&p.p[PKM_PARAM_HP],&personal.hp,&personal.attack,&personal.defense,&personal.spAttack,&personal.spDefense,&personal.speed)==10){
for(int i=0;i<6;i++)scanf("%d",&iv[i]);for(int i=0;i<6;i++)scanf("%d",&ev[i]);
int fields[]={PKM_PARAM_IV_HP,PKM_PARAM_IV_ATTACK,PKM_PARAM_IV_DEFENSE,PKM_PARAM_IV_SP_ATTACK,PKM_PARAM_IV_SP_DEFENSE,PKM_PARAM_IV_SPEED};
for(int i=0;i<6;i++){p.p[fields[i]]=iv[i];p.p[fields[i]+1]=ev[i];}
p.p[PKM_PARAM_SPECIES]=1;PokeParty_RecalcStatsCore(&p);
printf("%d %d %d %d %d %d %d\\n",p.p[PKM_PARAM_MAX_HP],p.p[PKM_PARAM_ATTACK],p.p[PKM_PARAM_DEFENSE],p.p[PKM_PARAM_SP_ATTACK],p.p[PKM_PARAM_SP_DEFENSE],p.p[PKM_PARAM_SPEED],p.p[PKM_PARAM_HP]);} }
'''
 vectors=json.loads((P/'individuals/vectors.json').read_text());inputs=[]
 for v in vectors:
  inputs.append(' '.join(map(str,[v['level'],v['nature'],v['old_max'],v['hp']]+v['base']+v['iv']+v['ev'])))
 with tempfile.TemporaryDirectory(prefix='iv-ev-reference-',dir='/private/tmp')as tmp:
  src=Path(tmp)/'oracle.c';src.write_text(code);exe=Path(tmp)/'oracle';subprocess.run(['cc','-std=c99','-Wall','-Werror',str(src),'-o',str(exe)],check=True)
  rows=subprocess.check_output([str(exe)],input=('\n'.join(inputs)+'\n').encode()).decode().splitlines()
  actual=[list(map(int,row.split()))for row in rows]
 for vector,result in zip(vectors,actual):assert result==vector['expected'],(vector['name'],result,vector['expected'])
 assert len(rows)==len(vectors)
 return {'ok':True,'vectors':len(vectors),'source_sha256':hashlib.sha256(text.encode()).hexdigest(),'oracle':'unchanged B2W2 RecalcStatsCore + adjustStatForNature + natureStat, with field I/O stubs only'}
if __name__=='__main__':print(json.dumps(oracle(),indent=2))
