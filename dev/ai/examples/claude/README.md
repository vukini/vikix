# claude

One question to Claude, and its answer: from Python with Anthropic's
library (`ask.py`), and from the shell with curl and jq (`ask.sh`).

    vikix ai key set anthropic     # once; then open a new terminal
    make run
    make run QUESTION="What is a monad, in plain words?"
    make run-sh
    uv run ask.py "Summarise this" < ~/dev/python/README.md

Each question costs a little: both print the tokens it used (Opus 5.5
is $4 a million in, $20 a million out). `CLAUDE_MODEL=claude-sonnet-5-5`
is half that.

Read `ask.sh` first: the whole API is one POST with a JSON body. Then
`ask.py`, which streams the answer as it's written.

Try: keep a list of messages and loop on `input()`, appending the user's
turn and Claude's reply each time, and you have a chat. Add
`system="Answer in Esperanto."` to the request to change how it replies.
Docs: https://docs.claude.com/en/api/messages
