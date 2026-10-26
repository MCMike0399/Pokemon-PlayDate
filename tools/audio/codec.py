"""Macro byte encoder; pointers use isolated data-section offsets, never ROM addresses."""
from .source import AudioError, number

PITCHES = dict(zip(('C_', 'C#', 'D_', 'D#', 'E_', 'F_', 'F#', 'G_', 'G#', 'A_', 'A#', 'B_'), range(12)))
ARITY = {'note': 2, 'rest': 1, 'drum_note': 2, 'drum_speed': 1,
         'note_type': 3, 'octave': 1, 'tempo': 1, 'volume': 2,
         'square_note': 4, 'noise_note': 4, 'pitch_sweep': 2,
         'duty_cycle': 1, 'duty_cycle_pattern': 4, 'vibrato': 3,
         'pitch_slide': 3, 'stereo_panning': 2, 'execute_music': 0,
         'toggle_perfect_pitch': 0, 'sound_call': 1, 'sound_loop': 2,
         'sound_ret': 0, 'unknownmusic0xef': 1}


def signed_nibble(n):
    return (8 | -n) if n < 0 else n


def encode(op, args, resolve=lambda x: 0):
    if op not in ARITY or len(args) != ARITY[op]:
        raise AudioError(f'unsupported macro/arity {op} {args}')
    a = [number(v, PITCHES) for v in args[:(-1 if op in ('sound_call', 'sound_loop') else None)]]
    word = lambda n: [n & 255, (n >> 8) & 255]
    if op == 'note': out = [a[0] << 4 | (a[1]-1)]
    elif op == 'rest': out = [0xc0 | (a[0]-1)]
    elif op == 'drum_note': out = [0xb0 | (a[1]-1), a[0]]
    elif op == 'drum_speed': out = [0xd0 | a[0]]
    elif op == 'note_type': out = [0xd0 | a[0], a[1] << 4 | signed_nibble(a[2])]
    elif op == 'octave': out = [0xe0 | (8-a[0])]
    elif op == 'tempo': out = [0xed, a[0] >> 8, a[0] & 255]
    elif op in ('square_note', 'noise_note'):
        out = [0x20 | a[0], a[1] << 4 | signed_nibble(a[2])]
        out += word(a[3]) if op == 'square_note' else [a[3]]
    elif op == 'pitch_sweep': out = [0x10, a[0] << 4 | signed_nibble(a[1])]
    elif op == 'duty_cycle': out = [0xec, a[0]]
    elif op == 'duty_cycle_pattern': out = [0xfc, a[0]<<6 | a[1]<<4 | a[2]<<2 | a[3]]
    elif op == 'vibrato': out = [0xea, a[0], a[1]<<4 | a[2]]
    elif op == 'pitch_slide': out = [0xeb, (a[0]-1) & 255, (8-a[1])<<4 | a[2]]
    elif op in ('volume', 'stereo_panning'): out = [0xf0 if op == 'volume' else 0xee, a[0]<<4 | a[1]]
    elif op == 'sound_call': out = [0xfd] + word(resolve(args[-1]))
    elif op == 'sound_loop': out = [0xfe, a[0]] + word(resolve(args[-1]))
    elif op == 'unknownmusic0xef': out = [0xef, a[0]]
    else: out = [{'execute_music': 0xf8, 'toggle_perfect_pitch': 0xe8, 'sound_ret': 0xff}[op]]
    if any(not 0 <= n <= 255 for n in out):
        raise AudioError(f'byte overflow in {op} {args}')
    return bytes(out)
