# AI

Programs that talk to a language model: Claude over the internet, or a
model running on this laptop with Ollama. The same few ideas go a long
way: send text and get text back, turn text into numbers (embeddings)
to find what's alike, and put the two together to answer questions
from your own notes.

## On this machine

<!-- tools -->

- Each example names the libraries it needs at its top (`# /// script`), and `uv run` fetches them the first time: no environment to make, nothing installed for the whole machine
- Claude needs a key: `vikix ai key set anthropic` (from https://console.anthropic.com), then a new terminal. It costs a little per question; `ask.py` prints the tokens each one used
- Local models need `vikix add local-ai`, then `vikix ai models` to pick one. Nothing leaves the laptop
- Examples: `~/dev/ai/examples/` (`make run` in each)

## Where to start

1. `examples/claude`: one question to Claude, from Python and from the shell. Read `ask.sh` first: it's a single HTTP request.
2. `examples/local`: the same question to a model on this laptop, through Ollama's API.
3. `examples/embeddings`: sentences turned into numbers, kept in SQLite, and the nearest found for a question.
4. `examples/ask-notes`: 2 and 3 together. It searches a folder of Markdown (your Obsidian vault, say) and answers from what it finds, locally unless you add `--claude`.

## Online

- Claude's API: https://docs.claude.com/en/api/overview
- The Python library: https://github.com/anthropics/anthropic-sdk-python
- Ollama's API: https://github.com/ollama/ollama/blob/main/docs/api.md
- sqlite-vec: https://alexgarcia.xyz/sqlite-vec/
- uv's scripts, with their libraries at the top: https://docs.astral.sh/uv/guides/scripts/
- llm: https://llm.datasette.io/

## Free books and courses

- Anthropic's courses (prompting, the API, tool use): https://github.com/anthropics/courses
- Hugging Face's LLM course: https://huggingface.co/learn/llm-course
