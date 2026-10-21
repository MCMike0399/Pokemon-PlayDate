#!/usr/bin/env python3
"""Observed Simulator frame intervals/heap; includes trace and PNG capture overhead."""
import argparse
import json
import statistics
from pathlib import Path


def profile(root):
    report={'schema':1,'measurement':'observed Simulator consecutive active frame intervals including harness capture/trace overhead; not isolated NPC CPU time or device capacity', 'traces':[]}
    root=Path(root)
    paths=sorted((root/'processes').glob('*/trace.jsonl')) if (root/'processes').is_dir() else []
    if not paths:
        paths=[root/'trace.jsonl'] if (root/'trace.jsonl').is_file() else [root/'runtime-data/trace.jsonl'] if (root/'runtime-data/trace.jsonl').is_file() else []
    for path in paths:
        rows=[json.loads(line) for line in path.read_text().splitlines() if line.strip()]
        intervals=[];heap=[];previous=None;moving=0
        for row in rows:
            state=row.get('snapshot',{});motion=state.get('world_motion',{})
            active=state.get('root')=='overworld' and motion.get('paused') is False
            if active:
                sample=state.get('performance',{}).get('heap_kib')
                if isinstance(sample,(int,float)):heap.append(sample)
                actors=motion.get('live',{}).get('actors',[])
                if any(a.get('phase')=='moving' for a in actors):moving+=1
                if previous and row.get('tick')==previous.get('tick',-2)+1:
                    delta=row.get('time_ms',0)-previous.get('time_ms',0)
                    if delta>=0:intervals.append(delta)
                previous=row
            else:previous=None
        item={'trace':str(path),'active_intervals':len(intervals),'active_moving_samples':moving}
        if intervals:
            ordered=sorted(intervals);item['interval_ms']={'min':min(intervals),'median':statistics.median(intervals),'p95':ordered[min(len(ordered)-1,int(len(ordered)*.95))],'max':max(intervals)}
        if heap:item['heap_kib']={'first':heap[0],'last':heap[-1],'min':min(heap),'max':max(heap)}
        report['traces'].append(item)
    if not report['traces']:raise ValueError('no completed runtime traces')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('run',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    args.output.write_text(json.dumps(profile(args.run),indent=2)+'\n');print(args.output)
