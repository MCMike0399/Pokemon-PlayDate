"""Root-owned real-input medicine qualification; explicit bounded battle fixtures."""
import copy
from tools.harness.journeys import Journey, lookup
from tools.harness.protocol import ProtocolError


class MedicineJourney(Journey):
    def command(self):
        for _ in range(100):
            self.require(root='battle')
            battle=self.state['battle']
            if battle['phase']=='command' and battle.get('menu',{}).get('active') and not battle.get('introDrawing'):
                return
            if battle['phase']=='script' and battle.get('waiting'):
                self.send('wait 12','press a')
            elif battle['phase'] in ('script','command'):
                self.send('wait 2')
            else:
                raise ProtocolError('unexpected medicine battle phase: '+battle['phase'])
        raise ProtocolError('medicine command did not settle')

    def start(self,name,item,active=None,bench=None):
        first={'species':'charmander','level':5}
        first.update(active or {})
        second={'species':'squirtle','level':5,'hp':0}
        second.update(bench or {})
        fixture={'seed':42,'intro':'skip','opening':False,'zone':'reds_house_2f',
                 'party_pokemon':[first,second],
                 'inventory':{'money':3000,'slots':[{'id':item,'quantity':2}]}}
        self.fixtures.append({'name':name,'options':fixture})
        self.send({'op':'fixture','options':fixture},'battle magikarp 5')
        self.await_value('battle.introPhase','ready')
        self.command()
        self.require(**{'battle.enemy.species':'magikarp','battle.enemy.pp.splash':40})

    def bag(self):
        self.command()
        self.require(**{'battle.menu.selected':1})
        self.send('press right','wait 2','press a')
        self.await_value('root','bag')
        self.require(**{'bag.phase':'list','bag.selected':1})

    def target(self,index):
        self.send('press a');self.await_value('root','party')
        self.require(**{'party_ui.selected':1})
        if index==2:self.send('press down','wait 2')
        self.send('press a')

    def stable(self,before):
        now={key:copy.deepcopy(self.state[key]) for key in ('party','inventory','rng')}
        if now!=before or lookup(self.state,'battle.enemy.pp.splash')!=40:
            raise ProtocolError('failed/cancelled medicine changed party/bag/RNG/enemy PP')


def run(client,scenario,evidence):
    j=MedicineJourney(client,evidence,scenario['journey'])
    j.start('potion-success','potion',{'hp':1})
    j.bag();j.checkpoint('medicine-potion-bag');j.target(1)
    j.require(root='battle',**{'inventory.quantities.potion':1})
    if lookup(j.state,'party.members.1.hp')!=lookup(j.state,'party.members.1.maxHP'):
        raise ProtocolError('Potion did not restore the selected damaged active member')
    j.checkpoint('medicine-potion-used');j.command();j.require(**{'battle.enemy.pp.splash':39})
    j.checkpoint('medicine-potion-enemy-response')

    j.start('potion-no-effect','potion')
    before={key:copy.deepcopy(j.state[key]) for key in ('party','inventory','rng')}
    j.bag();j.target(1);j.require(root='bag',**{'bag.phase':'message'})
    j.send('wait 24');j.stable(before);j.checkpoint('medicine-no-effect')
    j.send('press b','wait 2','press b');j.command();j.stable(before)

    j.start('revive-bench','revive',{'hp':1})
    j.bag();j.target(2);j.require(root='battle',**{'inventory.quantities.revive':1,'party.active':1,'party.members.1.hp':1})
    member=lookup(j.state,'party.members.2')
    if member['hp']!=max(1,member['maxHP']//2):raise ProtocolError('bench Revive HP was not half maximum')
    j.checkpoint('medicine-bench-revived');j.command();j.require(**{'battle.enemy.pp.splash':39,'party.active':1})

    j.start('ether-chosen-pp','ether',{'hp':1,'pp':{'growl':0}})
    scratch=lookup(j.state,'party.members.1.pp.scratch')
    j.bag();j.target(1);j.require(root='bag',**{'bag.phase':'move','bag.menu.selected':1})
    j.checkpoint('medicine-ether-move-menu')
    j.send('press down','wait 2','press a')
    j.require(root='battle',**{'inventory.quantities.ether':1,'party.members.1.pp.growl':10,'party.members.1.pp.scratch':scratch})
    j.checkpoint('medicine-ether-used');j.command();j.require(**{'battle.enemy.pp.splash':39})

    j.start('cancel-target-and-move','ether',{'hp':1,'pp':{'growl':0}})
    before={key:copy.deepcopy(j.state[key]) for key in ('party','inventory','rng')}
    j.bag();j.target(1);j.require(**{'bag.phase':'move'})
    j.send('press b');j.require(root='bag',**{'bag.phase':'list'})
    j.send('press a');j.require(root='party');j.send('press b');j.require(root='bag',**{'bag.phase':'list'})
    j.send('press b');j.command();j.stable(before);j.checkpoint('medicine-cancel-no-turn')
    j.summary.update(ok=True,cases=5,limitation='Explicit battle/party/item fixtures; real inputs select and use/cancel actual medicine. No natural Brock completion claim.')
    return j.summary
