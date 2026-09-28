# Everyday user: local AI models (Vikix 0.43.0), 2026-09-28

Checked: dev checkout `VERSION` 0.43.0. The installed `~/vikix` was 0.42.1 when I started. The user ran `vikix update` at 11:49 while I was working, and after that it was 0.43.0 (commit 7a977a1) too. Machine: i7-7500U (4 threads), 15 GB RAM, no graphics card used. Ollama 0.34.4, with `llama3.2:3b` already downloaded.

What I did: read the README's "Local AI models" section, the bar's `ai` line, the skill line and the entries in `docs/map.md`. Ran `help`, `status`, `list` and `models --print`, plus a few wrong inputs. Ran every subcommand in a throwaway HOME, which is now deleted. Did one cold `ollama run llama3.2:3b` prompt, then `stop`. Took one screenshot of the bar.

Overall: this works well, and it's honest. The problems are about what happens *after* setup, and a few rough messages.

---

## 1. After setup, a non-technical person has nowhere to go except `ollama run` in a terminal

- **What happened:** setup ends with "Next, choose a model". The download ends with "ready. Try it: ollama run llama3.2:3b". After that, nothing on the desktop lets you talk to the model: Super+m only has "choose a model" and "unload the model". The README also skips how to leave `ollama run` (`/bye` or Ctrl+D) and doesn't say that it keeps your prompts in `~/.ollama/history`.
- **Expected:** one obvious way to ask it something.
- **How to see it:** Super+m, then type "Local AI". There are two entries, and neither of them talks to a model.
- **Cost:** this hits every user who isn't a terminal person, on day one. They downloaded 2 GB and can't find the "use it" button.
- **Suggestion:** a Super+m entry "Local AI: talk to a model" that opens a terminal running `ollama run <the model you have>` (the first in `ollama list`, or a rofi pick when there are several). Add one README line: "type `/bye` or Ctrl+D to leave; your questions are kept in `~/.ollama/history`". TODO item 1 (`llm`) helps shell users but not this.
- **In TODO.md:** no (item 1 `llm` and item 7 `~/dev/ai` are nearby, but neither is a desktop entry).

## 2. "fast / well / slowly" don't say how long you wait

- **What happened:** the picker says `runs well` for llama3.2:3b. I measured it cold on this laptop: about 4 s to load the model, then about 11 s to write two sentences (roughly 8 tokens/s). That's 15.4 s in total before the prompt came back. Once loaded, the next answer skips the 4 s. The README and the picker say nothing about seconds, so "slowly" for 7–8B could mean 30 s or 5 minutes.
- **Expected:** a rough sense of how long I wait, stated where I choose.
- **How to see it:** `vikix ai stop; time ollama run llama3.2:3b "In two sentences: what is a window manager?"`.
- **Cost:** people pick blind, often the 8B "best here" one. They wait, and decide local AI is broken.
- **Suggestion:** put a timing next to each word in the picker's header and the README, e.g. "fast: a paragraph in a few seconds; well: about 10 s; slowly: a minute or more. The first question after a pause adds a few seconds of loading." Measure the 1B and 8B cases on this X1 once and write the numbers down.
- **In TODO.md:** no.

## 3. One model, four sizes

