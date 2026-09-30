# The AI desktop

A plan for a desktop that sits at work, next to the ROG Flow Z13 (TODO items 58–63). Decided with Vid on 2026-09-30: one AMD Radeon AI PRO R9700, with room for a second.

## What it is for

The Z13 holds the big models (128 GB) but is slow to read long input. This machine is for what the Z13 is slow at, and for what a laptop can't do.

- **Reading fast.** A pile of emails, a long document, a folder of notes: a card with its own fast memory reads several times quicker than the Z13.
- **Running all the time.** Jobs that go on overnight, such as the desk (TODO item 21) sorting the business mail, with nothing leaving the office.
- **Serving the laptop.** Over Tailscale (TODO item 16), the Z13 and the X1 send it jobs from anywhere, through `vikix ai use` (TODO item 12).
- **Linux at work.** The work ERP needs Windows; Vikix's Windows VM (`vikix windows`) runs it in a window. With 16 cores and 128 GB this is comfortable, which could make Linux full-time at work possible.

It does not need to hold the biggest models: that is the Z13's job.

## The parts

| Part | Choice | Why |
|---|---|---|
| Graphics | **AMD Radeon AI PRO R9700, 32 GB** | 32 GB, like an RTX 5090, for a third to a half of the price; AMD's drivers are part of Linux, so nothing extra to install on Void |
| Processor | AMD Ryzen 9 9950X (16 cores) | AI, the Windows VM and everyday work at once |
| Cooler | A large quiet air cooler (Noctua NH-D15 G2 class) | Quiet in an office; no pump to fail |
| Motherboard | X870E with two graphics slots that split x8/x8 (ASUS ProArt X870E-Creator WiFi class) | Room for a second R9700 later |
| Memory | 128 GB DDR5 as **two** 64 GB sticks | Windows VM, big jobs, and model parts that spill past the card's 32 GB. Two sticks run faster than four on this platform. The priciest part this year: shop around |
| Storage | 4 TB NVMe | Models are big (20–100 GB each), plus the Windows VM's disk |
| Power supply | 1200 W, ATX 3.1 | One R9700 is 300 W; two are 600 W, plus the processor, with headroom |
| Case | Sound-dampened, with room for two cards (Fractal Define 7 class) | See Noise below |

"Class" means any equivalent model is fine; these are what to ask a shop for.

### Noise

Every R9700 found so far (ASUS Turbo, Gigabyte AI TOP, Sapphire, PowerColor, ASRock Creator, XFX) uses a **blower** fan: it pushes the heat out of the back of the case, which suits two cards side by side, but it is louder than a gaming card's fans. So:

- a sound-dampened case,
- the card's power limited a little (it loses a few percent of speed and a lot of noise; set on Linux, and measured once it's built),
- if the office is very quiet, the machine can sit under the desk or in a cupboard with airflow; it is used over the network anyway.

## Cost (rough, 2026-09-30)

- The R9700: about **$1,400–2,100** in stock (July–August 2026; list price $1,299).
- The whole machine: about **$4,000–5,000**. Memory and graphics prices moved a lot in 2026; check Dubai prices before buying.
- For comparison, the same build with an RTX 5090 (about $4,300 for the card alone) comes to about $7,000: about a third faster, not two to three times.

## What it runs

The card holds models up to about 32 GB at full speed; bigger ones spill into the 128 GB of main memory and slow down.

| Model | Speed on one R9700 | Use |
|---|---|---|
| Mid-size mixture-of-experts models (30–35 billion parameters, e.g. Qwen3.5-35B-A3B) | about 127–163 tokens a second | The everyday work: mail, summaries, drafting, Super+i |
| Small dense models (7–8 billion) | about 99 tokens a second | Quick jobs, many at once |
| Dense 70 billion | doesn't fit one card; about 11 tokens a second on two | Only with the second card |

Reading long input is 2.6–3.4× slower than on NVIDIA's cards, and still far quicker than the Z13.

## Software

- Void (glibc) and Vikix, as on the laptops.
- Ollama through `vikix ai setup`, on the card. Vulkan first (Ollama's Vulkan library, which Vikix keeps); ROCm tried against it, since ROCm reads long input faster on this card. Measured on the machine, then written down here.
- Reachable from the Z13 and the X1 over Tailscale only, never open to the office network or the internet; like Swank, with a password or key.
- The Windows VM for the ERP (`vikix windows setup`, `vikix windows create ISO`).
- A Vikix hardware profile for it, as for the Z13: the card's power limit, and the models the picker offers for 32 GB.

## Later

- **A second R9700:** 64 GB, for dense 70-billion models and two jobs at once. Two cards don't make one answer faster; they make bigger models fit.

## Still to decide

- Where it sits (under a desk, a cupboard, the server room), which decides how much the noise matters.
- Buying the parts and having a Dubai shop assemble it, or a ready-built workstation.
- Whether the office network allows Tailscale, or IT needs asking first.

## Sources

- [RTX 5090 vs Dual AMD R9700 for Local AI in 2026 (RunAIHome, Aug 2026)](https://runaihome.com/blog/rtx-5090-vs-dual-amd-r9700-value-comparison-2026/)
- [AMD Radeon AI PRO R9700 for Local AI in 2026 (RunAIHome)](https://runaihome.com/blog/amd-radeon-ai-pro-r9700-local-ai-hardware-guide-2026/)
- [All the Radeon AI Pro R9700 cards announced (TechRadar)](https://www.techradar.com/pro/here-are-all-the-radeon-ai-pro-r9700-cards-that-have-been-announced-msi-xfx-biostar-and-acer-are-still-missing)
- [Radeon AI Pro R9700 review (LocalAIMaster)](https://localaimaster.com/blog/radeon-ai-pro-r9700-local-ai)
- [Local AI Hardware Guide 2026 (Context Studios, Sep 2026)](https://www.contextstudios.ai/blog/local-ai-hardware-guide-2026)
