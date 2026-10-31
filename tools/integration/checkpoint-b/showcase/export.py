#!/usr/bin/env python3
"""Offline original-time native exporter. Never opens or controls a runtime."""
import argparse
import json
import struct
import subprocess
from pathlib import Path

def write_json(p, a):
    p.write_text(json.dumps(a, indent=2) + '\n')

def stamp(seconds):
    ms = round(seconds * 1000)
    return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('run', type=Path)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--plan', type=Path, help='Reviewed list of label/start/end/title in source-relative seconds')
    args = ap.parse_args()
    run = args.run.resolve(); out = args.output.resolve()
    assert json.loads((run / 'outcome.json').read_text())['ok']
    chapters = json.loads((run / 'chapters.json').read_text())
    assert all(c['status'] == 'complete' for c in chapters)
    out.mkdir(parents=True, exist_ok=False)
    rows = [json.loads(s) for s in (run / 'runtime-data/showcase-frames.jsonl').read_text().splitlines()]
    groups = {}
    for r in rows:
        assert r['phase'] == 'completed'
        p = run / 'frames' / r['file']
        assert struct.unpack('>II', p.read_bytes()[16:24]) == (400, 240)
        groups.setdefault(r['label'], []).append(r)
    durations = {}; gaps = {}
    for label, frames in groups.items():
        assert len(frames) > 1
        assert all(b['tick'] == a['tick'] + 1 and b['time_ms'] > a['time_ms'] for a,b in zip(frames,frames[1:])), label
        # Last frame has no measured successor. End at its timestamp; invent no tail.
        durations[label] = (frames[-1]['time_ms'] - frames[0]['time_ms']) / 1000
        gaps[label] = max(b['time_ms'] - a['time_ms'] for a,b in zip(frames,frames[1:])) / 1000
    write_json(out / 'capture-report.json', dict(durations=durations, max_frame_gap_seconds=gaps,
        dimensions=[400,240], speed=1, audio='none', timing='SDK wall timestamps; final unbounded frame omitted',
        motion_review='pending root; long frame gaps remain visible, not compressed away'))
    def render(name, segments):
        lines = ['ffconcat version 1.0']; used = []; subtitles = []; position = 0
        for seg in segments:
            label = seg['label']; frames = groups[label]; base = frames[0]['time_ms']
            start = float(seg.get('start', 0)); end = float(seg.get('end', durations[label]))
            assert 0 <= start < end <= durations[label] + 1e-6
            first_time = position
            for a,b in zip(frames,frames[1:]):
                t0=(a['time_ms']-base)/1000; t1=(b['time_ms']-base)/1000
                overlap=max(0,min(t1,end)-max(t0,start))
                if not overlap: continue
                p=run/'frames'/a['file']
                # ffconcat's quote escaping, independent of shell escaping.
                quoted=str(p).replace("'", "'\\''")
                lines += [f"file '{quoted}'", "option framerate 1000", f'duration {overlap:.6f}']
                position += overlap
            used.append(dict(seg, output_start=first_time, output_end=position, speed=1))
            subtitles.append(f'{len(subtitles)+1}\n{stamp(first_time)} --> {stamp(position)}\n{seg["title"]}\n')
        # Repeat final image solely to terminate the final measured duration.
        lines += [lines[-3], 'option framerate 1000']; listing=out/(name+'.ffconcat'); listing.write_text('\n'.join(lines)+'\n')
        subprocess.run(['ffmpeg','-v','error','-n','-safe','0','-i',str(listing),'-an',
            '-fps_mode','vfr','-c:v','libx264','-crf','0','-preset','slow','-pix_fmt','yuv420p',
            '-video_track_timescale','1000000','-movflags','+faststart',str(out/(name+'.mp4'))],check=True)
        (out/(name+'.srt')).write_text('\n'.join(subtitles))
        probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(out/(name+'.mp4'))]))
        assert probe['streams'][0]['width']==400 and probe['streams'][0]['height']==240
        assert len(probe['streams'])==1
        assert abs(float(probe['format']['duration'])-position)<0.15
        write_json(out/(name+'.json'),dict(seconds=position, encoder_terminal_frame_seconds=0.001, segments=used, probe=probe, source=str(run)))
        return position
    for label in groups:
        render(label+'-complete', [dict(label=label, title=label+' — complete native capture; original speed; silent, audio held')])
    if not args.plan:
        print('Complete companions exported. Supply a reviewed --plan for the 60–90s native montage.')
        return
    plan=json.loads(args.plan.read_text())
    # Root marks only a reviewed continuous challenge-to-victory interval complete.
    # Approach/return travel may be trimmed; turns inside that interval may not.
    assert any(seg['label'] == 'trainer' and seg.get('complete_battle') is True
               for seg in plan), 'Root must identify a complete uncut trainer battle interval'
    assert {'walk', 'trainer', 'gym', 'cutscene'} <= {seg['label'] for seg in plan}
    write_json(out/'edit-plan.json',plan)
    seconds=render('PokemonBlue-5.5b-showcase',plan)
    if not 60<=seconds<=90:
        raise SystemExit(f'Truthful export is {seconds:.3f}s, outside 60–90s. Complete originals retained; root must review cuts. No padding or acceleration applied.')
    print(f'{seconds:.3f}s, native 400×240, silent, original speed. Root motion and chapter inspection still required.')

if __name__=='__main__':
    main()
