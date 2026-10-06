# Installing from Vikix's stick

Vikix's stick installs Void and Vikix together: you answer a few questions, it erases one disk, and twenty minutes after the first login you are at the desktop. It is the easier way, and on a new laptop often the only one that works: Void's own image is from February 2025 (kernel 6.12), and laptops made since need a newer kernel and firmware for their Wi-Fi, sound and graphics. The stick carries Void's current ones. [Installing Void for Vikix](install-void.md) is the other way, Void's installer by hand, then Vikix.

**The whole disk is erased, Windows included.** The stick doesn't install beside another system. Copy off anything you want to keep first.

You need:

- a 64-bit PC or laptop (x86_64) that starts with UEFI, with 30 GB of disk or more,
- a USB stick of 2 GB or more, which is erased too,
- the network: Wi-Fi or a cable. The stick installs today's packages from Void, not its own.

## Making the stick

The image is made from this repository by `installer/build-image.sh`, with Void's own tool for its live images (void-mklive). On a Vikix or Void machine:

```sh
cd ~/vikix
sudo installer/build-image.sh
```

About fifteen minutes and 4 GB of space the first time; it leaves `vikix-VERSION-DATE-x86_64.iso` and its checksum in the folder you ran it from. The image is about 1.3 GB, most of it firmware.

Write it to the stick. Find the stick's name with `lsblk` (here `/dev/sdX`; the wrong name erases the wrong disk), then:

```sh
sudo dd if=vikix-VERSION-DATE-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

On Windows, Rufus writes it (choose *DD image mode* when it asks).

## Before starting from it

**Switch Secure Boot off** in the computer's firmware settings. Void's kernel isn't signed for it, so with it on the stick may start but the installed system won't. The installer checks, and stops with this advice if it's on.

- On an ASUS laptop (the ROG Flow Z13 among them): hold **F2** while it starts for the settings; Secure Boot is under *Security*. Save and leave. **Esc** while it starts is the boot menu, to pick the stick.
- On a ThinkPad: **F1** for the settings (*Security* → *Secure Boot*), **F12** for the boot menu.
- Elsewhere the keys are often F2, Del, F10, F11 or F12.

## The questions

Start from the stick: its menu's first entry starts it. The first screen logs in by itself and the installer starts. Arrows move, Enter chooses, Tab moves to the buttons, and **Esc stops** at any point: nothing is changed until the last question.

1. **Network**, only if there is none yet: choose *Connect to Wi-Fi*, then your network and its password. The connection is copied to the installed system, so its first start is online too.
2. **Disk**: the one to erase. The stick itself isn't offered.
3. **You**: your name, a short login name, and your password (also the one `sudo` asks for). `root` gets no password; `sudo` is the way in.
4. **Computer**: a name for it.
5. **Encryption**: yes is the default and the advice for a laptop. A passphrase is asked at every start; your login password can be it. You won't notice the cost: the processor encrypts in hardware, about as fast as the disk can read.
6. **Time zone** and **keyboard** (for the text screens; the desktop's layout is in Vikix's welcome).
7. **How much of Vikix**: the desktop alone, or with the *essentials* (Emacs, C, Python, Lisp), *developer* (both editors, every language) or *everything* (also LibreOffice and printing). Anything left out is one `vikix add` later.
8. **Last chance**: it shows what it will do. Type `erase` to go ahead.

Then it works by itself for a few minutes: the disk, Void, the boot loader, a copy of Vikix brought up to date from GitHub. At the end it says what comes next, and restarts. Take the stick out.

## The first start

1. Type the disk passphrase, if you chose encryption.
2. Log in as yourself on the first screen.
3. Vikix's own install runs by itself: it asks for your password once, then downloads the desktop and builds the window manager, twenty minutes or more.
4. Enter restarts, and the next login is the desktop. [Your first hour](first-hour.md) is the page after.

If it stops, the message names the stage. Run `~/vikix/install.sh` again (every stage is safe to re-run), or log out and in again on the first screen, which starts it again. [When something breaks](fixing.md#the-install-stopped) says more.

## What the stick saw

Before installing, the stick can tell you what it made of the machine: switch to the second screen (**Alt+F2**), log in as `anon` (password `voidlinux`), and run `vikix-hwreport | less`. It lists the machine, the kernel, every device with its driver, the network, sound cards, screens, touch and pen, the battery, and the firmware the kernel asked for and didn't find. The installer saves the same report in your home, `~/vikix-hardware-DATE.txt`, for when something doesn't work later.

## How the disk is laid out

Two partitions, on a GPT table:

| Partition | Size | What | Mounted at |
|---|---|---|---|
| 1 | 1 GiB | EFI System, vfat: GRUB, the kernel and the initramfs | `/boot` |
| 2 | the rest | LUKS2 (when encrypting), then ext4 | `/` |

Only the boot files are left unencrypted, so GRUB starts without a passphrase of its own and the initramfs asks for the disk's. The encryption uses LUKS2's defaults (AES-XTS, Argon2id for the passphrase), with TRIM passed through and dm-crypt's extra queues switched off, which on a fast NVMe disk only add delay; all three are kept in the LUKS header. The new system starts with NetworkManager (Vikix's network) rather than Void's dhcpcd.

## How it was tested

`installer/qemu-test.py` starts the stick in QEMU under UEFI, installs onto an empty virtual disk with encryption from an answers file, then starts that disk alone, types the passphrase and checks the result: the kernel, LUKS2 and its settings, `/boot`, the services, the network, `~/vikix` and the first-start step. `tests/installer.sh`, in the usual tests, checks the installer's steps in a dry run and the first-start step with stand-ins. Neither runs Vikix's own install, which the other tests cover.
