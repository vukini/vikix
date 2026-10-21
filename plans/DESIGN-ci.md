# Vikix CI and tests — design

Tests that hold when the machine is busy, CI that shows every failure at once, and a release that doesn't take five tries.

Drafted 2026-10-18 from Groki's handover after the 0.72.97 release night (studied at 0.72.95, `63b82eb`; written against 0.72.97, `55cbc56`). Nothing here is decided yet: the order is the handover's, and item 4's first point is a policy for Vid to choose. Kept honest like the other designs: what ships is deleted here, what changes is dated. Its partner, `DESIGN-dependable.md`, is about the machine itself; `DESIGN-accelerators.md` builds on items 3 and 4 here.

---

## Where things stand (2026-10-18)

- **0.72.97** (`55cbc56`, tag `v0.72.97`) made CI green again for `void` and `editors`, for the first time since 2026-10-15: the `editors` job runs under `shell: bash` and installs `packages/emacs.list`, `neovim.list` and `editor-tools.list`; `tests/house.sh` defines `close()` once, before its first use (shellcheck SC2218); `tests/lint.sh` uses `grep -d skip`; the Void jobs install `void-repo-nonfree`, `void-repo-multilib` and `void-repo-multilib-nonfree`, then `xbps-install -S`. `tests/lisp.sh` goes on past `sb-ext:package-locked-error` with stand-ins for StumpWM's functions, and `lib/md2texi.py` moves a link in a table's first column off the `@item` line, since makeinfo 7.1 warns.
- **`lint` is still red** (run 39132865581), at `tests/ci.sh man`: `FAIL: man doesn't show vikix-backup's prose` (`tests/man.sh`, the grep for `Every backup is encrypted` in `MANWIDTH=80 man -M … vikix-backup | col -b`). Not looked into. Likely: Ubuntu's man-db and groff justify or hyphenate that line differently from the laptop, so the fixed-string grep misses. The lint steps run one after another, so more may be hidden behind it. (Also in `bugs.md`.) *2026-10-20: fixed. groff justified the paragraph with tabs and hyphenated the password file's path; the page now asks for ragged right and no hyphenation (`.ds AD l`, `.ad l`, `.nh` after `.TH` in `lib/man.py`), and `tests/man.sh` renders with groff as well when it is installed.*
- **`packages/repos.list` lacks the multilib repositories**: only CI was changed.
- 0.72.97 went out with `.claude/release --tests none`, Vid's call. Every failure in the five tries was a load or timing flake that passed alone (queue, main, viri, what, house, plan, music, vm), except `info`, which was real and is fixed.

## Why the release took five tries

1. **Load.** With other agents testing, the load sat at 7 to 9 on 4 cores. Each full `--changed` run (25 to 30 minutes, most of the suite) failed on a different timing test.
2. **`tests/queue.sh`** ("a process no agent is above is found by its folder…") fails whenever another run's tests wait for a slot: it isn't kept apart from the other runs on the machine.
3. **`tests/docs.sh`** ("no key, --claude says so") fails when `ANTHROPIC_API_KEY` is in the environment, and `vikix.bash` exports it to every shell. The way round was `env -u ANTHROPIC_API_KEY .claude/release …`.
4. A failed release writes over `.git/vikix-release-tests.log`, and an outer `timeout` on `.claude/release` ends the script but leaves `tests/run.sh` orphaned.

## The plan

In order of value. Each is small enough for one commit and a test.

### 1. CI shows every failure, and runs once (`.github/workflows/test.yml`)

- ~~`if: ${{ !cancelled() }}` on each test step; `install-info`; `on: push: branches: ['**']`; one version of `actions/checkout`~~ (done 2026-10-22: every `tests/ci.sh` step runs after a failed one, a tag push runs nothing, `pages.yml` at `@v5`).
- ~~Fix the `man` failure~~ (done 2026-10-20, see above).

### 2. One version of each tool, said aloud (`tests/lint.sh`)

