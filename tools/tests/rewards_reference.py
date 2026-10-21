"""Unchanged primary C AddEVs + six setters; no production Lua oracle."""
from pathlib import Path
import hashlib,json,re,subprocess,tempfile
P=Path(__file__).resolve().parents[1]/'references'
def function(text,name):
 m=re.search(r'^(?:static )?(?:BOOL|void|u32|u16)\s+'+name+r'\([^;\n]*\) \{',text,re.M);assert m,name
 start=m.start();end=m.end();depth=1
 while depth:
  if text[end]=='{':depth+=1
  elif text[end]=='}':depth-=1
  end+=1
 return text[start:end]
def oracle():
 pin=json.loads((P/'rewards-sources.json').read_text())
 for name,entry in pin['files'].items():assert hashlib.sha256((P/'rewards'/name).read_bytes()).hexdigest()==entry['sha256']
 tool=(P/'rewards/poke_tool.c').read_text();flow=(P/'rewards/btl_server_flow_sub.c').read_text()
 start=tool.index('    case PKM_PARAM_EV_HP: {',tool.index('static void PML_PkmSetParamCore(BoxPkm *pkm, u32 field, u32 value) {'));end=tool.index('    case PKM_PARAM_CONTEST_COOL:',start);cases=tool[start:end]
 start=flow.index('typedef struct {',flow.index('// For each stat: its effort value'));end=flow.index('// clang-format on',start);table=flow[start:end]
 c='''#include <stdio.h>
#include <assert.h>
typedef unsigned char u8;typedef unsigned short u16;typedef unsigned int u32;typedef int BOOL;
#define PKM_EV_TOTAL_MAX 510
#define PKM_EV_MAX 255
#define ITEM_MACHO_BRACE 215
#define PKM_PARAM_EV_HP 13
#define PKM_PARAM_EV_ATTACK 14
#define PKM_PARAM_EV_DEFENSE 15
#define PKM_PARAM_EV_SPEED 16
#define PKM_PARAM_EV_SP_ATTACK 17
#define PKM_PARAM_EV_SP_DEFENSE 18
typedef struct {int hpEV,atkEV,defEV,speEV,spaEV,spdEV;} PartyPkm;
typedef struct {PartyPkm*src;int species;} BattleMon;
typedef struct {int hp,attack,defense,speed,spAttack,spDefense;} BtlFlowExpEntry;
static int yield[6];
u16 GetBattleMonSpecies(BattleMon*m){return m->species;}
int GetBattleMonStat(BattleMon*m,int stat){return 0;}
u32 PML_PersonalGetParamSingle(int species,int form,int param){return yield[param-10];}
u16 GetBattleMonHeldItem(BattleMon*m){return 0;} /* no accepted modifier definitions */
u32 ItemGetParam(int item,int param){assert(0);return 0;}
PartyPkm* GetSrcData(BattleMon*m){return m->src;}
BOOL PokeParty_DecryptPkm(PartyPkm*p){return 0;}void PokeParty_EncryptPkm(PartyPkm*p,BOOL v){}
u32 PokeParty_GetParam(PartyPkm*p,int field,void*unused){int e[]={p->hpEV,p->atkEV,p->defEV,p->speEV,p->spaEV,p->spdEV};if(field==0x97)return 0;assert(field>=13&&field<=18);return e[field-13];}
void PokeParty_SetParam(PartyPkm*p,u32 field,u32 value){PartyPkm*blockA=p;switch(field){'''+cases+'''}}
'''+table+'\n'+function(flow,'AddEVs')+'''\nint main(){PartyPkm p;BattleMon m={&p,1},foe={0,25};BtlFlowExpEntry e;
while(scanf("%d%d%d%d%d%d",&p.hpEV,&p.atkEV,&p.defEV,&p.speEV,&p.spaEV,&p.spdEV)==6){for(int i=0;i<6;i++)scanf("%d",&yield[i]);e=(BtlFlowExpEntry){0};AddEVs(&m,&foe,&e);printf("%d %d %d %d %d %d\\n",p.hpEV,p.atkEV,p.defEV,p.speEV,p.spaEV,p.spdEV);}}
'''
 # All inputs/expected use native HP/Atk/Def/Spe/SpA/SpD order, explicitly.
 vectors=[
  ('pika-speed2',[0]*6,[0,0,0,2,0,0],[0,0,0,2,0,0]),
  ('second-recipient-full-not-halved',[0]*6,[0,0,0,2,0,0],[0,0,0,2,0,0]),
  ('stat255-waste',[0,0,254,0,0,0],[0,0,3,0,0,0],[0,0,255,0,0,0]),
  ('510-native-speed-before-spa',[255,254,0,0,0,0],[0,0,0,1,1,0],[255,254,0,1,0,0]),
  ('beedrill-cap',[255,254,0,0,0,0],[0,2,0,0,0,1],[255,255,0,0,0,0]),
  ('full510',[255,255,0,0,0,0],[0,0,0,2,0,0],[255,255,0,0,0,0]),
  ('hp-quarter-crossing',[3,0,0,0,0,0],[1,0,0,0,0,0],[4,0,0,0,0,0])]
 wire='\n'.join(' '.join(map(str,old+amount))for _,old,amount,_ in vectors)+'\n'
 with tempfile.TemporaryDirectory(prefix='rewards-c-reference-',dir='/private/tmp')as t:
  source=Path(t)/'oracle.c';source.write_text(c);exe=Path(t)/'oracle';subprocess.run(['cc','-std=c99','-Wall','-Werror',str(source),'-o',str(exe)],check=True);rows=subprocess.check_output([str(exe)],input=wire.encode()).decode().splitlines()
 assert len(rows)==len(vectors)
 for (name,_,_,expected),actual in zip(vectors,rows):assert list(map(int,actual.split()))==expected,(name,actual,expected)
 return {'ok':True,'vectors':len(vectors),'source':'unchanged native AddEVs and six per-stat setter cases; held/virus0 stubs; no DS RNG/device or absent-modifier claim'}
if __name__=='__main__':print(json.dumps(oracle(),indent=2))
