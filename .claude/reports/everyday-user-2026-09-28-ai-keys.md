# Everyday user review: AI on the selected text (Super+i), 2026-09-28

Checked: the dev checkout at **0.45.0** (`bin/vikix-ask`). The installed `~/vikix` is 0.44.1 and doesn't have it yet, so none of this was tried on the live desktop's keys or menus.

How I tested: I ran `bin/vikix-ask ACTION` directly, with stand-ins for `xclip`, `notify-send` and `rofi` in a temp dir, `XDG_CONFIG_HOME` and `XDG_RUNTIME_DIR` pointing at temp dirs, and `VIKIX_TERMINAL=echo`. The real `llm` and **llama3.2:3b** answered 8 times: proofread ×3, rewrite, translate, explain ×2, ask. The failure paths were run without calling a model. The user's clipboard, the selection and `~/.config/vikix/ai` were not touched. One side effect: the 8 test prompts (made-up text) are now in the user's `llm logs`.

Times (the first run includes loading the model): proofread 7–19 s, rewrite 14 s, translate 12 s, ask 20 s, explain 24–30 s. These match the README's "about 10 s to proofread, 20 to explain".

None of the findings below is in `TODO.md`. `tests/ai-keys.sh` passes; it doesn't cover finding 1.

---

## 1. After a long answer, Super+i says "AI is still working" until you close the answer's terminal (high)

- **What I did:** held the lock the same way the script does just before it opens the terminal (`exec 9>lock; flock; exec TERMINAL …`), with a stand-in terminal that sleeps. Then I ran `vikix-ask proofread` on new text.
- **What happened:** the notification said **"AI is still working on the last one"** and nothing else happened. The lock file's descriptor (fd 9) stays open through `exec "$TERMINAL" -e less …`, so the terminal, and `less` inside it, hold the lock for as long as the window is open. I confirmed that bash keeps fd 9 open across `exec`.
- **Why it matters:** Explain opened a terminal both times I tried it (see finding 2), so after almost every Explain, Super+i refuses to work and gives a wrong reason. A user will think the AI is stuck, not that an open `less` window is the cause.
- **Expected:** once the answer is shown, Super+i works again.
- **Fix:** close the lock before handing over: `exec 9>&-` just before `exec "$TERMINAL" …`, or `exec "$TERMINAL" … 9>&-`. Add a check to `tests/ai-keys.sh`: a stand-in terminal that sleeps, then a second run that must not see "still working".

## 2. Explain almost never fits in a notification, and the small model makes up a "fix" (medium)

- **What I did:** explained an xbps "unresolvable shlib" error and the command `find . -name "*.log" -mtime +7 -delete`.
- **What happened:** both answers were 400 characters or more, over the 280 limit, so each time I got the notification "AI answered / In a terminal: q closes it" and a terminal opened. For the `find` command, which has nothing wrong with it, the model added: *"To fix a syntax error in this command, you can use a backslash to escape the exclamation mark in `-mtime +7`…"*. That is invented, and the prompt's "how to fix it if something is wrong" invites it. The answer also had a Markdown bullet list and backticks, even though the prompt asks for sentences without headings. For the xbps error the advice was generic ("update or reinstall libicuuc"). On Void the usual cause is a partial update: run a full `xbps-install -Su`.
- **Why it matters:** the docs promise that "a short answer comes as a notification", but with "at most five short sentences" Explain in practice always opens a window over your work. The invented fix is the kind of answer that sends a user off to "fix" a command that already works.
- **Fix:** ask for "at most three short sentences, plain text, no lists", and raise the notification limit to about 450 characters or 6 lines. Reword the fix part: "Only if it is an error message, say how to fix it; otherwise don't suggest changes." Optionally add "The user runs Void Linux" so package errors get Void advice.

## 3. An older highlight beats what you just copied (medium)

