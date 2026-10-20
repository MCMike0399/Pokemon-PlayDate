import hashlib
import importlib.util
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

PATH = Path(__file__).resolve().parents[1] / 'generate_kanto_maps.py'
SPEC = importlib.util.spec_from_file_location('generate_kanto_maps', PATH)
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def source_png(mode=0):
    # Four source gray levels in each byte, deliberately not tool.encode_png.
    rows = [bytes([(0x1B + y * 17 + x * 3) & 255 for x in range(4)]) for y in range(8)]
    filtered = bytearray()
    previous = bytes(4)
    for row in rows:
        filtered.append(mode)
        for x, value in enumerate(row):
            a, b, c = (row[x-1] if x else 0), previous[x], (previous[x-1] if x else 0)
            p = a+b-c
            pa,pb,pc = abs(p-a),abs(p-b),abs(p-c)
            prediction = [0,a,b,(a+b)//2,a if pa<=pb and pa<=pc else b if pb<=pc else c][mode]
            filtered.append((value-prediction) & 255)
        previous = row
    data = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR',struct.pack('>IIBBBBB',16,8,2,0,0,0,0))
            + chunk(b'IDAT',zlib.compress(filtered)) + chunk(b'IEND',b''))
    expected = [[3-((row[x//4] >> (6-2*(x%4)))&3) for x in range(16)] for row in rows]
    return data, expected


def unpack_png(data):
    width,height,depth,color,compression,filtering,interlace = struct.unpack('>IIBBBBB',data[16:29])
    compressed=b'';position=8
    while position<len(data):
        size=struct.unpack('>I',data[position:position+4])[0]
        kind=data[position+4:position+8];content=data[position+8:position+8+size]
        if kind==b'IDAT':compressed+=content
        position+=size+12
    raw=zlib.decompress(compressed);stride=(width*depth+7)//8
    rows=[]
    for y in range(height):
        start=y*(stride+1)
        assert raw[start]==0
        row=raw[start+1:start+stride+1]
        rows.append([(row[x*depth//8]>>(8-depth-(x*depth)%8))&((1<<depth)-1) for x in range(width)])
    return (width,height,depth,color),rows


class GeneratorTests(unittest.TestCase):
    def test_all_source_png_filters_preserve_four_shades(self):
        for mode in range(5):
            with self.subTest(mode=mode):
                data,expected=source_png(mode)
                self.assertEqual(GEN.decode_png(data),expected)

    def test_bad_png_crc_and_alpha_are_rejected(self):
        data,_=source_png()
        broken=bytearray(data);broken[-1]^=1
        with self.assertRaisesRegex(GEN.MapError,'CRC'):GEN.decode_png(bytes(broken))
        alpha=data[:-12]+chunk(b'tRNS',b'\0\0')+data[-12:]
        with self.assertRaisesRegex(GEN.MapError,'no alpha'):GEN.decode_png(alpha)

    def test_png_format_or_dimensions_are_not_guessed(self):
        data,_=source_png()
        incompatible=data[:8]+chunk(b'IHDR',struct.pack('>IIBBBBB',16,8,8,0,0,0,0))+data[33:]
        with self.assertRaisesRegex(GEN.MapError,'2-bit grayscale'):GEN.decode_png(incompatible)
        with self.assertRaisesRegex(GEN.MapError,'not a PNG'):GEN.decode_png(b'bad')

    def test_four_quadrants_are_distinct_and_row_major(self):
        blockset=bytes(range(16))
        self.assertEqual(GEN.quadrant_ids(blockset,0,0),[0,1,4,5])
        self.assertEqual(GEN.quadrant_ids(blockset,0,1),[2,3,6,7])
        self.assertEqual(GEN.quadrant_ids(blockset,0,2),[8,9,12,13])
        self.assertEqual(GEN.quadrant_ids(blockset,0,3),[10,11,14,15])
        with self.assertRaisesRegex(GEN.MapError,'quadrant'):GEN.quadrant_ids(blockset,0,4)
        with self.assertRaisesRegex(GEN.MapError,'block reference'):GEN.quadrant_ids(blockset,1,0)

    def test_composition_preserves_tile_order_and_rejects_missing_tile(self):
        tiles=[[[shade]*8 for _ in range(8)] for shade in range(4)]
        grid=GEN.compose_grid(tiles,[0,1,2,3])
        self.assertEqual(grid[0],'.'*8+'1'*8)
        self.assertEqual(grid[15],'2'*8+'#'*8)
        with self.assertRaisesRegex(GEN.MapError,'outside PNG'):GEN.compose_grid(tiles,[0,1,2,4])
        with self.assertRaisesRegex(GEN.MapError,'four 8px'):GEN.compose_grid(tiles,[0,1])

    def test_reference_checks_consumed_hashes_and_rejects_unknown_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'file.asm').write_bytes(b'pinned')
            reference=GEN.Reference(root,{'file.asm':hashlib.sha256(b'pinned').hexdigest()})
            self.assertEqual(reference.bytes('file.asm'),b'pinned')
            (root/'file.asm').write_bytes(b'changed')
            self.assertEqual(reference.bytes('file.asm'),b'pinned') # frozen consumed bytes
            with self.assertRaisesRegex(GEN.MapError,'checksum'):GEN.Reference(root,reference.pins).bytes('file.asm')
            with self.assertRaisesRegex(GEN.MapError,'unpinned'):reference.bytes('other.asm')

    def test_blue_selection_is_explicit_and_unknown_condition_fails(self):
        source='a\nIF DEF(_RED)\nred\nENDC\nIF DEF(_BLUE)\nblue\nELSE\nred2\nENDC'
        self.assertEqual(GEN.blue_text(source),'a\nblue')
        with self.assertRaisesRegex(GEN.MapError,'unsupported version'):GEN.blue_text('IF DEF(_YELLOW)\nx\nENDC')

    def test_native_pattern_has_fine_dots_and_exact_densities(self):
        for code,black in [('1',128),('2',512),('#',1024),('.',0)]:
            definition={'dimensions':{'cells':[1,1]},'grids':[{'id':1,'grid':[code*16]*16}],'tile_ids':[[1]]}
            data=GEN.render_map(definition)
            header,rows=unpack_png(data)
            self.assertEqual(header,(32,32,1,0)) # opaque monochrome, no alpha
            self.assertEqual(sum(value==0 for row in rows for value in row),black)
            if code=='1':self.assertNotEqual(rows[0],rows[1])
            self.assertEqual(GEN.render_map(definition),data)

    def test_renderer_pattern_contract_matches_production_source(self):
        import re
        text=(PATH.parents[1]/'Source/lib/shade.lua').read_text()
        for name,expected in [('LIGHT',GEN.LIGHT),('DARK',GEN.DARK)]:
            body=re.search(r'Shade\.'+name+r'\s*=\s*\{([^}]+)\}',text)[1]
            self.assertEqual(tuple(int(value.strip(),16) for value in body.split(',')),expected)

    def test_invalid_grid_is_not_rendered(self):
        with self.assertRaisesRegex(GEN.MapError,'16x16'):GEN.validate_grid(['.'*15]*16)
        with self.assertRaisesRegex(GEN.MapError,'16x16'):GEN.validate_grid(['?'*16]*16)

    def test_event_bounds_and_dynamic_last_map_are_explicit(self):
        class Source:
            def __init__(self,text):self.value=text
            def text(self,path):return self.value
        valid='warp_event 3,7,LAST_MAP,2\nobject_event 0,5,SPRITE_CLERK,STAY,RIGHT,TEXT_CLERK'
        events=GEN.object_events(Source(valid),'ViridianMart','VIRIDIAN_MART',8,8,{})
        self.assertEqual(events['warps'][0]['destination'],{'kind':'last_outdoor_map','warp_index':2,'resolved':False})
        self.assertIsNone(events['objects'][0]['runtime_sprite'])
        with self.assertRaisesRegex(GEN.MapError,'outside map'):
            GEN.object_events(Source('warp_event 8,7,LAST_MAP,2'),'X','X',8,8,{})
        with self.assertRaisesRegex(GEN.MapError,'1-based'):
            GEN.object_events(Source('warp_event 3,7,LAST_MAP,0'),'X','X',8,8,{})

    def test_check_only_rejects_changed_or_extra_artifact_without_rewriting(self):
        with tempfile.TemporaryDirectory(prefix='pokemon-map-pilot-test-',dir='/private/tmp') as directory:
            root=Path(directory)
            (root/'map.json').write_bytes(b'original')
            GEN.publish({'map.json':b'original'},root,True)
            with self.assertRaisesRegex(GEN.MapError,'differs'):GEN.publish({'map.json':b'changed'},root,True)
            self.assertEqual((root/'map.json').read_bytes(),b'original')
            (root/'extra').mkdir()
            with self.assertRaisesRegex(GEN.MapError,'inventory'):GEN.publish({'map.json':b'original'},root,True)
        with self.assertRaisesRegex(GEN.MapError,'output must'):GEN.publish({},PATH.parents[1]/'Source')


@unittest.skipUnless(os.environ.get('KANTO_REFERENCE'),'set KANTO_REFERENCE for pinned real-source checks')
class PinnedReferenceTests(unittest.TestCase):
    def test_route_and_mart_dimensions_events_and_independent_sign_hash(self):
        reference=GEN.Reference(os.environ['KANTO_REFERENCE'])
        route=GEN.decode_map(reference,'Route1');mart=GEN.decode_map(reference,'ViridianMart')
        self.assertEqual(route['dimensions']['cells'],[20,36]);self.assertEqual(mart['dimensions']['cells'],[8,8])
        self.assertEqual(len(route['grids']),15);self.assertEqual(len(mart['grids']),16)
        self.assertEqual([len(route['events'][key]) for key in ('warps','background_events','objects')],[0,1,2])
        self.assertEqual([len(mart['events'][key]) for key in ('warps','background_events','objects')],[2,0,3])
        sign=route['grids'][route['tile_ids'][27][9]-1]
        self.assertEqual(sign['source_tile_ids'],[0x46,0x47,0x56,0x57])
        self.assertEqual(sign['canonical_shade_sha256'],'f31adf65be1d1ec73c573d4aebaf0fda4270dbd58b6b286604a8af982b45a249')
        self.assertEqual(route['collision'][35][9:12],[1,0,0])
        self.assertEqual(len(route['encounters']['grass']['slots']),10)
        self.assertEqual(route['encounters']['grass']['rate_byte'],25)
        self.assertEqual(mart['encounters']['grass']['slots'],[])

    def test_known_short_underground_layout_fails_without_padding(self):
        with self.assertRaisesRegex(GEN.MapError,'92 bytes vs 4x24'):
            GEN.decode_map(GEN.Reference(os.environ['KANTO_REFERENCE']),'UndergroundPathNorthSouth')

    def test_artifacts_are_byte_identical_across_fresh_consumers(self):
        a=GEN.artifacts(GEN.Reference(os.environ['KANTO_REFERENCE']),list(GEN.PILOT_MAPS))
        b=GEN.artifacts(GEN.Reference(os.environ['KANTO_REFERENCE']),list(GEN.PILOT_MAPS))
        self.assertEqual(a,b)
