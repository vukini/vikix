"""Finite, device-free exports. Publish a complete new batch, never overwrite one."""
import datetime
import json
import math
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import tempfile
import uuid
import wave

from launcher import data_dir, end, message

RATE = 48000
PPQ = 9600
DRUMS = {'kick': 36, 'snare': 38, 'closed-hat': 42}
ATTACK = {'sine': .005, 'bass': .005, 'kick': .003, 'bell': .003, 'snare': .002}


def child_run(argv, timeout):
    child = None
    try:
        child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = child.communicate(timeout=timeout)
        if child.returncode or b'FAILURE' in out + err or b'ERROR' in out + err:
            raise RuntimeError('offline child failed: ' + (err + out).decode(errors='replace')[-2000:])
        return out
    finally:
        end(child)


def vlq(value):
    result = [value & 127]
    while value > 127:
        value >>= 7
        result.insert(0, (value & 127) | 128)
    return bytes(result)


def midi(pattern):
    tempo = round(60000000 / pattern['bpm'])
    tick = lambda seconds: round(seconds * 1000000 * PPQ / tempo)
    events = [(0, b'\xff\x51\x03' + tempo.to_bytes(3, 'big')),
              (0, b'\xff\x58\x04\x04\x02\x18\x08')]
    for at, freq, dur, gain, sound in pattern['events']:
        if gain == 0:
            continue
        channel = 9 if sound in DRUMS else 0
        pitch = DRUMS.get(sound, round(69 + 12 * math.log2(freq / 440)))
        velocity = max(1, min(127, round(127 * gain / .08)))
        events.extend(((tick(at), bytes((0x90 + channel, pitch, velocity))),
                       (tick(at + dur), bytes((0x80 + channel, pitch, 0)))))
    # Note-offs sort before note-ons at the same tick.
    events.sort(key=lambda event: (event[0], 0 if event[1][0] == 255 else 1, event[1]))
    events.append((max(tick(pattern['duration']), events[-1][0]), b'\xff\x2f\x00'))
    track, previous = bytearray(), 0
    for at, payload in events:
        track.extend(vlq(at - previous) + payload)
        previous = at
    return (b'MThd' + struct.pack('>IHHH', 6, 0, 1, PPQ) +
            b'MTrk' + struct.pack('>I', len(track)) + track)


def bundle(at, *messages):
    data = b'#bundle\0' + struct.pack('>Q', round(at * 2**32))
    for item in messages:
        data += struct.pack('>I', len(item)) + item
    return struct.pack('>I', len(data)) + data


def render(pattern, synth, folder, output):
    # A short silent preparation interval lets d_recv finish before the first note.
    lead = .1
    score = bytearray(bundle(0, message('/d_recv', synth)))
    for index, (at, freq, dur, gain, sound) in enumerate(pattern['events']):
        voice = 'tone' if sound == 'sine' else sound
        score.extend(bundle(at + lead, message('/s_new', 'vikix-' + voice, 1000 + index,
                                               0, 0, 'freq', float(freq), 'dur', float(dur),
                                               'amp', float(gain))))
    # Keep complete bars, adding only enough tail for any last envelope to finish.
    duration = max([pattern['duration']] +
                   [at + (.061 if sound == 'closed-hat' else dur + ATTACK[sound]) + 128 / RATE
                    for at, freq, dur, gain, sound in pattern['events']])
    frames = round(duration * RATE)
    score.extend(bundle(lead + duration + .1, message('/c_set', 0, 0)))
    source, raw = folder / 'score.osc', folder / 'raw.wav'
    source.write_bytes(score)
    child_run(['scsynth', '-D', '0', '-R', '0', '-i', '0', '-o', '2', '-z', '64',
               '-N', str(source), '_', str(raw), str(RATE), 'WAV', 'int16'],
              max(30, duration * 2 + 10))
    with wave.open(str(raw)) as incoming:
        if (incoming.getnchannels(), incoming.getsampwidth(), incoming.getframerate()) != (2, 2, RATE):
            raise RuntimeError('unexpected offline WAV format')
        incoming.setpos(round(lead * RATE))
        with wave.open(str(output), 'wb') as outgoing:
            outgoing.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
            remaining = frames
            while remaining:
                count = min(remaining, RATE)
                data = incoming.readframes(count)
                if len(data) != count * 4:
                    raise RuntimeError('offline WAV ended early')
                outgoing.writeframesraw(data)
                remaining -= count
    source.unlink()
    raw.unlink()
    return frames / RATE


def send_score(root, args):
    if not 1 <= args.repeat <= 16:
        raise RuntimeError('repeat must be 1 to 16')
    previous = {}
    def interrupted(signum, frame):
        # A second signal must not interrupt child reaping or temporary-file cleanup.
        for sig in previous:
            signal.signal(sig, signal.SIG_IGN)
        raise KeyboardInterrupt
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        previous[sig] = signal.signal(sig, interrupted)
    try:
        path = Path(args.file).expanduser().resolve(strict=True)
        patterns = json.loads(child_run(
            ['sbcl', '--noinform', '--no-sysinit', '--no-userinit', '--script',
             str(root / 'lib/music/export.lisp'), str(path), args.pattern or '', str(args.repeat)], 15))
        synth = (data_dir() / 'palette-v1.scsyndef').read_bytes() if args.format != 'midi' else None
        destination = path.parent / 'render'
        destination.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.send-', dir=destination) as temp:
            staging = Path(temp)
            batch = staging / 'batch'
            batch.mkdir()
            manifest = {'source': path.name, 'repeat': args.repeat, 'format': args.format,
                        'session_gain': .08, 'patterns': []}
            for index, pattern in enumerate(patterns, 1):
                stem = f'{index:02d}-' + (re.sub(r'[^a-z0-9-]', '_', pattern['name'].lower())[:80] or 'pattern')
                entry = {k: pattern[k] for k in ('name', 'bpm', 'duration')}
                if args.format != 'wav':
                    entry['midi'] = stem + '.mid'
                    (batch / entry['midi']).write_bytes(midi(pattern))
                if args.format != 'midi':
                    entry['wav'] = stem + '.wav'
                    entry['wav_duration'] = render(pattern, synth, staging, batch / entry['wav'])
                manifest['patterns'].append(entry)
            (batch / 'export.json').write_text(json.dumps(manifest, indent=2) + '\n')
            name = datetime.datetime.now(datetime.timezone.utc).strftime('send-%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex
            final = destination / name
            os.rename(batch, final)
        print(final)
        return 0
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
