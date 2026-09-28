# Everyday user: web apps (`vikix webapp`), 2026-09-28

Checked: the dev checkout at **0.42.0** (`bin/vikix-webapp`). The installed `~/vikix` is **0.41.2**, so on this machine `vikix webapp list` still says `xx unknown command: webapp`. That's expected until `vikix update`, but worth knowing: the README describes a command that the installed `vikix` doesn't have yet.

How I tested: I read the README's "Web apps" section and its `s-M` row, docs/customize.md "Web apps", `vikix-webapp help`, and the SKILL.md line. Then I ran every command in a throwaway `HOME` with `VIKIX_SWANK_PORT=9` and a stand-in `chromium` that only logged its arguments. On the real machine I only ran `bin/vikix-webapp list`/`help`, plus read-only `vikix eval` lookups (a key binding, the menu labels, and one parse of a key string). The real list is unchanged (superhuman `s-M`, fastmail with no key). No windows or profiles were touched; for one finding I measured profile sizes with `du`. The throwaway home is deleted. Nothing about web apps is in `TODO.md` yet.

---

## 1. Re-running `add` quietly drops the key, and `s-M` can move to another app

- **What happened:** `vikix webapp add superhuman` gave it `s-M`. Running the same command again said `:: changed the web app Superhuman` and the key was gone (`list`: `no key`). A custom key goes the same way: `add notion https://notion.so --key s-y`, then `remove notion`, then `add notion https://notion.so` gives no key. Worse, the next mail app added (`add outlook-live`) quietly took `s-M`. The "changed" line doesn't say that a key went. The re-added entry also moves to the bottom of the list.
- **Expected:** re-running a setup command to be harmless (Vikix says its stages are safe to re-run, so users learn to expect that). Changing only the URL should keep the key.
- **How to see it:** `add superhuman`, `add superhuman`, `list`.
- **Cost:** high and silent. Re-running the README line "to be sure" or to fix a URL is a very natural thing to do, and Super+Shift+m stops working with no message. This machine's user already has superhuman on `s-M`.
- **Suggestion:** when the entry exists and `--key` isn't given, keep its current key. The cause is the `s-M` check, which counts the app's own `s-M` as "taken". If a key really does change, say so ("s-M: now nobody's").

## 2. `--key s-1` (and `s-C-1` … `s-C-9`) is accepted and takes over a workspace key

- **What happened:** `add a13 https://a.example --key s-1` gave `:: made the web app A13 … on s-1`. On the live desktop `s-1` is `gselect 1`. The check for "Vikix's own keys" reads only the literal `("s-…"` lines in keys.lisp, and the workspace keys are bound in a loop there. From reading webapps.lisp: the web app's key replaces the workspace key, and `remove` then *unbinds* `s-1` completely, so "go to workspace 1" stays dead until a reload.
- **Expected:** the same refusal as `s-d` gets ("one of Vikix's own keys").
- **Cost:** medium. Digits look like the obvious free keys ("mail on Super+1"), and losing a workspace key is confusing.
- **Suggestion:** check against the live bindings (or list `s-[1-9]` and `s-C-[1-9]` too). A test that adds `--key s-1` and expects a refusal would stop it coming back.

## 3. Nothing checks a hand-edited list, and one bad key can drop every web app's key and menu entry

- **What happened:** the docs say "editing it by hand is fine". I added lines by hand: `cal … s-d` (the launcher key), `odd … Super+Shift+o`, `Wiki` (a capital letter), `bad http://insecure.example`, the name `dup` twice, and `nourl` with no URL. `list` printed all of them as if they were fine, including `nourl` with an empty URL and `Super+Shift+o` as a key. `open cal` and `open Wiki` started Chromium. `open nourl` said "there's no web app called nourl", although `list` had just shown it.
- In the live StumpWM, `(kbd "Super+Shift+o")` raises a type error (I parsed it only; nothing was bound). From reading `vikix-load-webapps`: it unbinds the old keys and removes the menu entries *before* it reads the list, so an error partway leaves some keys unbound and no "Web app:" entries in Super+m at all. `vikix webapp add` hides that error (`>/dev/null`) and prints "StumpWM takes it at its next reload", which isn't what happened. A hand-written `s-d` would replace the launcher key without any warning.
- **Also:** your own comments in the file are dropped the next time `add` or `remove` rewrites it. My `# my work stuff below` line vanished.
- **Cost:** medium. Only people who edit by hand hit it, but the docs invite that. It shows up as "my mail key stopped working" with no message anywhere.
- **Suggestion:** make `list` flag bad lines ("line 7: Super+Shift+o isn't a key, try s-O"). In Lisp, skip a line whose key doesn't parse or is a Vikix key (catch it per line) instead of stopping. When the eval reload fails, say that it failed. Keep comment lines when rewriting, or change the header to "comments you add here are not kept".

