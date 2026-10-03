# Your notes, on the laptop and the phones

Your notes are one folder of Org files, `~/Dropbox/notes`. On the laptop you take a note from anywhere with a key, sort the inbox into your files now and then, and read and tick off your TODOs in Emacs. Dropbox carries the folder to your phones, where an Org app reads it, adds to it and ticks things off too. No account but Dropbox, and the notes stay plain text you can open with anything.

It comes in two parts: the plugin `inbox` (the key and the sorting: `vikix plugin add inbox`) and Emacs's `C-c n` keys (Vikix's `vikix-notes.el`, which the Emacs config loads). The folder is made by your first note.

## Taking a note

**Super+Alt+i**, over whatever you're doing, opens a small box. Write the note; the first line is its title. Or press **Super+F9** and speak: dictation types into the box. **C-c C-c** keeps it, **C-c C-k** drops it.

**Super+Alt+Shift+i** does the same with what you had selected quoted in the note.

Each note lands at once at the end of `~/Dropbox/notes/inbox.org`, with when you wrote it and the window you were in (and, in Firefox or Nyxt, the page's address). From a terminal or a script: `inbox add "call the bank"`. In Emacs: **C-c n c**.

## Sorting the inbox

**Super+Alt+Shift+s** opens a terminal and asks the model Super+i uses (`vikix ai use`: one on this laptop, or Claude, and then your notes' text goes to Anthropic, as it says first) where each note belongs: which file in the folder, and which top heading in it. It also guesses which notes are things to do. You see the list before anything moves:

```
   1  Check the Q3 numbers  → work.org   to-do
   2  Call the bank         → personal.org   to-do
   3  helllo                → stays in the inbox
```

- **Enter** moves them.
- **A number** (`3`) changes where that note goes.
- **t and a number** (`t 2`) makes it a to-do, or not.
- **d and a number** (`d 3`) deletes it; `d 3` again keeps it.
- **q** stops, and nothing moves.

To-dos get `TODO` in front of their title. `inbox sort --undo` puts every file back as it was before the last sort, when nothing has changed them since.

The first sort makes four files to sort into: `work.org`, `personal.org`, `projects.org` (a heading for each project in `~/src`) and `someday.org`. Rename them, add your own or remove them: the sort offers whatever `.org` files are in the folder, and their top headings.

**To-dos into Todoist.** Give Vikix your Todoist token once: `vikix ai key set todoist` (in Todoist: Settings, Integrations, Developer). After that, each sort asks whether to send its to-dos to Todoist too, and each note keeps the task's link.

## In Emacs

Everything is under **C-c n**:

| Keys | What it does |
|---|---|
| `C-c n a` | The agenda: this week, then every TODO in your notes and their journal |
| `C-c n t` | Every TODO; `t` on one ticks it done |
| `C-c n c` | A note into the inbox |
| `C-c n o` | Open a notes file, the inbox first |
| `C-c n j` | Today's journal page, `journal/2026-10-03.org` |
| `C-c n f` | Find a note by its title, or start a new one |
| `C-c n i` | A link to another note, where you are |
| `C-c n l` | What links to this note |
| `C-c n g` | The graph of your notes and their links, in the browser |

The last five use org-roam (and the graph org-roam-ui), the add-ons for links between notes as Obsidian has them. Emacs asks before installing them from MELPA, the first time you use one. Their index of your notes is kept on the laptop (`~/.cache/vikix/org-roam.db`), never in Dropbox, and is made again from the files whenever needed; the graph is served to this laptop only.

A notes file open in Emacs takes the changes the phones make to it, by itself, as long as you haven't changed it in Emacs too. Notes open ready to edit, though emacs-void opens other files read-only (its `my/editable-directories` says which folders are exempt).

## On the phones

Each phone needs an Org app that syncs with Dropbox. Point it at the `notes` folder in your Dropbox; it reads and writes the same files Emacs does.

### Android: Orgzly Revived

Free and open source: from [F-Droid](https://f-droid.org/packages/com.orgzlyrevived/) or Google Play. (The original Orgzly is no longer updated; Revived is its continuation.)

1. Open it, then **Settings → Sync → Repositories**, and add a **Dropbox** one.
2. Sign in to Dropbox when it asks, and allow Orgzly.
3. For the directory, type **`/notes`**: the folder inside your Dropbox, without "Dropbox" itself.
4. Go back and press **Sync** (the round arrows). Each `.org` file becomes a notebook: Inbox, Work, Personal and the rest.

To have new notes go to the inbox, choose **inbox** as the notebook for new and shared notes in the settings. Sync runs when you press the button; recent versions can also sync by themselves when the app opens and after each change (**Settings → Sync**, auto-sync). If the journal's pages (`journal/`) don't show up, add `/notes/journal` as a second Dropbox repository.

The agenda is a search: `ad.7` lists the next seven days, `i.todo` every TODO. Orgzly can also remind you of a scheduled time or a deadline (**Settings → Reminders**).

### iPhone: beorg

From the App Store. Free, with extensions you can buy inside it (themes, more sync choices); syncing with Dropbox is in the free part.

1. Open it, then **Settings → Sync**, and choose **Dropbox**.
2. Set the folder to **`/notes`**.
3. Tap **Link Account**, and allow beorg in Dropbox.

beorg syncs the `.org` files in that folder. To see the journal's pages too, it needs subfolders switched on: open the file `init.org` in beorg (its own settings, kept in the same folder) and add the line `(set! sync-subfolders #t)`, then restart beorg. Its share sheet adds a link or text from any app to the inbox, and its agenda and task list read every file.

### What each can do

| | Laptop (Emacs) | Orgzly Revived | beorg |
|---|---|---|---|
| Read every note | yes | yes | yes |
| Take a note into the inbox | Super+Alt+i, C-c n c | yes (and from the share menu) | yes (and from the share sheet) |
| Tick a TODO done | yes | yes | yes |
| The agenda, the week ahead | yes | yes (as a search) | yes |
| Reminders at a scheduled time | no | yes | yes |
| The journal | C-c n j | with the second repository | with subfolders on |
| Sorting the inbox with a model | Super+Alt+Shift+s | no | no |
| Links between notes, backlinks, the graph | yes (org-roam) | links show as text | links show as text |

## What travels, and what doesn't

- **The whole folder travels,** while the Dropbox program runs on the laptop (`vikix add dropbox`). Dropbox only carries changes while it's running: a note taken with it stopped goes up when you start it.
- **The laptop's own:** org-roam's index (`~/.cache/vikix/org-roam.db`), the graph, the copies each sort keeps for `--undo` (`~/.local/state/vikix/inbox/sorts/`), and the inbox plugin's settings.
- **Two changes to the same file before either was synced** (the phone offline, say) can't both win. Dropbox keeps the other one beside it as `inbox (conflicted copy).org`: open both, copy across what's missing, then delete the copy. Orgzly asks whether to load the file again (**Force Load**) or keep the phone's version (**Force Save**); beorg warns you and keeps the version it replaced.
