"""Supplementary real-input reward/HUD panels; owner runner supplies Client."""
from tools.harness.journeys import Journey,lookup
from tools.harness.protocol import ProtocolError,atomic_json

class RewardHUDJourney(Journey):
    def advance(self):
        self.send('wait 12','press a')

    def run(self):
        # One labeled setup only. Both actual foes begin at1HP/asleep; attacks,
        # PP, accuracy, XP/EV, learning, return and save execute production paths.
        self.reset(intro='skip',opening=False,zone='reds_house_2f',seed=42,
                   player_pokemon={'species':'charmander','level':6,'hp':18},grant_xp={'amount':56},
                   trainer_name='REWARD HUD',enemy_party=[
                       {'species':'rattata','level':5,'hp':1,'status':'sleep','status_turns':3,'sleep_duration':3},
                       {'species':'caterpie','level':5,'hp':1,'status':'sleep','status_turns':3,'sleep_duration':3}])
        self.await_value('battle.introPhase','ready',240)
        selected=0;gained=False;grew=False;learned=False;terminal=False
        for _ in range(120):
            root=self.state.get('root')
            if root=='overworld':
                if not terminal:raise ProtocolError('reward HUD battle returned without observed victory')
                break
            if root=='learning':
                if self.state['learning']['phase']!='message':raise ProtocolError('unexpected full/refusal learning path')
                if not learned:
                    self.await_value('learning.dialog_ready', True, frames=180)
                    self.checkpoint('reward-actual-ember-learning');learned=True
                self.advance();continue
            if root!='battle':raise ProtocolError('unexpected reward HUD root: '+str(root))
            b=self.state['battle'];phase=b['phase'];message=b.get('message','')
            if phase=='script':
                if not b.get('waiting'):
                    self.send('wait 2');continue
                if ' gained ' in message and not gained:
                    self.require(**{'battle.player.level':7,'battle.player.hp':20,'battle.player.maxHP':22,'battle.player.xp':303,
                                    'battle.player.individuals.evs.spe':1,'battle.rewards.holds.1.level':6,
                                    'battle.rewards.holds.1.hp':18,'battle.rewards.holds.1.maxHP':20,'battle.presentation.player.level':6,'battle.presentation.player.hp':18,'battle.presentation.player.maxHP':20})
                    if message!='CHARMANDER gained 68 EXP!':raise ProtocolError('unexpected literal first-foe EXP: '+message)
                    self.checkpoint('reward-gained-before-ack');self.send('record reward-gained-held 12');gained=True
                elif ' grew to ' in message and gained and not grew:
                    self.require(**{'battle.player.level':7,'battle.player.hp':20,'battle.player.maxHP':22,'battle.rewards.holds':[],'battle.presentation.player.level':7,'battle.presentation.player.hp':20,'battle.presentation.player.maxHP':22})
                    if message!='CHARMANDER grew to Lv7!':raise ProtocolError('unexpected first level panel: '+message)
                    self.checkpoint('reward-level-after-ack');grew=True
                self.advance()
            elif phase=='command':
                if not b.get('menu',{}).get('active') and not b.get('inMoveSelect'):
                    self.send('wait 2');continue
                desired='scratch'if selected==0 else'ember'
                moves=b['player']['moves']
                if desired not in moves:raise ProtocolError('actual learned move unavailable: '+desired)
                if not b.get('inMoveSelect'):
                    self.send('press a');self.await_value('battle.moveMenu.active',True)
                target=moves.index(desired)+1
                for _ in range(4):
                    if self.state['battle']['moveMenu']['selected']==target:break
                    self.send('press down','wait 2')
                self.require(**{'battle.moveMenu.selected':target})
                self.send('press a');selected+=1
                if selected>2:raise ProtocolError('controlled panel foes unexpectedly survived real attacks')
            elif phase=='ended':
                self.require(**{'battle.outcome':'victory','battle.rewards.awards':2})
                self.checkpoint('reward-two-foe-victory');terminal=True;self.send('press a')
            else:raise ProtocolError('unexpected reward HUD phase: '+str(phase))
        else:raise ProtocolError('reward HUD journey exceeded120 observed actions')
        if not(gained and grew and learned and terminal):raise ProtocolError('required actual reward/level/learning panels missing')
        self.await_value('root','overworld');self.await_value('overworld','explore')
        self.require(**{'pokemon.individuals.evs.spe':1,'pokemon.individuals.evs.hp':1,'pokemon.level':8})
        self.checkpoint('reward-returned-canonical')
        # Real field menu by observed label; no fabricated save/copy or slot write.
        self.send('press b');self.await_value('root','pause')
        options=self.state['pause']['menu']['options']
        choices=[i+1 for i,value in enumerate(options)if str(value).upper()=='SAVE']
        if len(choices)!=1:raise ProtocolError('SAVE option not unique')
        for _ in range(len(options)):
            if self.state['pause']['menu']['selected']==choices[0]:break
            self.send('press down','wait 2')
        self.require(**{'pause.menu.selected':choices[0]});self.send('press a','wait 2','press a');self.await_value('root','dialog')
        self.await_value('dialog.ready',True,300);self.require(**{'pause.lastSave.ok':True});self.checkpoint('reward-real-save-dialog')
        self.send('press a');self.await_value('root','overworld');self.send('wait 2');self.checkpoint('reward-saved-world')
        self.summary.update(ok=True,journey_outcome='complete',supplementary=True,attacks=selected,
                            final=self.state,notes='Single controlled setup; real attacks/learning/Save. Not natural campaign or true-process Continue acceptance.')
        return self.summary

def run(client,scenario,evidence_dir,**_):
    config=scenario['journey']
    if config!={'name':'reward-hud','seed':42}:raise ProtocolError('invalid reward HUD recipe config')
    journey=RewardHUDJourney(client,evidence_dir,config)
    try:return journey.run()
    except BaseException as error:
        journey.summary.update(ok=False,journey_outcome='failed',error=str(error),final=journey.state);raise
    finally:atomic_json(journey.evidence/'reward-hud-summary.json',journey.summary)
