"""Supplementary source-input recipe. Receives root's already-owned Client only."""
from pathlib import Path
from tools.harness.brock_journey import BrockJourney,MAPS
from tools.harness.protocol import ProtocolError,atomic_json
from tools.harness.journeys import lookup

def run(client,scenario,evidence,build_evidence=None,capture_dir=None,**unused):
    config=dict(scenario['journey'],max_actions=4000,max_steps=1500,max_encounters=32)
    d=BrockJourney(client,evidence,config,build_evidence,capture_dir)
    try:
        d.dependencies();d.initializing=True
        try:d.reset(seed=42,intro='skip',opening=False,zone='kanto_pewter_city',entry={'x':13,'y':26,'facing':'up'},player_pokemon={'species':'squirtle','level':16},inventory={'money':3000,'slots':[]})
        finally:d.initializing=False
        d.summary.update(natural=False,supplementary=True)
        d.center(MAPS['PewterCity']);checkpoint=lookup(d.state,'session.checkpoint')
        d.warp(MAPS['PewterMart']);d.buy_item('pokered:PEWTER_MART:objects:1','escapeRope',1,550);d.checkpoint('field-rope-actual-shop-purchase');d.warp(MAPS['PewterCity'])
        d.navigate((18,35));d.cross('down',MAPS['Route2'],(8,0));d.warp(MAPS['ViridianForestNorthGate']);d.warp(MAPS['ViridianForest'])
        before_party=d.party();d.send('press b');d.pause_option('ITEM');d.send('press a');d.require(root='bag')
        slots=lookup(d.state,'session.inventory.slots');index=next(i for i,slot in enumerate(slots,1)if slot['id']=='escapeRope')
        d.select('bag.selected',index);d.send('press a','press a');d.require(**{'bag.phase':'field-confirm'})
        rng=d.state['rng'];world=lookup(d.state,'world_motion.rng');actors=lookup(d.state,'world_motion.live')
        d.send('press b');d.require(**{'bag.phase':'list'})
        if d.quantity('escapeRope')!=1 or d.party()!=before_party or d.state['rng']!=rng or lookup(d.state,'world_motion.rng')!=world or lookup(d.state,'world_motion.live')!=actors:raise ProtocolError('cancelled real Rope confirmation changed item/party/streams/actors')
        d.send('press a','press a');d.select('bag.menu.selected',2);d.checkpoint('field-rope-yes-before');d.send('press a')
        d.require(root='overworld',zone_id=checkpoint['zone_id'],**{'player.x':checkpoint['x'],'player.y':checkpoint['y'],'player.facing':checkpoint['facing']})
        if d.quantity('escapeRope')!=0 or d.party()!=before_party:raise ProtocolError('actual Rope did not consume exactly one without healing/changing party')
        d.require(**{'field_item.kind':'escape-rope','field_item.consumed':1})
        d.checkpoint('field-rope-actual-checkpoint-return');d.save()
        d.summary.update(ok=True,acceptance='supplementary actual shop/cancel/Forest return/save; successful Rope true-process Continue not yet covered',checkpoint=checkpoint,field_item=lookup(d.state,'field_item'))
    except BaseException as error:
        d.summary.update(ok=False,error=str(error),last_snapshot=d.state);atomic_json(Path(evidence)/'journey-summary.json',d.summary);raise
    atomic_json(Path(evidence)/'journey-summary.json',d.summary);return d.summary
