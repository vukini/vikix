# Colibrì for SSD-streamed local models — spike

Looked into on 2026-10-21, for item 8 of "To look into" in TODO.md. Colibrì
(https://github.com/JustVugg/colibri, Apache-2.0) keeps the dense part of a
mixture-of-experts model in RAM and reads the routed experts from the disk
when the router asks for them, so a 744B model runs on a 16 GB laptop, slowly.
The question was whether that path belongs in `vikix ai` beside Ollama and
llama.cpp. **Recommendation: no-go for now**; the measurements and the
triggers to look again are below.

## The machine measured

| | |
|---|---|
| Machine | ROG Flow Z13 (`rog`), Void Linux, kernel 6.18.57 |
| CPU | AMD Ryzen AI Max+ 395, 16 cores / 32 threads, Zen 5, avx512-vnni |
| Memory | 121 GB LPDDR5x, shared with the graphics chip; 110 GB given to it by `vikix ai` |
| Graphics | Radeon 8060S (Strix Halo), RADV, Vulkan 1.4 |
| Disk | WD PC SN5000S 1 TB NVMe, 301 GB free |
| Toolchain | gcc 14.2.1, libgomp, clang 21, Vulkan-Headers 1.4, glslang, shaderc (`glslc`), Python 3.14.7 — every Colibrì build input is already a Void package |
| Baseline backend | Ollama 0.34.4 in `~/.local/opt/ollama`, Vulkan |

The disk, measured as Colibrì's protocol asks (`docs/benchmarking.md`): on a
63 GB model file, `dd bs=1M iflag=direct` read 3.7 GB/s sequentially, and
forty random 19 MiB reads (the size of one GLM-5.2 expert slab) with
`O_DIRECT` at queue depth 1 took 4.1 ms each, 4.8 GB/s. Colibrì's own table
lists machines from 1.5 to 11.5 GB/s; this drive is in the lower middle.

The network: 3.6 MB/s from Hugging Face on one connection, 4.7 MB/s on eight,
2.0 MB/s from a Void mirror. About 13 to 17 GB an hour, so the smallest
Colibrì model (19.4 GB) is 70 to 90 minutes and GLM-5.2 (429 GB) more than a
day, and it would not fit the 301 GB free anyway.

## Baseline: Ollama on the same class of model

Qwen3-30B-A3B (`qwen3:30b`, Q4_K_M, 18 GB on disk) is the same architecture
as Colibrì's smallest chat model, Qwen3-Coder-30B-A3B: 48 layers, 128 experts,
8 active, 3B active parameters. A 41-token prompt, `/no_think`, answers of
470 to 680 tokens, two runs each, load low (0.5):

| Ollama, Qwen3-30B-A3B | decode | prompt | load |
|---|---|---|---|
| graphics chip (default) | 78.3 and 76.9 tok/s | 146 tok/s | 8.4 s cold |
| CPU only (`num_gpu 0`) | 42.2 and 42.4 tok/s | 152 tok/s | 15.2 s cold |

Reproduce:

```sh
ollama run qwen3:30b --verbose "Explain in about 150 words why a mixture-of-experts language model can be large on disk yet cheap per token. /no_think"
curl -s localhost:11434/api/generate -d '{"model":"qwen3:30b","prompt":"...the same prompt...","stream":false,"options":{"num_gpu":0}}'
```

## Colibrì's own numbers on this chip and on this model class

Colibrì runs the small models from RAM and the large ones from the disk. Its
published measurements (README and `docs/benchmarks.md`, commit of
2026-10-17):

| Model | Machine | Colibrì | Here with Ollama |
|---|---|---|---|
| Qwen3-Coder-30B-A3B int4, every expert in RAM (15.2 GB) | Ryzen 7 PRO 8700GE, 8 cores, DDR5 | 8.5 to 9.6 tok/s; 13 tok/s warm in chat | 42 tok/s CPU, 78 tok/s graphics |
| the same with 32 experts per layer cached (6.5 GB) | same | 5.1 tok/s | |
| Qwen3.6-35B-A3B, Vulkan expert tier and dense chain on the integrated Radeon 780M | same | 6.0 → 9.9 tok/s | |
| GLM-5.2, 744B, int4, 429 GB, experts from the disk | **Ryzen AI Max+ 395, 128 GB** (the same chip as this Z13), PCIe 4.0 NVMe | 0.06 tok/s cold → 1.10 sustained → 1.83 warm with `DIRECT=1 PIPE=1` | nothing comparable; gpt-oss-120b runs at 51 words/s here through llama.cpp (TODO 61) |
| GLM-5.2 | Ryzen AI Max+ 395, Framework Desktop, Optane | 0.16 → 0.40 tok/s after five runs of learning | |
| GLM-5.2, every expert in RAM | EPYC, 430 GB RAM | 1.0 tok/s (RAM-bandwidth bound) | |
| GLM-5.2, every expert on the cards | 6× RTX 5090 | 9.0 to 9.2 tok/s | |

Even granting this 16-core Zen 5 twice the 8700GE's speed, Colibrì would
decode the 30B model at 20 to 25 tok/s on the CPU, against Ollama's 42 on the
CPU and 78 on the graphics chip. On the huge models the engine is built for,
the maker's own best on this exact chip is 1.8 tok/s, warm, after the cache
has learned the work.

## How it works (read from the code, not run)

- **Resident versus streamed.** Attention, shared experts, embeddings and the
  output head stay in RAM (3.6 GB for Qwen3-Coder, about 10 GB for GLM-5.2).
  The routed experts live in an int4 container of per-expert slabs (about
  19 MB each for GLM-5.2) and are read when routed. `coli plan --model DIR`
  prints the split before anything loads.
- **The GLM engine** (`c/colibri.c`, 14k lines): `mmap` of the container,
  `pread` of slabs, `O_DIRECT` when `DIRECT=1` (+65% on a Strix Halo in its
  table), `io_uring` when `URING=1`, an asynchronous expert-load pool
  (`PIPE=1`, 8 workers) overlapping reads with matmul, next-layer prefetch
  (`PILOT`), and an LRU cache plus a learned pin set saved in `.coli_usage`
  beside the model, so the second session is faster than the first.
- **The Qwen engine** (`c/qwen36.c`, 7k lines): `pread` plus
  `posix_fadvise(DONTNEED)`, an LRU of `--cap` experts per layer, and on
  Vulkan or CUDA a VRAM expert tier and a "dense chain" running whole layers
  on the device.
- **Routing.** By default the router's choice is untouched: where a weight
  sits changes speed, not the answer. `CACHE_ROUTE=1` (off by default) lets
  already-resident experts fill the lower-ranked slots, which does change the
  answer.
- **Serving.** `coli serve` is an OpenAI- and Anthropic-compatible API on
  127.0.0.1:8000 with a dashboard showing each expert fire; there is an MCP
  server. Vikix would only need to point `llm` and Super+i at that URL.
- **Offline.** The launcher reaches huggingface.co to download models and
  api.github.com to find a prebuilt engine; nothing else, and no telemetry
  was found in the sources.
- **Packaging.** Pure C with OpenMP; `make -C c qwen36` for the CPU,
  `VK=1` for Vulkan (needs `glslc`); the launcher is stdlib Python ≥ 3.10.
  Not in void-packages; prebuilt Linux x86_64 archives come with each
  release (v2.0.0, 2026-10-06).
- **Upstream.** Created 2026-07-01; 43k stars, 4.8k forks, 153 open issues,
  about 180 contributors, 20 releases, hundreds of commits a day in early
  October 2026, last push 2026-10-21. Young and churning: its own docs
  record a weight-format number claimed twice and a retracted measurement.
- **The disk's wear.** Reads do not wear flash the way writes do; the cost is
  the drive and the fan running flat out for as long as the model generates
  (Colibrì profiles 49% of GLM-5.2's time in disk reads on the Framework
  Desktop, and reads experts at 6.3 GB/s for Kimi K3). The 429 to 1,560 GB
  containers are the real storage cost.

## The verdict

**No-go**, for three reasons:

1. On the models that fit this machine's RAM, Colibrì's own measurements are
   three to eight times slower than what Ollama does here today.
2. On the models it exists for, the maker's best on this very chip is
   1.8 tok/s warm, about a word a second. Super+i, chat, Emacs and Neovim
   need ten times that. The container does not fit the free disk, and the
   download would take more than a day of the whole link.
3. An always-on Vikix Cloud node does not change the arithmetic: the best
   CPU result anywhere is about 1 tok/s, and the 9 tok/s result needed six
   RTX 5090s. Overnight batch answers from a 744B model would work, but
   nothing in Vikix asks for that today.

Ollama and llama.cpp stay the defaults, with no opt-in Colibrì backend.

**Look again when** Colibrì publishes 10 tok/s or more on a Strix Halo or a
128 GB CPU box for a model Ollama cannot run, or when a Vikix Cloud node has
a GPU and 512 GB or more of NVMe to spare.

## Running it here (not done)

Building and running Colibrì's engine on this machine was refused by the
agent's permission rules (code from outside the repository), so the table
above compares this machine's Ollama against Colibrì's published numbers on
the same model class and the same chip, not against a run here. To close
that gap, with the source already at `~/.cache/colibri-spike/src` (copied
from the 2026-10-17 checkout) and about 80 minutes of the whole link for
the download:

```sh
cd ~/.cache/colibri-spike/src/c
make qwen36 -j16                                    # CPU engine, about a minute
make qwen36 VK=1 -j16                               # or with Vulkan for the Radeon
mkdir -p ~/.cache/colibri-spike/models
./coli setup --model qwen3-coder-30b --backend cpu --dir ~/.cache/colibri-spike/models --yes
./coli plan --model ~/.cache/colibri-spike/models/qwen3-coder-30b     # resident vs streamed
./coli run  --model ~/.cache/colibri-spike/models/qwen3-coder-30b --cap 128 "the prompt above"
./coli run  --model ~/.cache/colibri-spike/models/qwen3-coder-30b --cap 32  "the prompt above"
COLI_VULKAN=1 ./coli run --model ~/.cache/colibri-spike/models/qwen3-coder-30b --cap 128 "the prompt above"
```

Read the engine's own footer for tok/s, time to first token and expert hits;
state warm or cold (drop the page cache between cold runs); record the
command, the commit and the load. `rm -r ~/.cache/colibri-spike` removes
everything the spike put on the disk.
