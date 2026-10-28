"""Proportional host checks for the synth adaptation; no runtime/audio claims."""
import os
import unittest
from tools.audio.catalog import Catalog
from tools.audio.scores import ASSETS, ScoreTrace
from tools.audio.source import Source
from tools.audio.trace import Trace

class FullTrace(ScoreTrace):
    snapshot = Trace.snapshot

class ScoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=Catalog(Source(os.environ['POKERED_REFERENCE_DIR']))

    def test_musical_laps_preserve_native_note_onsets(self):
        # Full-register recurrence remains the existing oracle. Compare all note
        # gates, Hz, duties and envelopes through its longer effect-phase cycle.
        for name in ('pallet','route1','wild','trainer'):
            with self.subTest(name=name):
                asset=ASSETS[name]
                small=ScoreTrace(self.catalog,self.catalog.headers[asset]['family']);small.load(asset)
                a=small.run()
                full=FullTrace(self.catalog,self.catalog.headers[asset]['family']);full.load(asset)
                b=full.run()
                self.assertEqual(a['status'],'repeat');self.assertEqual(b['status'],'repeat')
                start,end=a['repeat']['start_tick'],a['ticks']
                expanded=list(small.notes)
                lap=1
                while end+lap*(end-start)<b['ticks']+(end-start):
                    expanded += [[n[0]+lap*(end-start),*n[1:]] for n in small.notes if n[0]>=start]
                    lap+=1
                self.assertEqual([n for n in expanded if n[0]<b['ticks']],full.notes)

    def test_alarm_transition_ticks_match_existing_source_interpreter(self):
        trace=Trace(self.catalog,2)
        trace.run(63,alarm=True)
        triggers=[e['tick'] for e in trace.events if e['kind']=='write'
                  and e['register']=='ff14' and e['owner']=='low-health']
        self.assertEqual(triggers,[0,11,31])  # Full-state repeat stops the run here.

    def test_finite_sfx_have_bounded_gates_and_source_pitch(self):
        for name in ('heal','menu','hit','faint'):
            with self.subTest(name=name):
                asset=ASSETS[name]
                trace=ScoreTrace(self.catalog,self.catalog.headers[asset]['family']);trace.load(asset)
                result=trace.run()
                self.assertEqual(result['status'],'ended')
                self.assertTrue(trace.notes)
                self.assertTrue(all(0<n[2]<=256 and 0<n[4]<=1 for n in trace.notes))
                self.assertTrue(all(n[0]+n[2]<=result['ticks'] for n in trace.notes))
        asset=ASSETS['menu']
        trace=ScoreTrace(self.catalog,2);trace.load(asset);trace.run()
        self.assertAlmostEqual(trace.notes[0][3],131072/(2048-0x7c0),places=3)

if __name__=='__main__': unittest.main()
