# Vikix on real machines

What a laptop does on Void's kernel, as Vikix finds it: which parts work
as installed, what to set after the first login, and what is still open.
One section a machine. Each starts from the machine's **hardware report**,
which the stick's installer saves in your home as `~/vikix-hardware-DATE.txt`
and which `vikix-hwreport` prints on any installed machine (it is in
`~/.local/bin` since 0.72.100; `sudo vikix-hwreport` sees the kernel's
messages on a machine where `dmesg` is root's).

## Reading a report

The report has a section for the machine (model, BIOS, kernel, memory,
Secure Boot), the PCI devices with the driver each got, the USB devices,
the network, the sound cards, the screens, the input devices (touch, pen,
keyboard, touchpad), power (battery, sleep states, the platform profile)
and, last, **the firmware the kernel asked for and didn't find, and other
complaints**. Read that last section first: a device with a driver but
no firmware is the usual reason Wi-Fi or sound is missing, and the line
names the file. `regulatory.db failed` there means the Wi-Fi radio is
on the cautious world settings and may leave out some 5 and 6 GHz
channels: the package `wireless-regdb` has the file, and it is in Vikix's
base since 0.72.100 (`vikix update` brings it to a machine installed
before).

## Power profiles

`vikix power` shows the current kernel profile and the profiles this machine supports. Choose one from **Super+m → System → Power profile**, or use:

```sh
vikix power set quiet
vikix power set balanced
vikix power set performance
```

Those three are offered by the Z13; other machines may offer different names, which the menu reads from the kernel. Unsupported choices are refused. Machines without this interface show no profile in the bar, and the command explains that the hardware does not expose it.

The bar says `power quiet`, `power balanced` or `power performance` beside the battery, even when the battery is full. It reads the kernel each time the bar refreshes, so a change from another tool is reflected too. A click on the field opens its explanation.

Switching may ask for administrator authentication in the desktop's password box (`pkexec`). Cancellation leaves the profile unchanged. Vikix installs no passwordless policy or background service, does not change profiles automatically on battery or AC, and does not save the choice across boots. `DRY_RUN=1 vikix power set quiet` prints the intended change. A profile is a firmware preference, not a promise of wattage, fan speed or performance; those depend on hardware, cooling and workload. See the [kernel's platform-profile documentation](https://docs.kernel.org/userspace-api/sysfs-platform_profile.html).

## ASUS ROG Flow Z13 (2025), GZ302EA

Installed from Vikix's stick (0.72.97) on 2026-10-18: kernel 6.18.57,
linux-firmware 20260810, BIOS 311 of August 2025, Secure Boot off. A
tablet with a detachable keyboard: AMD Ryzen AI Max+ 395, 128 GB of memory
shared by the processor and the graphics, a 13.4-inch 2560×1600 touch screen.

| Part | On Void's 6.18 |
|---|---|
| Processor and memory | Works; 121 GiB seen by the kernel |
| Graphics (Radeon 8060S, `amdgpu`) | Works: 2560×1600 at 180 Hz, 40 compute units, video decoding. The firmware sets 4 GB aside as graphics memory and the rest (62 GB) is shared on demand, the kernel's half; `vikix ai share most` lets the chip take all but 16 GB from the next boot |
| Wi-Fi 7 (MediaTek MT7925, `mt7925e`) | Works, firmware of June 2026. Needs `wireless-regdb` for every channel (see above) |
| Bluetooth (MediaTek, `btusb`) | Seen with its driver; not tried yet |
| Speakers (two Cirrus CS35L41 amplifiers) | Work: both amplifiers load their firmware (`cs35l41-hda`, gain 15). Quieter than under Windows, as other owners report; headphones work |
| Camera (ASUS 5M, `uvcvideo`) | Seen with its driver; not tried yet |
| Touch screen and pen (ELAN 9008) | Touch works in X; the pen is seen. Turning the screen round: not yet (TODO 59) |
| Keyboard and touchpad (detachable) | Work, with tap to click and natural scrolling from the base. F6 wears a "snip" picture but sends a plain F6 on Linux; Vikix makes it Print (udev's keys file, `55-hardware`, from 0.72.102), so F6 takes a screenshot, Shift+F6 keeps it as a file, Ctrl+F6 the window, Super+F6 the screen |
| Suspend | Modern standby (`s2idle`) only. Keys pressed while asleep did not wake it (tried 2026-10-19), so no sleep hook is needed on this kernel |
| Battery and charging | Seen (BAT0, two USB-C sources) |
| Fan and power modes | The kernel offers `quiet`, `balanced` and `performance` in `/sys/firmware/acpi/platform_profile`; Void has no asusctl. Choose from Super+m → System → Power profile, or `vikix power set PROFILE` |
| USB4 | Works: a Corsair EX400U SSD (20 Gb/s) is authorized as it arrives and mounts like a stick, through udev's Thunderbolt rule (`55-hardware`, see the README's "USB drives"). Before the rule the drive showed no disk at all: a USB4 SSD isn't USB storage, and the kernel leaves a new Thunderbolt device waiting for an OK |
| SD reader | Driver bound; not tried yet |
| NPU (AMD XDNA) | No driver bound in 6.18; nothing in Vikix uses it |
| Fingerprint reader | None on this model |

Harmless lines in the report's last section: four `ACPI Error: AE_ALREADY_EXISTS`
at boot and `BIOS _OSI(Linux) query ignored` (the firmware's), `asus_wmi:
fan_curve_get_factory_default ... failed: -19` (no factory fan curve to
read), and `GPT: Use GNU Parted to correct GPT errors` while the installer
stick is still plugged in.

### After installing

- **Text size.** The screen is 226 pixels an inch, so at X's default
  everything is tiny. In `~/.Xresources` (yours; the starter explains the
  choices) set `Xft.dpi: 192` and `Xcursor.size: 48`, then log out and in.
  That is twice the size, right for 13.4 inches; `160` if it feels big.
- **Wi-Fi channels.** `wireless-regdb` comes with the base now; on a
  machine installed from the 0.72.97 stick, `vikix update` adds it.
- **Speakers.** If they are too quiet, `alsamixer` (F6 for the second
  card) shows the amplifiers' own sliders beside the master; the ceiling
  itself is in the amplifiers' firmware settings and still open.

### Still open

Turning the screen round by hand and by itself (TODO 59), most of the
memory for models (TODO 60), Ollama on its graphics (61), and quiet or
full power from Super+m with the bar saying which (63): `TODO.md`, under
*The ROG Flow Z13*.

## Your machine

Make a report (`vikix-hwreport > ~/vikix-hardware-$(date +%F).txt`, with
`sudo` where `dmesg` needs it), read its last section, and add a section
like the one above to this page in a pull request, or send the report with
an issue: github.com/vukini/vikix.
