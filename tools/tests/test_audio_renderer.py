"""Independent arithmetic and host-only output qualification for offline audio."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import wave

from tools.audio.render import APU, CLOCK, RATE, TICK, render, sample_index
from tools.audio.source import AudioError

ROOT = Path(__file__).resolve().parents[2]
REFS = ROOT/'tools/references/audio'
FIXTURE = json.loads((REFS/'hardware-math-fixtures.json').read_text())


def ir(writes=(), ticks=2, status='ended'):
    events = [{'tick':0,'kind':'write','register':f'{a:04x}','value':v}
              for a,v in [(0xff26,128),(0xff24,119),(0xff25,255),*writes]]
    return {'schema':1, 'clock':{'tick_numerator':TICK,'tick_denominator':CLOCK,'unit':'seconds'},
            'status':status, 'ticks':ticks, 'repeat':None, 'events':events}


def pulse(apu, frequency=2047, envelope=0xf0, control=0):
    for a,v in [(0xff26,128),(0xff24,119),(0xff25,0x11),(0xff10,control),
                (0xff11,0x80),(0xff12,envelope),(0xff13,frequency & 255),
                (0xff14,0x80 | (frequency>>8))]:
        apu.write(a,v)


class HardwareMathTests(unittest.TestCase):
    def test_primary_document_pins(self):
        pins = json.loads((REFS/'hardware-pins.json').read_text())
        self.assertEqual(len(pins['revision']),40)
        for name, pin in pins['files'].items():
            self.assertIn(pins['revision'],pin['url'])
            self.assertEqual(hashlib.sha256((REFS/name).read_bytes()).hexdigest(),pin['sha256'])

    def test_literal_periods_and_bitwidth(self):
        apu = APU()
        for name, expected in FIXTURE['periods'].items():
            kind, value = name.split('_'); value=int(value)
            i = {'pulse':0,'wave':2,'noise':3}[kind]
            apu.voices[i].frequency=value
            if kind=='noise': apu.registers[0xff22]=value
            self.assertEqual(apu.period(i), expected*RATE)
        for value in (0xe0,0xf0):
            apu.registers[0xff22]=value
            self.assertIsNone(apu.period(3))
        for value in (-1,256,1.5,True):
            with self.assertRaises(AudioError): apu.write(0xff12,value)

    def test_pulse_duty_literal_phases_and_retrigger(self):
        for duty, expected in enumerate(FIXTURE['pulse_duties']):
            apu=APU(); pulse(apu)
            apu.write(0xff11,duty<<6)
            self.assertEqual(apu.levels()[0],120)  # Initial digital 0.
            actual={}
            for _ in range(8):
                apu.integrate(apu.time+4*RATE)
                actual[apu.voices[0].position]='1' if apu.levels()[0]<0 else '0'
            self.assertEqual(''.join(actual[i] for i in range(8)),expected)
            apu.integrate(apu.time+4*RATE)
            before=apu.voices[0].position
            apu.write(0xff14,0x87)
            self.assertEqual(apu.voices[0].position,before)

    def test_wave_buffer_first_fetch_levels_and_banks(self):
        apu=APU(); apu.write(0xff26,128)
        apu.write(0xff30,0x1e)
        for a,v in [(0xff24,119),(0xff25,0x44),(0xff1a,128),(0xff1c,32),(0xff1d,255),(0xff1e,135)]: apu.write(a,v)
        self.assertEqual(apu.voices[2].buffer,0)
        apu.integrate(2*RATE)
        self.assertEqual(apu.voices[2].buffer,14)
        self.assertEqual(apu.levels()[4],-104)
        apu.write(0xff1c,64)
        self.assertEqual(apu.levels()[4],8)  # digital 14 >> 1 = 7, not analog half.
        apu.write(0xff1c,96)
        self.assertEqual(apu.levels()[4],72)
        with self.assertRaisesRegex(AudioError,'wave RAM'): apu.write(0xff30,0)
        apu.write(0xff1a,0)
        apu.write(0xff30,0xab)
        self.assertEqual(apu.ram[:2],[10,11])

    def test_noise_independent_literal_sequences(self):
        for mode, key in [(0,'noise15'),(8,'noise7')]:
            apu=APU()
            for a,v in [(0xff26,128),(0xff21,0xf0),(0xff22,mode),(0xff23,128)]: apu.write(a,v)
            actual=[]
            for _ in FIXTURE[key]:
                apu.integrate(apu.time+8*RATE)
                actual.append(apu.voices[3].lfsr)
            self.assertEqual(actual,FIXTURE[key])
            self.assertTrue(all(0<=x<32768 for x in actual))

    def test_envelope_64hz_and_pace_zero(self):
        apu=APU(); pulse(apu,0,0xf1)
        actual=[apu.voices[0].volume]
        for _ in range(4):
            apu.integrate(apu.time+65536*RATE)
            actual.append(apu.voices[0].volume)
        self.assertEqual(actual,FIXTURE['envelope_down_15_pace1'])
        apu=APU(); pulse(apu,0,0x58)
        apu.integrate(CLOCK*RATE)
        self.assertEqual(apu.voices[0].volume,5)
        apu=APU(); pulse(apu,0,0xe9)
        apu.integrate(3*65536*RATE)
        self.assertEqual(apu.voices[0].volume,15)
        self.assertFalse(apu.voices[0].env_running)

    def test_sweep_shadow_double_overflow_and_negate(self):
        apu=APU(); pulse(apu,512,0xf0,0x11)
        actual=[]; active=[]
        for cycle in (24576,57344,90112):
            apu.integrate(cycle*RATE)
            actual.append(apu.voices[0].frequency); active.append(apu.voices[0].active)
        self.assertEqual(actual,FIXTURE['sweep_add_shift1_initial512'])
        self.assertEqual(active,FIXTURE['sweep_add_shift1_active'])
        apu=APU(); pulse(apu,1500,0xf0,0x01)
        self.assertFalse(apu.voices[0].active)  # Trigger overflow even with pace zero.
        apu=APU(); pulse(apu,1000,0xf0,0x19)
        apu.integrate(24576*RATE)
        self.assertEqual(apu.voices[0].frequency,500)
        apu.write(0xff10,0x11)
        self.assertFalse(apu.voices[0].active)

    def test_length_clock_and_extra_enable(self):
        apu=APU(); pulse(apu,0)
        apu.write(0xff11,63); apu.write(0xff14,0xc0)
        apu.integrate(8192*RATE-1)
        self.assertTrue(apu.voices[0].active)
        apu.integrate(8192*RATE)
        self.assertFalse(apu.voices[0].active)
        apu.write(0xff11,63); apu.write(0xff14,0x80)
        apu.write(0xff14,0x40)  # Next frame step 1 does not clock length.
        self.assertEqual(apu.voices[0].length,0)
        self.assertFalse(apu.voices[0].active)

    def test_panning_master_zero_nonmute_and_dac(self):
        apu=APU(); pulse(apu)
        apu.write(0xff24,0)
        self.assertEqual(apu.levels()[:2],[15,15])
        apu.write(0xff25,0x10)
        self.assertEqual(apu.levels()[:2],[15,0])
        apu.write(0xff12,0)
        self.assertEqual(apu.levels()[:2],[0,0])
        with self.assertRaisesRegex(AudioError,'VIN'): apu.write(0xff24,0x88)

    def test_exact_area_independent_rectangle_math(self):
        apu=APU(); pulse(apu)
        # Duty 50: initial zero and three more zero steps; next four are high.
        # First 8 periods: +120 for 20 dots, -120 for 12 dots.
        area=apu.integrate(32*RATE)
        self.assertEqual(area[:2],[120*8*RATE]*2)
        apu=APU(); pulse(apu)
        area=apu.integrate(CLOCK)
        # 95.108934 dots; high spans [20,36), [52,68), [84,95.108934).
        high=32*RATE+(CLOCK-84*RATE)
        self.assertEqual(area[:2],[120*(CLOCK-2*high)]*2)


class RenderContractTests(unittest.TestCase):
    def test_clock_no_drift_and_mutation_witness(self):
        for ticks, expected in FIXTURE['clock_frames'].items():
            self.assertEqual(sample_index(int(ticks)),expected)
        self.assertNotEqual(120000*sample_index(1),sample_index(120000))
        self.assertNotEqual(120000*44100//30,sample_index(120000))
        for tick in (1,3,60,120000,10**9):
            exact=tick*70224*44100
            self.assertLessEqual(sample_index(tick)*4194304,exact)
            self.assertLess(exact,(sample_index(tick)+1)*4194304)

    def test_determinism_wav_format_mix_stems_and_no_network(self):
        trace=ir([(0xff11,128),(0xff12,240),(0xff13,255),(0xff14,135)])
        with tempfile.TemporaryDirectory() as d, patch('socket.socket',side_effect=AssertionError('network forbidden')):
            r1=render(trace,Path(d)/'one'); r2=render(trace,Path(d)/'two')
            self.assertEqual(r1,r2)
            frames=[]
            for name in ('mix','pulse1','pulse2','wave','noise'):
                p=Path(d)/'one'/(name+'.wav')
                with wave.open(str(p),'rb') as w:
                    self.assertEqual((w.getframerate(),w.getsampwidth(),w.getnchannels(),w.getnframes()),(44100,2,2,1476))
                    data=w.readframes(w.getnframes()); frames.append(struct.unpack('<'+'h'*(len(data)//2),data))
            for n, mixed in enumerate(frames[0]):
                self.assertLessEqual(abs(mixed-sum(f[n] for f in frames[1:])),3)
                self.assertLessEqual(abs(mixed),32760)
            altered=copy.deepcopy(trace); altered['events'][-3]['value']=128
            r3=render(altered,Path(d)/'mutated')
            self.assertNotEqual(r1['files']['mix.wav']['sha256'],r3['files']['mix.wav']['sha256'])

    def test_fail_closed_bounds_schema_clock_events_and_budget(self):
        bad=[]
        for key,value in [('schema',2),('status','bound'),('ticks',0),('clock',{}),('events',[])]:
            t=ir(); t[key]=value; bad.append(t)
        t=ir(); t['events'].append({'kind':'mystery','tick':0}); bad.append(t)
        t=ir(); t['events'][0]['tick']=1; bad.append(t)
        t=ir(); t['events'][0]['value']=256; bad.append(t)
        t=ir(); t['events'][0]['register']='ff04'; bad.append(t)
        t=ir(status='repeat'); bad.append(t)
        with tempfile.TemporaryDirectory() as d:
            for t in bad:
                with self.assertRaises(AudioError): render(t,Path(d)/'no')
                self.assertFalse((Path(d)/'no').exists())
            with self.assertRaises(AudioError): render(ir(),Path(d)/'no',max_samples=1)
            self.assertFalse((Path(d)/'no').exists())

    def test_loop_and_channel_steal_metadata_not_seamless(self):
        trace=ir(ticks=4,status='repeat')
        trace['repeat']={'start_tick':1,'end_tick':4,'sha256':'score-only'}
        trace['events'] += [{'tick':1,'kind':'ownership','voice':1,'channel':5,'asset':'cry','replaced':None},
                            {'tick':2,'kind':'ownership','voice':1,'channel':5,'asset':None,'resumes':'music'}]
        with tempfile.TemporaryDirectory() as d:
            r=render(trace,Path(d)/'full')
            self.assertFalse(r['loop']['seamless'])
            self.assertFalse(r['loop']['sample_grid_closes'])
            self.assertEqual(r['loop']['loop_samples'],sample_index(4)-sample_index(1))
            self.assertEqual(r['ownership'][0]['sample_floor'],738)
            self.assertEqual(r['ownership'][1]['resumes'],'music')
            self.assertEqual(r['voice_leases']['1'][1]['owner'],{'channel':5,'asset':'cry'})
            self.assertTrue(r['voice_leases']['1'][1]['music_suppressed'])
            self.assertEqual(r['voice_leases']['1'][1]['end_sample_floor'],sample_index(2))
            short=render(trace,Path(d)/'short',preview_ticks=2)
            self.assertIsNone(short['loop']['hardware_state_equal'])
            self.assertTrue(short['preview'])

    def test_reject_active_envelope_semantics_and_keep_bank_wave_bytes(self):
        t=ir([(0xff12,240),(0xff14,128)])
        t['events'].append({'tick':1,'kind':'write','register':'ff12','value':0x91})
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(AudioError,'active envelope'): render(t,Path(d)/'no')
            self.assertFalse((Path(d)/'no').exists())
        # Each bank's traced literal bytes reach RAM unmodified; no universal wave5.
        apu=APU()
        for prefix in ('21e23328e122ffea1014dc10e3415173','ec022091c0072081d0072091c0072ca1','21e23328e122ff22f72422f73424f744'):
            data=bytes.fromhex(prefix)
            for n,b in enumerate(data): apu.write(0xff30+n,b)
            self.assertEqual(apu.ram,[x for b in data for x in (b>>4,b&15)])


if __name__=='__main__': unittest.main()
