# Everyday user review: dictation (Super+F9), 2026-09-29

Checked: the dev checkout at **0.53.0** (`bin/vikix-dictate`, docs, keys). The installed
desktop (`~/vikix`) is still **0.52.1**; Super+F9 / Super+Shift+F9 are bound live by hand to
the dev checkout's script (`exec .../vikix/bin/vikix-dictate toggle|cancel`, read with
`vikix eval`). whisper.cpp v1.9.4 was built in `~/.local/opt/whisper.cpp` and base.en plus
Silero were in `~/.local/share/vikix/whisper`. The CPU is an i7-7500U with 4 threads.

## What I did

- Read docs/ai.md "Dictation" and its trouble rows, the README's "Dictation (`s-F9`)", `vikix dictate --help`,
  `vikix help`, `vikix features`, keys.lisp, the Super+m entry and the features.list line.
- Ran `vikix dictate status`, `models`, `models tiny`, `bogus`, and `dictate` with no argument.
- Ran `vikix dictate file` on jfk.wav and 16 WAVs I made with ffmpeg: silence, white noise,
  loud pink noise, a 440 Hz tone, jfk slowed to 0.7x and sped up to 1.5x, jfk with pink noise, jfk at 44.1 kHz
  stereo, jfk at 48 kHz float, jfk as an MP3, jfk at 5 % volume, jfk with 3 s of silence on
  each side, a 1.2 s clip, a 0.3 s clip, 5.5 min (jfk looped 30 times), an empty file, a
  text file and a missing file. I timed every run.
- **I didn't use the microphone, press any keys or type into a window.** To see what the listening
  flow does (the 5-minute limit, a second press, two dictations in a row), I ran
  `vikix-dictate toggle/stop/cancel` in a **sealed sandbox**, the same way `tests/dictate.sh` does it. It had a fake HOME
  and XDG_RUNTIME_DIR, no DISPLAY and no D-Bus, and `VIKIX_SWANK_PORT=9`. pw-record was replaced by a stand-in that
  "records" jfk.wav, xdotool, xclip and notify-send by stand-ins that only log, and
  `timeout` by one that stops after 3 s instead of 300 s. whisper and the models were the
  real ones. Nothing could reach the mic, the screen or the live bar.

## Findings, most important first

### 1. HIGH: after the 5-minute limit, the next Super+F9 throws the recording away and says "Heard nothing"

- **What happened:** when `timeout 300` ends the recording, nothing tells you (no
  notification), and the bar's `mic` goes away within 10 s. Anyone still talking, or
  who never looked at the bar, then presses Super+F9 to finish. `toggle` sees nobody
  listening, so it **starts** a new recording. `cmd_start` does `: > "$WAV"`, which
  empties the 5-minute file. The next Super+F9 then says **"Heard nothing: Is the microphone
  on?"**. So up to five minutes of speech are gone, and the message sends you off to check a
  microphone that works.
- **Expected:** the first Super+F9 after the limit types what was recorded. At the limit itself, a
  notification such as "Stopped listening after 5 minutes: Super+F9 types it".