- SC2218 fires with shellcheck 0.10 and older but not 0.11, which the laptop has. Pin one version for both (`uvx --from shellcheck-py==0.11.0.1 shellcheck`) and print it.
- Print `sbcl --version` and `makeinfo --version` in the lisp and info tests.

### 3. Tests that hold under load (`tests/run.sh`, `tests/lib/wm.sh`)

- **Weighted slots:** a test that sources `wm.sh` (Xvfb, SBCL, Alacritty) takes two slots, or draws from an X pool of its own, `max(1, nproc/2)`.
- **A load gate** before the heavy tests, with a bound: wait up to about 120 seconds for the one-minute load to fall below the cores.
- **Waiting for what is expected, not for a time:** `key(){ xdotool key; sleep 0.5; }` becomes `wait_for FORM EXPECTED [TIMEOUT]` and `key_until`; `win` fails loudly when a window never comes; deadlines scale by `VIKIX_TEST_SLACK`.
- ~~**Once more, alone**~~ (done 2026-10-22: a test that sources `tests/lib/wm.sh` or starts an Xvfb and fails runs again by itself, once, through the `alone` slot; passing then it counts as passed, the run says *passed once more alone* and names it, and a tab-separated line goes into `~/.local/state/vikix/test-flakes.log`: when, commit, test, the load as the run began, its first FAIL lines. A plain test, a single named test and `VIKIX_TEST_RETRY=0` keep the first answer. `tests/queue.sh`.) Left: looking at the flakes log after some weeks, to mend the tests that are in it most.
- **`tests/queue.sh` with slots of its own** (a private slots folder), so other runs' waiting doesn't reach it.
- earlyoom prefers to end Xvfb and sbcl: consider exempting test sessions.

### 4. Releases that don't stall (`.claude/release`)

- **For Vid to decide:** test before taking the global release lock (rebase at the desk, test, then lock), and when `main` moved only in files the desk doesn't touch, run just the changed delta again.
- ~~One log a release; the load and the other runs' tests at the start; the retry once alone~~ (done 2026-10-22: `.git/vikix-release-tests/TOPIC-TIME.log`, kept whether the run passed or not; the load and how many tests of other runs are on the machine, said as the tests begin; the flaky line after a pass).

### 5. Hermetic tests (`tests/run.sh`, `tests/ci.sh`)

- Unset `*_API_KEY`, `*_KEY`, `*_TOKEN`, `*_SECRET`, `CLAUDE_CODE_*`, `CLAUDECODE`, `OLLAMA_HOST` and `ANTHROPIC_BASE_URL` for every test, as `drop_keys` in `lib/common.sh` does for the installer and `vikix update`.
- A lint check that requires it, as lint already requires `VIKIX_SWANK_PORT=9` and the `unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE` line.

### 6. CI runs more of the suite

- CI runs 45 of about 127 tests. An `office` job for the tests without a screen (office, tasks, handoff, house, tester, scheduler, release, queue, plan, door, socket, grok, codex); they need python3, git and flock.
- CI's list made from one file (say `tests/ci-list.txt`) and checked against `run.sh`'s, so the two can't drift.

### 7. Budgets about to bite

- `config/claude/skills/vikix/SKILL.md` is 15,998 of its 16,000 bytes (`tests/agents.sh`): trim it before anything is added.
- The key card has no rows left; see `DESIGN-dependable.md` item 13.

### 8. Housekeeping

- Stale branches on GitHub: `cursor/containers-feature-1cce` (1,380 lines, CI red) and `agent-orchestration` (a design document). Vid's to delete or keep.
- Multilib into `packages/repos.list`.
- `CLAUDE.md`'s load order drifted from `*vikix-files*` in `config/stumpwm/init.lisp`: make them agree.

## References

- The failing lint: `gh run view 39132865581 -R vukini/vikix --log-failed`; the runs: `gh run list -R vukini/vikix`.
- The handover's study (architecture, the Office, the subsystems) and cheat sheet were written at 0.72.95, outside this repository.