- **What happened:** llama3.2:3b shows up as:
  - 2.02 GB in the picker
  - 2.0 GB in `vikix ai list`
  - 1.9G in `vikix ai status` (`du -h`, in GiB)
  - 2 GB in the README
  - 2.56 GB in memory while loaded (Ollama's `/api/ps`), which the README only calls "a few GB"

  Memory in use went up by about 2.4 GB when it loaded and came back down by about 2 GB after `stop`. So freeing works, but nothing tells you the number.
- **Expected:** one number for disk and one for memory.
- **How to see it:** run `vikix ai models --print`, `vikix ai list` and `vikix ai status` one after another.
- **Cost:** small, but it makes you wonder whether something is off. The memory number is the one people need before starting it next to Firefox and the Windows VM, and it's the one that's missing.
- **Suggestion:** `status` shows `loaded: llama3.2:3b (2.6 GB of memory, unloads at 11:54)`. Both come straight from `/api/ps` (`size`, `expires_at`). Use `du -sh --si` so the disk figure is in GB like the others.
- **In TODO.md:** no.

## 4. Ollama's terminal control codes leak into Vikix's messages

- **What happened:** `vikix ai stop` prints `^[[?2026h^[[?25l^[[1G^[[K…` before ":: unloaded llama3.2:3b". `vikix ai remove nosuch:1b` prints the same codes before "Error: model 'nosuch:1b' not found". In a terminal that's mostly invisible, but the codes show up when the output is piped or logged.
- **How to see it:** `vikix ai stop 2>&1 | cat -v`.
- **Cost:** low, but it looks broken wherever the output is captured.
- **Suggestion:** in `vikix-local-ai`, run `ollama stop`/`rm` with `2>/dev/null` (Vikix already prints its own line), or unload through the API (`POST /api/generate {"model":M,"keep_alive":0}`). For `remove`, check the name against `ollama list` first and say "you don't have nosuch:1b; vikix ai list shows what you have".
- **In TODO.md:** no.

## 5. `vikix ai remove` with no model gives a bash error

- **What happened:** it prints `/home/…/bin/vikix-local-ai: line 230: 1: which model? vikix ai list`. `pull` without a model does the same.
- **Expected:** `xx which model? vikix ai list`, formatted like every other Vikix error.
- **Suggestion:** replace `${1:?…}` with `[ -n "${1:-}" ] || die "which model? …"`.
- **In TODO.md:** no.

## 6. How to remove it all isn't written anywhere

- **What happened:** you can delete one model, but there's no "remove local AI" and no README line explaining how. The pieces are `~/.local/opt/ollama` (98 MB), `~/.ollama/` (models, history, an ssh key Ollama makes), the `~/.local/bin/ollama` link, `~/.local/state/vikix/ollama.log`, and a block in `backup-exclude`. The session also starts it at every login for as long as `~/.local/opt/ollama/bin/ollama` exists.
- **Suggestion:** a `vikix ai remove-all` (or `setup --undo`) that deletes those files. Or at the least, a README line: "To remove it all: `rm -rf ~/.local/opt/ollama ~/.ollama ~/.local/bin/ollama`; it stops starting at the next login."
- **In TODO.md:** no.

## 7. `vikix help` doesn't mention local models

- **What happened:** the top-level help lists only `vikix ai key set|list|remove|check`. You find `setup/models/…` only through `vikix ai help`, which points to `bin/vikix-local-ai: vikix ai help-local`, a path a user shouldn't need to see.
- **Suggestion:** add one line to `vikix help`: `vikix ai setup|models|list|remove|status|stop   AI models on this machine (Ollama)`. In `vikix ai help`, say "vikix ai help-local for the details" without the file path.
- **In TODO.md:** no.

## 8. Super+m "Local AI: unload the model" gives no feedback

- **What happened:** it runs `vikix-local-ai stop` with nothing on screen. The only sign it worked is `ai` leaving the bar. Before setup the same entry fails silently. The "choose a model" entry is better: before setup it shows a notification, "Local AI isn't set up / In a terminal: vikix ai setup (no password needed)".
- **Suggestion:** have the menu entry send a notification: "Unloaded llama3.2:3b" / "No model was loaded" / "Local AI isn't set up".
- **In TODO.md:** no.

## 9. Small mismatches

- The README says the kept parts are "about 115 MB", but `du -sh ~/.local/opt/ollama` gives 98M. The script's own help says "its CPU parts" while setup keeps Vulkan's too (the README says both).
- `~/.local/state/vikix/ollama.log` is in neither `docs/map.md` nor `docs/fixing.md`, yet it's what `need_running` points to when Ollama won't start. It's also append-only: 87 KB and 1068 lines after about 20 minutes and a few prompts, and nothing rotates it. Suggestion: list it in map.md, add a "Local AI won't start" line to fixing.md, and truncate it when `serve` starts.
- `vikix doctor` says nothing about local AI (e.g. "installed but not running").
- The bar's `ai` can show up to 15 s late after a model loads (the serve loop polls every 15 s). `stop` clears it at once. That's fine, just worth knowing.
- Not a bug, but it surprised me: `vikix ai status` said "unknown command" at first because the desktop was still 0.42.1. That was because the update hadn't run yet.

---

## What felt good

- **Before setup, every command says the one thing to do.** `list`, `stop`, `models` and `remove` print "Ollama isn't installed: vikix ai setup", and `status` prints "Ollama: not installed (vikix ai setup)" with exit code 0. The Super+m picker shows a notification instead of doing nothing. Keep it that way.
- **`status` is instant (0.05 s) and answers the right questions:** is it installed, is it running and only here, which model is loaded, how much disk. `(not backed up)` answers a question before you ask it.
- **The picker is honest and readable.** One line per model with what it's for, a ✓ for what you have, the machine's memory in the header, and models too big for this machine left out instead of offered with a warning. "Bigger answers better, and slower." is the right one-line lesson.
- **Memory looks after itself.** It unloads after 5 minutes, `stop` frees about 2 GB right away, and the bar's `ai` (screenshot `.claude/reports/shots/local-ai-bar.png`) appears and disappears with the model. It's in the quiet colour, so it informs without nagging.
- **No password, nothing system-wide, checksum checked, only 98 MB kept out of a 1.4 GB download, models left out of backups automatically.** The README says all of this in five bullets.
- **Speed is fine for a 2017 laptop:** a two-sentence answer from the 3B model in about 15 s cold, less once it's loaded. "Runs well" is fair.