- **What happens (from the script's order, and how X works):** `selection()` reads PRIMARY first and falls back to CLIPBOARD only when PRIMARY is empty. On X, PRIMARY usually isn't empty: it keeps whatever you last highlighted, maybe minutes ago in a terminal, until something else is highlighted. The docs say *"If nothing is highlighted, it uses what you last copied"*, but the script can't tell "nothing highlighted now" from "highlighted something earlier".
- **Why it matters:** a user who copies with Ctrl+C (or a "Copy" button) and presses Super+i can get an answer about some other text. The Super+i menu shows the text's start, which gives a chance to notice. A direct key from the README's own example (`s-I` → `vikix-ask proofread`) shows nothing: it proofreads the wrong text and replaces the clipboard with it.
- **Fix:** at least, have the "AI is working…" notification show the first ~60 characters of the text being sent, so a wrong pick is visible at once. Also reword the docs: "the text you last highlighted (even if it's no longer highlighted); if there is none, what you last copied". A bigger fix is to prefer CLIPBOARD when it changed more recently than PRIMARY. xclip can't tell which is newer, so this is harder.

## 4. Switching between local and Claude means editing a file you're only told about in docs and error messages (medium)

- **What I did:** tried to find out, as a user, how to "use Claude for this".
- **What happened:** the only way is to edit `~/.config/vikix/ai`, which only exists after the first press. The Super+i menu names the model and where the text goes ("AI (llama3.2:3b, on this laptop)"), which is good, but it doesn't say how to change it. There's no `vikix ai …` command for it and no Super+m entry. `vikix ai` help lists setup, models, llm and key, but says nothing about Super+i or the `ai` file.
- **Also confusing:** the names differ. The feature is "AI on the selected text" in the key help, the menu and the README; "**AI keys** need llm" in the error; "Vikix **AI on keys**" in the file's header; and `vikix ai key` is the command for API keys. "AI keys need llm" reads like "you need API keys".
- **Fix:** add a last menu line "Model: llama3.2:3b (change…)" that opens the file in the editor, or add `vikix ai use local|claude [model]`. Use one name everywhere: "Super+i needs llm", and a header that starts "# Super+i (AI on the selected text)".

## 5. Proofread can make correct text worse, and you can't see what it changed (low–medium)

- **What I did:** proofread "Thanks for the update. I will review the document tomorrow morning."
- **What happened:** llama3.2:3b turned the full stop into a comma, which is a comma splice. The result was then copied with "Proofread: copied, paste with Ctrl+v". The "nothing to correct" message only appears when the text comes back exactly the same, so any small change the model makes looks like a correction.
- **Fix:** show the changes in the notification: the changed words in bold using `difflib` (dunst shows `<b>`), or at least "Proofread: 1 change, copied". Proofreading the email sentence and the list both went well (see "what felt good").

## 6. The trouble table doesn't list the messages you actually get (low)

`docs/ai.md`'s table covers "AI keys need llm", "No local model yet", "isn't running" and "Select some text first". It doesn't cover messages I saw or that the script can show: **"AI is still working on the last one"**, **"You don't have the model X"**, **"The model in ~/.config/vikix/ai looks wrong"**, **"Claude needs your Anthropic key"**, **"use= … should be local or claude"**, and **"AI didn't answer"** (with its 5-minute timeout). Those messages do explain themselves well (see below), so one row each is enough.

## 7. Small rough edges (low)

- **A typed language with an accent is silently dropped.** Typing `Português` (or `Français`, or `中文`) at "Translate into" exits with no notification, because of the `[A-Za-z -]` check. Either allow letters from any language, or tell the user: "Type the language name in English letters". Also, `languages=` is split on spaces, so "Brazilian Portuguese" becomes two entries.
- **A typo in the action is silent from a key.** `vikix-ask proofred` bound in `user.lisp` only prints the usage to stderr, which nobody sees. Send a notification as well.
- **Case matters in `use=`.** `use=Local` is refused. The message is clear, but accepting any case costs nothing.
- **Long clipboard results are cut in the notification without a mark.** For the 9-line email the notification ended at "Thanks," and dropped "Vid". The clipboard held the whole text. Add "…" when the body is cut.
- **Rewrite joined two paragraphs into one.** The rewrite prompt, unlike proofread's, doesn't ask to keep the paragraphs. Add "Keep the paragraphs and lists".
- **"Paste with Ctrl+v"** is wrong in a terminal (Ctrl+Shift+v). Consider "paste it where you want it".
- **"AI is working…"** doesn't say which action is running, and there's no way to cancel. Something like "Proofreading… (llama3.2:3b, on this laptop)" would be clearer.
- **Test safety note:** `env -u ANTHROPIC_API_KEY` alone does **not** keep a `use=claude` test offline. The script reloads keys from `${XDG_CONFIG_HOME}/vikix/secrets` via `lib/secrets.sh`. My test was safe only because `XDG_CONFIG_HOME` pointed at a temp dir. Anyone repeating this test should know that.

---

## What felt good

- **The model and where the text goes are always named**: in the menu title, in the "working" notification ("llama3.2:3b, on this laptop") and in the answer's header. Together with "never falls back to Claude by itself", this makes the privacy choice clear.
- **The clipboard gets clean text.** In 5 clipboard results: no "Here is…", no quotes, no code fences. Line breaks, the bullet list, `&` and `<version>` all came through unchanged. The notifications escape `&` and `<` correctly (they showed `R&amp;D` in the raw markup, and a notification shows that as `R&D`).
- **Local quality was good enough for everyday work**: the error-filled email sentence was fully fixed, the Spanish shipping notice was translated well, and the Ask answer ("deadline Friday 3 October, send to finance@…") was right and short, in a notification.
- **Error messages say what to do next**: "You don't have the model mistral:7b / vikix ai models gets it, or change model= in ~/.config/vikix/ai", and "Claude needs your Anthropic key / In a terminal: vikix ai key set anthropic. Or use=local…". Comments after a value in the `ai` file (`use= local  # try claude later`) are handled.
- **The "working" notification is replaced in place** by the result, so there is no pile-up, and it stays up for the whole wait.
- **Easy to find**: the README's key table, Super+F1 help, the Super+m menu entry, the vikix.dev key list and the docs/ai.md overview table all mention it, with the same one-line description.