- **How to see it:** in the sandbox, with 3 s standing in for 300 s: `toggle`, wait 4 s (the WAV is
  352 KB), `toggle` (it says "Listening…" again, and the WAV is **0 bytes**), `toggle` (it says "Heard
  nothing"). `vikix dictate stop` instead of the second `toggle` does rescue it (the text is typed),
  but no user will know that.
- **Cost:** it hits every dictation longer than five minutes, the one kind where losing the text
  hurts most. The wrong message adds a hunt for a microphone fault.
- **Suggestion:** in `toggle`, treat a leftover recording as something to stop:
  `if listening || [ -s "$WAV" ]; then cmd_stop; else cmd_start; fi`. Run the recorder as
  `( timeout ...; [ $? = 124 ] && note "Stopped listening after 5 minutes" "Super+F9 types it" ) &`.
  Also mention the limit in docs/ai.md and `--help` (only the README has it).
- Not in TODO.md.

### 2. MEDIUM: a second press while it's "Writing it down…" loses the second dictation

- **What happened:** pressing stop removes the pid file before whisper runs, so a Super+F9 during those
  2–3 s starts a new recording into **the same file name**. The first stop then finishes and runs
  `rm -f "$WAV"`, which deletes the file the new recording is writing into. When you stop the second
  one, you get "Heard nothing".
- **How to see it:** in the sandbox: `toggle`, `toggle &`, then `toggle` 0.6 s later. The first text
  is typed and "Listening…" shows, but the runtime folder is **empty** while the recorder is still
  running.
- **Cost:** it happens to people who dictate in short bursts ("sentence, press, press, next
  sentence"). The second part is lost without a trace.
- **Suggestion:** at stop, `mv "$WAV" "$WAV.writing"` (or use a `mktemp` name per recording) and
  transcribe and delete that file. Then a new recording can't be touched.
- Not in TODO.md.

### 3. MEDIUM: text goes where the focus is when writing down finishes, not when you press Super+F9

- **What happened:** the trouble table says "It types where the focus is when you press the second
  Super+F9". In fact `xdotool type` runs after transcription, which takes 2.3–3 s for a sentence and
  **57 s for a 5.5-minute dictation**. Typing then runs at 8 ms a character, so the 3,364
  characters of that dictation take about **27 s more**. Switching workspace, clicking or typing in
  that window sends the text somewhere else, or mixes your keys into it. The "Writing it down…"
  notification lasts 60 s, so for a long dictation it disappears before the text arrives, and
  nothing shows while it types.
- **Expected:** it types where I was when I pressed the key, or it doesn't type at all.
- **Suggestion:** at stop, save `xdotool getactivewindow`. Before typing, if the active window
  has changed, don't type: show "It's on the clipboard (the window changed)". Fix the doc
  line either way. For long texts (more than a few hundred characters), pasting from the
  clipboard is much faster than typing it out, though terminals and Emacs need different paste keys.
- Not in TODO.md.

### 4. MEDIUM-LOW: two dictations in a row are glued together

- **What happened:** the text has no leading or trailing space, so dictating two sentences
  into the same box gives `...for your country.And so my fellow...` (sandbox, two
  toggles in a row, what xdotool was asked to type).
- **Cost:** every multi-part dictation into a chat or email box needs a manual fix.
- **Suggestion:** type a trailing space when the text ends in `.?!,` (most dictation tools do).
  Or add a `space=` setting in `~/.config/vikix/dictation`, and mention it in the docs.
- On the good side, there's no trailing newline, so a sentence dictated into a terminal is never run (see "what felt good").

### 5. LOW: "MODEL_SHA: bad array subscript" for anyone without a dictation config yet

- **What happened:** with no `~/.config/vikix/dictation` file (a new user, before setup writes
  it), `vikix dictate status`, `models` and `setup` print
  `bin/vikix-dictate: line 63: MODEL_SHA: bad array subscript`, sometimes twice, before the
  real answer. Today's setup log (in the job's tmp folder) shows it in the middle of setup too.
- **How to see it:** `HOME=<empty dir> bin/vikix dictate status`, or move the config aside.
- **Cost:** it's the very first thing a curious new user runs, and it reads like a bug.
- **Suggestion:** in `model_name`, `[ -n "$m" ] && [ -n "${MODEL_SHA[$m]:-}" ]`. A test
  with no config file would catch it.

### 6. LOW: setup prints a screenful of git and CMake noise

- **What happened:** the setup log from this morning (2 min 0 s, the same as the README's "about two
  minutes") shows `warning: refs/tags/v1.9.4 ... is not a commit!`, git's 10-line
  "detached HEAD" advice, and a CMake "Deprecation Warning" block, in among Vikix's
  `::` lines. A user can't tell whether any of it matters.
- **Suggestion:** `git -c advice.detachedHead=false`, and send the cmake configure's stderr to a log
  that is shown only if it fails.

### 7. LOW: `vikix dictate file` is silent on files it can't read

- An empty file or a text file named `.wav` prints an empty line and exits 0. A missing
  file prints `xx vikix dictate file WAV`, which is the usage line and never says the file isn't there.
- **Suggestion:** "can't read FILE" for a missing file, and report whisper's failure instead
  of returning an empty result.

### 8. LOW: the docs give three different speeds, and leave out the 5-minute limit

- My measurements: the jfk sample (11 s) took **2.7–2.8 s**, 1.2 s of speech **2.3 s** (that's the floor,
  the model loading), and 5.5 min **57 s**. The claims: docs/ai.md says "a sentence in about a second", `--help`
  "a second or two a sentence", and the README "11 s in about 3.5 s".
- **Suggestion:** say "two or three seconds a sentence" everywhere. Also add "about 10 s a
  minute of speech", so people know a long dictation takes a while.
- `--help` names Super+F9 but not **Super+Shift+F9** (cancel) or the 5-minute limit.
- The "not set up" notification and `status` say `vikix dictate setup`, while the docs and trouble
  table say `vikix add dictation`. Both work, but it's worth picking one.
- The Super+m menu has "Dictation: start, or stop and type it", but no cancel and no
  "switch model". That's fine, but changing language needs a terminal.

### 9. LOW: some things vanish from the text, and a very short clip can be misheard

- Anything in `()`, `[]` or between `*` is removed from the text (to drop "(music)"). Whisper
  rarely writes real speech that way, but a dictated aside such as "(on Tuesday)" would vanish
  without a word. I couldn't check this without a microphone. It's worth a note in the docs.
- A 1.2 s clip ("And so my…") came out as **"And so am I."**, a confident, well-formed
  sentence that wasn't said. Clips of 0.3 s gave nothing, which is right. The docs could suggest
  "speak a whole sentence".

### 10. NOT TESTED (needs the VM): holding Super+F9

- The docs explain why holding the key doesn't work. Still, people used to push-to-talk will hold it. X
  auto-repeats a held key (grabbed keys included), so I expect a burst of start/stop/start
  toggles, which together with finding 2 would lose audio. Worth checking in `void-vm`.
- **Suggestion:** ignore a toggle less than about 0.7 s after the previous one (a timestamp file).
  That also handles a double tap.

### 11. PRIVACY: the claims hold, with two small gaps

- Checked in the sandbox and in the code: the recording goes in `$XDG_RUNTIME_DIR`, which is tmpfs
  `/run/user/1000`, mode 700, with the file 600. It's deleted after stop and after cancel, and whisper
  runs locally with no network use. That matches "the recording is deleted once it's written down".
- The gaps: (a) after the 5-minute limit the recording stays until the next press (see finding 1).
  (b) The *text* is kept in the clipboard history (clipmenud, Super+c) and in the "Typed"
  notification (the notification history, Super+Shift+n) for the rest of the session. Worth one line in
  docs/ai.md for anyone dictating something private.

## Accuracy results (base.en, `vikix dictate file`)

| Recording | Time | Result |
|---|---|---|
| jfk 11 s | 2.7 s | Correct, with capitals and full stops |
| slowed 0.7x / sped up 1.5x | 2.9 s | Correct (1.5x: a comma instead of the full stop) |
| jfk with pink noise | 2.8 s | "fellow America," (one word wrong) |
| 44.1 kHz stereo, 48 kHz float, MP3 | 2.8–3.0 s | Correct: other formats are converted |
| 5 % volume | 2.8 s | Correct |
| 3 s silence + jfk + 3 s silence | 3.2 s | Correct |
| silence, white noise, loud pink noise, tone, 0.3 s | 0.2 s | Nothing (right) |
| 1.2 s clip | 2.3 s | "And so am I." (misheard) |
| 5.5 min loop | 57 s | One line, 3,364 characters, 29 of 30 repeats plus one garbled |

## What felt good

- **It's fast and clean:** a sentence comes back capitalised and punctuated, with no stray spaces and
  no trailing newline. That means it can't run a command in a terminal by accident, which is the right call.
- **Silence and noise type nothing**, and they're rejected in 0.2 s, just as the docs promise. The
  voice detector earns its place.
- **Any recording works:** stereo, 44.1/48 kHz, float, MP3 and very quiet audio all came out right.
- **The notifications read well:** "Listening… Super+F9 again types what you said
  (Super+Shift+F9 cancels)" teaches the cancel key when it's needed. "Writing it down… on this
  laptop (base.en)" says where the audio goes. "Heard nothing: Is the microphone on?
  (pavucontrol, Input devices)" gives a next step.
- **Always on the clipboard too**, so a window that ignores xdotool doesn't lose the text.
- `--clearmodifiers` deals with Super still being held at the second press.
- `vikix dictate` with no argument shows the help, and a wrong model name gives a helpful error ("no model
  called tiny: base.en or small"). `vikix dictate models` shows what's used and what's downloaded
  at a glance.
- Setup is honest: pinned commit, checked checksums, no password, and two minutes as the README says.
  `vikix features` shows it with its key, and the menu entry is hidden until it's set up.