## 4. The backup claim fails on existing machines: 2.3 GB of Chromium cache goes into the backup

- **What happened:** the README says "Backups keep the logins and leave out the caches." The shipped `config/backup/exclude` does have the web app cache lines. But `~/.config/vikix/backup-exclude` is copied once (`[ -f "$exclude" ] || cp …`), and no migration adds the new lines. This machine's copy (43 lines) has none of them. Here the Superhuman profile is **2.5 GB, of which 2.3 GB is exactly the cache folders** the new lines would leave out. Fastmail's is 140 MB.
- **Expected:** existing machines to get the new excludes too, or at least the README to say "add these lines".
- **How to see it:** `grep -c webapps ~/.config/vikix/backup-exclude` gives 0. `du -sh ~/.local/share/vikix/webapps/superhuman/Default/Cache` shows the cache size.
- **Cost:** high for anyone with backups set up: gigabytes of changing cache in every snapshot, and slower backups. (I found no backup log on this machine, so it may not bite this user yet.)
- **Suggestion:** a migration that appends the block (from its comment line on) when it's missing. The file stays the user's; this only adds lines. Or have `vikix backup` always add the shipped web app lines as a second `--exclude-file`.

## 5. There's no command to move `s-M` to another app or drop a key

- **What happened:** with superhuman on `s-M` and fastmail with none:
  - `add fastmail --key s-M` gave `xx s-M is already the key of your web app superhuman`, and stopped there with no next step.
  - `add superhuman --key ""` gave `…/bin/vikix-webapp: line 110: 2: --key needs a key, like s-M`. That's a raw bash error, with the script path and line number.
  - `--key none` gave the "a web app's key is Super and a letter…" message.
  - `--key=s-y` gave "unknown option".
  - The only way to drop a key through a command is bug 1 (re-add without `--key`).
- **Docs:** README and help say who *gets* `s-M`, but not how to move it or remove it. customize.md only says the list can be edited by hand.
- **Cost:** medium. "Two mail apps, which one is on the key?" is exactly this machine's setup. A user who switches from Superhuman to Fastmail will want to move `s-M`.
- **Suggestion:** support `--key none` (or `--no-key`). In the "already the key of" error, add the fix: "to move it: vikix webapp add superhuman --key none, then again". Replace `${2:?}` with `die`. Accept `--key=X`.

## 6. After a plain `remove`, the kept logins can't be seen or deleted by any command

- **What happened:** the message is good: `:: removed notion. Its logins are kept in …/webapps/notion, for if it comes back (--forget deletes them)`. But after that, `list` doesn't show kept profiles, and `remove notion --forget` answers `xx there's no web app called notion`. The only ways to get rid of the logins are to re-add and remove again with `--forget`, or `rm -rf` the folder yourself. `--forget` itself deletes without asking, which is fine because you typed it.
- **Expected:** what most people expect "remove" to do: "the app is gone". A privacy-minded person then expects a way to clear what's left. The README hides `--forget` in a code comment (`# remove NAME takes one away; --forget also deletes its logins`).
- **Cost:** low to medium. Kept profiles can be gigabytes (see 4), and it's a privacy question on a shared or handed-on laptop.
- **Suggestion:** let `remove NAME --forget` delete an orphaned profile even when the name isn't listed. Have `list` add "kept logins, not in use: notion (vikix webapp remove notion --forget)". Give `remove` its own line in the README instead of a code comment.

## 7. Notifications only arrive while the window is open, and the docs don't say so

