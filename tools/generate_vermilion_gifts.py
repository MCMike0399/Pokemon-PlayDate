"""Pin special Blue gift logic; reuse the prepared ordinary text/map resources."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if __package__ in (None, ''):
    sys.path.insert(0, str(ROOT))
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
    installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']
    rod_maps = {}
    for map_name, item, flag, prompt, declined, completed, success in [
        ('FuchsiaGoodRodHouse', 'goodRod', 'BIT_GOT_GOOD_ROD',
         '_FuchsiaGoodRodHouseFishingGuruText',
         '_FuchsiaGoodRodHouseFishingGuruThatsSoDisappointingText',
         '_FuchsiaGoodRodHouseFishingGuruHowAreTheFishText',
         ['_FuchsiaGoodRodHouseFishingGuruReceivedGoodRodText']),
        ('Route12SuperRodHouse', 'superRod', 'BIT_GOT_SUPER_ROD',
         '_Route12SuperRodHouseFishingGuruDoYouLikeToFishText',
         '_Route12SuperRodHouseFishingGuruThatsDisappointingText',
         '_Route12SuperRodHouseFishingGuruTryFishingText',
         ['_Route12SuperRodHouseFishingGuruReceivedSuperRodText',
          '_Route12SuperRodHouseFishingGuruFishingWayOfLifeText']),
    ]:
        script = sources['scripts/' + map_name + '.asm']
        assert 'call YesNoChoice' in script
        assert f'bit {flag}, a' in script and f'set {flag}, [hl]' in script
        assert f'const {flag}' in sources['constants/ram_constants.asm']
        assert script.index('call GiveItem') < script.index(f'set {flag}, [hl]')
        assert 'jr nc, .bag_full' in script
        assert f'lb bc, {"GOOD_ROD" if item == "goodRod" else "SUPER_ROD"}, 1' in script
        if map_name in installed:
            rod_maps[map_name] = ROOT / 'Source/data/midgameSouth'
            prefix = '_FuchsiaGoodRodHouseFishingGuru' if item == 'goodRod' else '_Route12SuperRodHouseFishingGuru'
            offers.append((map_name, 1, dict(item=item, flag='pokered:wStatusFlags1:' + flag,
                prompt=[prompt], before=[], declined=[declined], completed=[completed],
                full=[prefix + 'NoRoomText'], success=success)))
    ordinary = json.loads((PREPARATION/'events.json').read_text())['events']
    texts = json.loads((PREPARATION/'dialogue.json').read_text())['texts']
    events = {}
    for map_name,index,offer in offers:
        package = rod_maps.get(map_name, PREPARATION)
        record = json.loads((package/(map_name+'.json')).read_text())
        available_texts = texts
        if map_name in rod_maps:
            available_texts = json.loads((package/'dialogue.json').read_text())['texts']
            from tools.generate_cerulean_content import text_recipes
            pinned_texts = text_recipes(sources['text/' + map_name + '.asm'])
            for label, recipe in pinned_texts.items():
                assert available_texts[label]['recipe'] == recipe, 'rod source text drift: ' + label
        assert record['source_revision'] == REVISION
        actor = record['events']['objects'][index-1]
        identity = actor['id']
        assert actor['source_index'] == index and identity not in ordinary
        for key in ['prompt','before','declined','completed','full','success','insufficient']:
            for label in offer.get(key,[]):
                assert label in available_texts, 'missing prepared source text: '+label
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
