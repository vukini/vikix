#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["anthropic==1.9.0"]
# ///
"""ask.py: one question to Claude, the answer printed as it's written.

    uv run ask.py "Why is the sky blue?"
    uv run ask.py "Summarise this" < notes.md

The key comes from ANTHROPIC_API_KEY (vikix ai key set anthropic).
CLAUDE_MODEL picks another model: claude-sonnet-5-5 is cheaper.
"""
import os
import sys

import anthropic

MODEL = os.environ.get("CLAUDE_MODEL", "claude-opus-5-5")
# These models can decline a request their safety checks flag. With
# fallbacks="default" the API then answers on the model Anthropic
# recommends for that kind of request, in the same call.
FALLBACK_MODELS = ("claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5")


def main():
    question = " ".join(sys.argv[1:]) or "In two sentences: what is an API?"
    if not sys.stdin.isatty():
        piped = sys.stdin.read()
        if piped.strip():
            question = f"{question}\n\n<text>\n{piped}\n</text>"
    if not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("No ANTHROPIC_API_KEY: run `vikix ai key set anthropic`, then open a new terminal.")

    client = anthropic.Anthropic()   # reads ANTHROPIC_API_KEY (and ANTHROPIC_BASE_URL, if set)
    extra = {}
    if MODEL in FALLBACK_MODELS:
        extra = {"betas": ["server-side-fallback-2026-07-01"], "fallbacks": "default"}
    try:
        # Streaming: the words appear as they're written, and a long
        # answer never runs into a timeout.
        with client.beta.messages.stream(
            model=MODEL,
            max_tokens=16000,
            messages=[{"role": "user", "content": question}],
            **extra,
        ) as stream:
            for text in stream.text_stream:
                print(text, end="", flush=True)
            reply = stream.get_final_message()
    except anthropic.AuthenticationError:
        sys.exit("The key was refused: set it again with `vikix ai key set anthropic`.")
    except anthropic.RateLimitError:
        sys.exit("Too many requests just now (or no credit left): wait a minute and try again.")
    except anthropic.APIStatusError as e:
        sys.exit(f"The API said {e.status_code}: {e.message}")
    except anthropic.APIConnectionError:
        sys.exit("Couldn't reach Anthropic's API: is the network up?")
    print()

    if reply.stop_reason == "refusal":
        print("(Claude declined to answer that.)", file=sys.stderr)
    usage = reply.usage
    print(f"({reply.model}: {usage.input_tokens} tokens in, {usage.output_tokens} out)", file=sys.stderr)


if __name__ == "__main__":
    main()
