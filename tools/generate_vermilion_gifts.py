"""Pin special Blue gift logic; reuse the prepared ordinary text/map resources."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'tools/references/vermilion-gifts'
PREPARATION = ROOT / 'Source/data/vermilionPreparation'
REVISION = 'af519899719f0754965776faac0e836a3b906e6d'
CONTENT = 'vermilionGifts'


def build(reference=REFERENCE):
    pin = json.loads((reference / 'manifest.json').read_text())
    assert pin['revision'] == REVISION
    sources = {}
    for name, digest in pin['files'].items():
        raw = (reference / name).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('unverified gift source: ' + name)
        sources[name] = raw.decode()
    club = sources['scripts/PokemonFanClub.asm']
    rod = sources['scripts/VermilionOldRodHouse.asm']
    aide = sources['engine/events/oaks_aide.asm']
    assert 'CheckEvent EVENT_GOT_BIKE_VOUCHER' in club
    assert 'ld b, BICYCLE' in club and 'ld b, BIKE_VOUCHER' in club
    assert club.index('ld hl, .StoryText') < club.index('call GiveItem') < club.index('SetEvent EVENT_GOT_BIKE_VOUCHER')
    assert 'call YesNoChoice' in club and 'call YesNoChoice' in rod
    assert 'bit BIT_GOT_OLD_ROD, a' in rod and 'set BIT_GOT_OLD_ROD, [hl]' in rod
    assert 'const BIT_GOT_OLD_ROD' in sources['constants/ram_constants.asm']
    assert 'ld hl, wPokedexOwned' in aide and 'call CountSetBits' in aide
    assert aide.index('call YesNoChoice') < aide.index('call CountSetBits') < aide.index('call GiveItem')
    assert 'jr z, .giveItem' in aide and 'jr nc, .notEnoughOwnedMons' in aide
    for map_name, threshold, symbol, flag in [('Route2Gate', 10, 'HM_FLASH', 'EVENT_GOT_HM05'),
                                              ('Route11Gate2F', 30, 'ITEMFINDER', 'EVENT_GOT_ITEMFINDER')]:
        script = sources['scripts/' + map_name + '.asm']
        assert f'ld a, {threshold}' in script and f'ld a, {symbol}' in script
        assert f'SetEvent {flag}' in script and 'predef OaksAideScript' in script
    guru = '_VermilionOldRodHouseFishingGuru'
    offers = [
        ('PokemonFanClub', 5, dict(item='bikeVoucher', flag='EVENT_GOT_BIKE_VOUCHER',
            blocks=['bicycle', 'bikeVoucher'], prompt=['_PokemonFanClubChairmanIntroText'],
            before=['_PokemonFanClubChairmanStoryText'], declined=['_PokemonFanClubNoStoryText'],
            completed=['_PokemonFanClubChairFinalText'], full=['_PokemonFanClubBagFullText'],
            success=['_PokemonFanClubReceivedBikeVoucherText', '_PokemonFanClubExplainBikeVoucherText'])),
        ('VermilionOldRodHouse', 1, dict(item='oldRod', flag='pokered:wStatusFlags1:BIT_GOT_OLD_ROD',
            prompt=[guru+'DoYouLikeToFishText'], before=[], declined=[guru+'ThatsSoDisappointingText'],
            completed=[guru+'HowAreTheFishBitingText'], full=[guru+'NoRoomText'],
            success=[guru+'TakeThisText', guru+'FishingIsAWayOfLifeText'])),
    ]
    for map_name, index, item, flag, threshold, explanation in [
        ('Route2Gate', 1, 'hm05', 'EVENT_GOT_HM05', 10, '_Route2GateOaksAideFlashExplanationText'),
        ('Route11Gate2F', 2, 'itemfinder', 'EVENT_GOT_ITEMFINDER', 30, '_Route11Gate2FOaksAideItemfinderDescriptionText'),
    ]:
        offers.append((map_name,index,dict(item=item,flag=flag,threshold=threshold,
            prompt=['_OaksAideHiText'],before=['_OaksAideHereYouGoText'],
            declined=['_OaksAideComeBackText'], insufficient=['_OaksAideUhOhText'],
            completed=[explanation],full=['_OaksAideNoRoomText'],success=['_OaksAideGotItemText',explanation])))
    ordinary = json.loads((PREPARATION/'events.json').read_text())['events']
    texts = json.loads((PREPARATION/'dialogue.json').read_text())['texts']
    events = {}
    for map_name,index,offer in offers:
        record = json.loads((PREPARATION/(map_name+'.json')).read_text())
        assert record['source_revision'] == REVISION
        actor = record['events']['objects'][index-1]
        identity = actor['id']
        assert actor['source_index'] == index and identity not in ordinary
        for key in ['prompt','before','declined','completed','full','success','insufficient']:
            for label in offer.get(key,[]):
                assert label in texts, 'missing prepared source text: '+label
        events[identity] = dict(kind='bespoke',content=CONTENT,**offer)
    output = dict(schema=1, source_revision=REVISION, events=events)
    return {'events.json': (json.dumps(output,indent=2,sort_keys=True,ensure_ascii=False)+'\n').encode()}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    target=args.output or ROOT/'Source/data/vermilionGifts'
    for name,raw in build().items():
        if args.check:
            assert (target/name).read_bytes()==raw, 'stale gift artifact: '+name
        else:
            assert args.output, 'explicit output directory required'
            target.mkdir(parents=True,exist_ok=True)
            (target/name).write_bytes(raw)

if __name__=='__main__':
    main()
