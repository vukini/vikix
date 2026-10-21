# Your own model in the cloud

For when the model you want doesn't fit the laptop. [Working with AI](ai.md) says what runs here: on a laptop's CPU a 3B model answers in ten seconds, an 8B slowly, and `gpt-oss:120b` wants a machine with 128 GB. The rest of the models, and the speed, are in the cloud, four ways. All four end at the same setting, `vikix ai use cloud` with `cloud_url=` pointing at the address ([A cloud service](ai.md#a-cloud-service-openrouter-and-the-like)), so Super+i, the voice key, the editors' chats and `note` follow without knowing the difference.

The prices here were read on 2026-10-21 from the providers' pages and the comparisons of that month; they move every few months, so take them as the order of things, and read the live page before you pay. Nothing on this page is a package: it is an account, a card, and two lines in `~/.config/vikix/ai`.

## The four ways, in one look

| | What it is | You pay for | The text goes to | Good for |
|---|---|---|---|---|
| **Someone else's copy** (OpenRouter and the services behind it) | A model a host already runs; hundreds to choose from | Each word in and out, about 1 cent for 50 Super+i questions on a mid-size model | OpenRouter, then the host it picks (you can restrict which) | Nearly everyone: no machine to mind, nothing to wake |
| **A GPU by the hour** (RunPod, Vast.ai, Lambda) | A card that is yours while it runs, with a model you load | Every hour it is on, asked or not, $0.3–4 by the card | One machine you chose, and whoever runs it | A long session; a model nobody serves; text you won't send to a service |
| **Serverless** (RunPod Serverless, Modal) | The same, but the card is found when a question comes and dropped when quiet | Each second it works, $1–5 an hour's worth, and a minute or two to wake after a quiet spell | The provider's machines | Now and then, for hours apart: the meter stops by itself |
| **A box of yours** (a node, [Your other machines](nodes.md)) | A machine with a card, at home or rented bare, reached over SSH | Nothing more than the machine | Nowhere else | The most private; the one that needs you to look after it |

Rule of thumb: **under an hour a day, OpenRouter; a working day on one model, a card by the hour; private text, your own box.** Serverless is the hour-by-the-hour card for someone who forgets to turn it off.

## Someone else's copy: OpenRouter

One key, one address, every model with a public weight and the closed ones too, priced per million tokens (a token is about three-quarters of a word). The prices on OpenRouter's model pages, 2026-10-21, cheapest host:

| Model | In, per million tokens | Out, per million tokens | A Super+i question (500 in, 200 out) |
|---|---|---|---|
| `openai/gpt-oss-120b` | $0.03–0.10 | $0.10–0.50 | a hundredth of a cent |
| `meta-llama/llama-3.3-70b-instruct` | $0.10 | $0.32 | a hundredth of a cent |
| `qwen/qwen3-32b` | $0.08 | $0.28 | the same |
| `anthropic/claude-sonnet-4.5` | $3 | $15 | half a cent |

The first three are the open models the laptop would run if it could; the last is there to show the gap. A day of asking is cents; it is the agents, with their long contexts, that cost dollars. `openrouter.ai/models` lists every model with its price and the hosts behind it; `openrouter.ai/activity` is the meter.

**Where the text goes.** To OpenRouter, which keeps the request's size and timing but not the words unless you turn logging on, and then to the host it picks for the model (DeepInfra, Groq, Together, Cerebras ...), each with a policy of its own. Two settings on `openrouter.ai/settings/privacy` matter: *Zero Data Retention* routes only to hosts that keep nothing, and *data collection: deny* only to hosts that don't train on what they see. Both cut the list of hosts, sometimes to none for a model, and then the request fails rather than go elsewhere. A model whose name ends in `:free` is paid for by the host's right to train on your text: fine for a test, not for your notes.

**Set up.** `vikix ai key set openrouter`, then `vikix ai use cloud`; `cloud_model=` in `~/.config/vikix/ai` picks the model by OpenRouter's name:

```sh
use=cloud
cloud_model=openai/gpt-oss-120b     # empty: openai/gpt-4o-mini
```

Groq, Mistral, DeepSeek and the rest sell the same way at their own addresses, with one model family each: `cloud_url=https://api.groq.com/openai/v1`, `cloud_key=groq`, `vikix ai key set groq`.

## A GPU by the hour

A card in a data centre, with a Linux image on it, that you start, load a model on, and stop. Prices an hour, on demand, 2026-10-21 (RunPod's two tiers, Vast.ai's median listing, Lambda's rate card, and Modal's per-second rate as an hour, for the next section):

| Card | Memory | RunPod Secure | RunPod Community | Vast.ai (median) | Lambda | Modal |
|---|---|---|---|---|---|---|
| RTX 4090 | 24 GB | $0.69 | $0.34 | $0.37 | — | — |
| L40S | 48 GB | $0.79 | $0.53 | $0.60 | — | $1.95 |
| A100 | 80 GB | $1.59 | $1.39 | $1.00 | $2.06 | $2.50 |
| H100 | 80 GB | $2.89–3.49 | $1.99 | $2.13 | $2.99–3.99 | $3.95 |

*Secure* and *Lambda* are the provider's own data centres; *Community* and Vast.ai are other people's machines offered through the provider, cheaper and sometimes gone under you. For text you'd not post publicly, take the provider's own. A pod bills from start to stop, idle or not, and a stopped pod's disk goes on billing at a few cents a day until deleted: `runpodctl stop pod ID` is the off switch, and the console's billing page says what is still running.

**Which model on which card.** The weights' size is the `GB` column of `lib/ai-models.tsv` (the Ollama download, a 4-bit quantisation for most); the context costs more memory on top, and an agent such as Hermes or OpenCode wants 64k tokens of it. What 64k adds, at 16-bit cache, roughly: 2 GB for the gpt-oss models (half their layers look back 128 tokens only), 7 GB for `qwen3:30b`, 10 GB for `gemma3:27b`, 20 GB for Llama 3.3 70B. So:

| Model | Weights | With 64k context | The card |
|---|---|---|---|
| `gpt-oss:20b` | 14 GB | 16 GB | RTX 4090, 24 GB |
| `qwen3:30b`, `qwen3-coder:30b` | 19 GB | 26 GB | L40S, 48 GB (a 4090 with 16k context) |
| `gemma3:27b` | 17 GB | 27 GB | L40S, 48 GB |
| Llama 3.3 70B, 4-bit | 40 GB | 60 GB | A100 or H100, 80 GB |
| `gpt-oss:120b` | 65 GB | 67 GB | H100 80 GB (an A100 80 GB works, slower) |

Serving with vLLM at 16 bits instead of 4 doubles the weights; `--kv-cache-dtype fp8` halves the context's share. The server's first lines say how many tokens of cache fit after the weights: start with `--max-model-len 65536` and read them.

**The simplest server: vLLM with a key.** RunPod's *Deploy* page has a vLLM template; the same by hand is the official image, with a secret so the address isn't open to the world:

```sh
# the pod's start command, on vllm/vllm-openai:latest, HTTP port 8000 exposed
python3 -m vllm.entrypoints.openai.api_server \
  --model openai/gpt-oss-120b --max-model-len 65536 \
  --api-key "$VLLM_KEY" --host 0.0.0.0 --port 8000
```

RunPod then gives the pod an address of the form `https://POD_ID-8000.proxy.runpod.net`, with the certificate RunPod's; anything else that serves OpenAI's API does as well (Ollama with `OLLAMA_HOST=0.0.0.0`, llama.cpp's `llama-server --api-key`), as long as the address is `https`: Vikix refuses a plain `http` address off the machine itself, since the text would cross the Internet readable.

**Pointing Vikix at it.** A name in capitals is a variable of your own, for a key that belongs to no service:

```sh
vikix ai key set MY_POD_API_KEY      # paste the pod's secret
```

```sh
use=cloud
cloud_url=https://POD_ID-8000.proxy.runpod.net/v1
cloud_key=MY_POD_API_KEY
cloud_model=openai/gpt-oss-120b     # the name the server was started with
```

`vikix ai use cloud` says where the text goes; Super+i's notification names the host. When the pod is stopped, Super+i fails with llm's error in the notification: back to `vikix ai use local` until the next session.

## Serverless: the card comes when asked

The same card, but the provider starts it on the first request and drops it after some minutes of quiet; you pay the seconds in between, including the minute or two it takes to load the model, and nothing while it sleeps. Dearer an hour than a pod (RunPod's flex workers: an A100 about $2.70, an H100 about $4.80; Modal's rates are in the table above), cheaper a month for anyone who asks in bursts.

**RunPod Serverless.** *Serverless* → *New endpoint* → the vLLM worker, the model's Hugging Face name, the card; the endpoint gets a RunPod address, and RunPod's own API key opens it:

```sh
vikix ai key set runpod              # the key from the console's Settings
```

```sh
use=cloud
cloud_url=https://api.runpod.ai/v2/ENDPOINT_ID/openai/v1
cloud_key=runpod
cloud_model=openai/gpt-oss-120b
```

Set the endpoint's idle timeout (five minutes for a chat, longer if you'd rather pay than wait) and leave *active workers* at zero: an active worker is a pod by another name.

**Modal.** A Python file describes the server, `modal deploy` puts it up, and the file's `scaledown_window` says how long it waits before sleeping. Modal's own example serves gpt-oss with vLLM on one H100 ([modal.com/docs/examples/gpt_oss_inference](https://modal.com/docs/examples/gpt_oss_inference)); it prints an address of the form `https://WORKSPACE--APP-serve.modal.run`, and the example's `API_KEY` is the secret the address wants, kept as `vikix ai key set MY_MODAL_API_KEY`, `cloud_key=MY_MODAL_API_KEY`, `cloud_url=https://WORKSPACE--APP-serve.modal.run/v1`.

**The wait.** The first question after a quiet spell takes a minute or two (the card is found, the image pulled, the weights read in); Super+i's notification stays at *AI is working…* meanwhile, and gives up after five minutes. Everything after is as fast as the card.

## A box of yours

A machine with a card, at home, in the office, or rented bare for a month (Hetzner, OVH and the like rent a GPU server from about €200 a month, which is an H100 pod for three hours a day). Set it up as a node ([Your other machines, as nodes](nodes.md)): `vikix node add gpu me@gpu.example.com`, Ollama or vLLM on it as on the laptop, and then a tunnel, since the box's port should listen to the machine itself and nothing else:

```sh
ssh -N -L 11434:127.0.0.1:11434 gpu &    # the box's Ollama, as if here
```

```sh
use=cloud
cloud_url=http://127.0.0.1:11434/v1      # http is allowed on this machine only
cloud_key=MY_BOX_API_KEY                 # Ollama ignores it: vikix ai key set MY_BOX_API_KEY, any word
cloud_model=gpt-oss:120b                 # Ollama's names
```

Nothing leaves but the SSH connection, and the box's logs are yours. Over Tailscale the tunnel line goes too, but Vikix takes `http` only on the laptop itself, so the box then needs an `https` front (Caddy with Tailscale's certificates) before `cloud_url=` can name its Tailscale address; the SSH tunnel is the simpler of the two.

## What to pick

- **You ask a few things a day, and the model exists somewhere.** OpenRouter, with *Zero Data Retention* on if the text is yours. Cents.
- **You want a particular open model at 64k context for an agent, for a day's work.** A pod: `gpt-oss:120b` on an H100 at $2–3 an hour, `gpt-oss:20b` on a 4090 at under a dollar. Stop it at the end.
- **The same, but on and off through the week.** RunPod Serverless or Modal, idle timeout at five minutes, and patience for the first question each time.
- **The text must not leave machines you control.** Your own box, over SSH.
- **A model nobody serves, or your own fine-tune.** A pod or serverless, with the weights on the pod's volume so they aren't downloaded each start.

Whatever the way, `vikix ai log` keeps the questions and answers, and `vikix ai use local` is always one command back.

Sources (read 2026-10-21): RunPod's pricing and serverless docs ([runpod.io/pricing](https://www.runpod.io/pricing), [docs.runpod.io/serverless/pricing](https://docs.runpod.io/serverless/pricing)); Modal's ([modal.com/pricing](https://modal.com/pricing)); Vast.ai's listings and Lambda's rate card as [cloudmart.dev](https://cloudmart.dev/blog/h100-rental-prices-2026) and [tech-insider.org](https://tech-insider.org/runpod-vs-lambda-vs-vast-ai-2026/) read them that month; OpenRouter's model pages, its [Zero Data Retention](https://openrouter.ai/docs/guides/features/zdr) and [provider routing](https://openrouter.ai/docs/guides/routing/provider-selection) guides; OpenAI's [vLLM guide for gpt-oss](https://developers.openai.com/cookbook/articles/gpt-oss/run-vllm) and the [vLLM recipe](https://docs.vllm.ai/projects/recipes/en/stable/OpenAI/GPT-OSS.html) for the memory figures.