- **Docs:** "Notifications come through dunst … allow them in the web app when it asks." Nothing says that a closed web app gets no mail notifications, or that web apps don't start at login. Superhuman and Fastmail ask for permission in their own settings, not always by themselves.
- **Cost:** medium. "Why didn't I get notified?" is the first mail question anyone will have.
- **Suggestion:** one sentence: "Notifications come only while the web app is open (on any workspace); keep it open, or start it at login from user.lisp." If starting at login is meant to be supported, name how to do it.

## 8. The messages talk to someone who already knows StumpWM's key names

- `:: made the web app Superhuman: …, on s-M`: a non-technical user doesn't know what `s-M` is. Help and README spell it out ("Super+Shift+m"), but the success line, `list`, and the "already the key" error don't.
- For an app with no key, the success line still says "Open it with its key, from the launcher…".
- A second mail app (`add fastmail` while superhuman has `s-M`) gets no hint about why it has no key or how to give it one.
- The key rules are found only by trial: `s-J`, `s-k`, `s-f`, `s-x`, `s-c` are refused one by one, and `s-Return` or `s-Print` give the general format error. The refusal says "Super+F1 lists them", which works, but suggesting a free key would save the next three tries.
- The live key help labels `s-M` "Superhuman (web app)", while the README's Keys table calls it "Mail". That's fine, but the README row could say "(labelled by the app's name in Super+F1)".
- **Suggestion:** write keys as `s-M (Super+Shift+m)` everywhere output shows them. Leave out "with its key" when there's none. When a mail app doesn't get `s-M`, say "s-M is superhuman's; for a key of its own: vikix webapp add fastmail --key s-F". List the free letters in the refusal.

## 9. Names and preset lists don't match from place to place

- The preset list in error messages comes out in bash hash order: `presets: outlook superhuman outlook-live fastmail gmail`. The docs and help order them superhuman, fastmail, gmail, outlook, outlook-live.
- `vikix help` (dev checkout) lists the presets as `superhuman, fastmail, gmail, outlook` and leaves out outlook-live.
- `outlook-live` is called "Outlook.com" in the launcher and in `add`'s message. From reading webapps.lisp, Super+m and the key help would call it "Outlook-Live" (`string-capitalize`). Custom names are capitalised oddly ("Crm", "A13").
- The README says `outlook (work)`, and help says "work or school Microsoft 365". People with a personal Hotmail account will guess `outlook` first. The help explains it, so this is only a small guess.
- **Suggestion:** use one ordered array for the presets. Put outlook-live in `vikix help`. Have the Lisp read the title from the .desktop file, or write a title column into the list.

## 10. Small messages

- `add crm crm.example.com` (or `www.hey.com`) gives "the address must start with https://". A friendlier message would offer the fix: "did you mean https://crm.example.com?" `http://crm.example.com` gets the same message, with no reason given. Adding "(a login over http can be read on the way)" would stop people thinking it's a bug.
- `add 2do …` gives "small letters, digits and -", but the name must also *start* with a letter, which the message doesn't say.
- `vikix webapp rm crm` and `ad` give "unknown command". `rm` is a very common guess for `remove`, and a one-line alias would cover it.
- `vikix webap` (installed and dev) gives `unknown command: webap (try: vikix help)`, with no "did you mean webapp". Minor.
- `list` has no header row, and the "no key" column is fine. `open` of a web app that isn't running gave no output, which is right.

---

## What felt good

- **Presets without URLs.** `vikix webapp add superhuman` just works, and the first mail app landing on Super+Shift+m is a good default.
- **The success message** says where it went: launcher name, Super+m, and "log in the first time, it keeps its own login".
- **Refusals of Vikix's own letter keys** (`s-d`, `s-m`, `s-F1`, `s-J`) and of another web app's key are clear and say whose key it is.
- **https only** is refused up front, and localhost is allowed for development.
- **Safe removal by default.** Plain `remove` keeps the logins and says where they are and how to delete them. It also deletes the launcher entry.
- **Profiles are private:** created 700, one per app. The launcher files have a sensible `StartupWMClass` and a mail icon for the mail presets.
- **The file format** (`NAME URL [KEY]`) is readable, has a header explaining itself, and is in the snapshot history (`yours.list`).
- **Typo'd preset:** `add superhumn` says exactly what to do next (`give its address: vikix webapp add superhumn https://...`).
- **The live reload through Swank** means that on the real desktop nothing waits for Reload config.
