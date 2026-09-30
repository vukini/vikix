# local

A question to a model on this laptop, through Ollama's API: nothing
leaves the machine, and nothing is paid. `chat.py` needs no library at
all, only Python's own `urllib`.

    vikix add local-ai          # once: Ollama
    vikix ai models             # once: a model that fits this laptop
    make run
    make run QUESTION="Name three rivers in France."
    make run-sh

A 3B model answers simple questions well and quickly; it makes things up
more often than Claude, so check what matters. `ollama list` shows the
models here, and `OLLAMA_MODEL=NAME make run` picks one.

Compare with `../claude`: the request is almost the same shape, a list
of messages with a role and content each, which is why tools like `llm`
can speak to both.

Try: send `"options": {"temperature": 0}` with the request and ask the
same thing twice; then 1.5. Docs: https://github.com/ollama/ollama/blob/main/docs/api.md
