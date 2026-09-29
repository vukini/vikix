# Windows in a window

Some programs only run on Windows: a bank's tool, an accounts package, desktop Outlook. Vikix can run Windows 11 in a virtual machine (VM): a whole Windows computer inside a window, which tiles like any other. Its clipboard is shared with yours, its screen resizes with the window, and a folder of yours is a drive in Windows.

It's optional, and it's big, so nothing is installed until you ask for it.

## What you need

- **A laptop with 8 GB of memory or more.** Windows gets 4 GB of it on an 8 GB machine, 6 GB on a 16 GB one, and half the processor's threads.
- **40 GB free** where the VM's disk goes. The disk can grow to 64 GB as Windows fills it.
- **The Windows 11 ISO**, the installer as one file, free from Microsoft: [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11). Choose the disk image (ISO) for x64 devices, and your language.
- **A product key, if you have one.** Without it, Windows 11 Pro installs and works, with a reminder to activate it.
- **About half an hour**, most of it waiting.

Your laptop doesn't need to meet Windows 11's own requirements: the VM has the TPM and Secure Boot it asks for, and the check for a newer processor is skipped.

## Installing Windows

Four commands, in a terminal.

1. **Once, the parts it needs** (about 250 MB of packages, and the Windows drivers disc):

   ```sh
   vikix windows setup
   ```

   It asks for your password (sudo) once, for the packages and the VM's network. To put the VM's disk somewhere else, such as a bigger drive: `vikix windows setup --disk /path/to/folder`. (`vikix add windows` runs the same setup: Windows is one of the features.)

2. **Install Windows** from the ISO you downloaded:

   ```sh
   vikix windows create ~/Downloads/Win11_25H2_English_x64.iso
   ```

   Use your ISO's real name (the Tab key completes it). Add `--key XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` if you have a product key. It asks for a password for your Windows account, which is named after your Linux one.

3. **Wait.** Windows installs itself: the drivers, the disk, your account (a local one, no Microsoft account needed), then the tools that share the clipboard and your folder. A notification says *Windows is ready*, about 25 minutes later. To watch, run `vikix windows` in the meantime.

4. **Open it:**

   ```sh
   vikix windows
   ```

   Or **Super+m** → *Windows (the VM)*. Log in with the password from step 2.

## Day to day

- **Opening it.** `vikix windows` (or *Windows* in Super+m) starts Windows if it's off and opens its desktop. Close the window and Windows keeps running; open it again the same way.
- **The bar** says **win** while Windows runs, since it uses memory and battery.
- **Your files.** `~/Windows` on this laptop is drive **Z:** in Windows. Put files there to use them on both sides. `vikix backup` covers that folder.
- **Copy and paste** work both ways.
- **The window** tiles like any other: split the screen, move it, make it full screen with Super+f. Windows changes its screen size to fit.
- **Shutting it down.** Shut Windows down from its own Start menu, or run `vikix windows stop`. Reboot and Power off in Super+Shift+Escape shut Windows down properly first. Logging out leaves it running.
- **Is it on?** `vikix windows status` says whether it's installed and running, and where its parts are.

## What it can reach

Windows reaches the internet and your home or office network. It sees this laptop only as another computer on a private network, at 192.168.122.1. What this laptop keeps to itself stays out of reach: the window manager's Lisp connection, the printers' settings, a local AI model. So a bad download in Windows can't take over your desktop.

There's nothing to set up for it: `vikix windows setup` does it. To reach a program on this laptop from Windows on purpose, run that program on 192.168.122.1, not on 127.0.0.1.

## Changing it

More memory, more processors, or a USB device handed to Windows: open the VM manager with

```sh
virt-manager -c qemu:///session
```

and open the *windows* VM's details. Change memory and processors while Windows is shut down. A USB device is added the same way (*Add Hardware* → *USB Host Device*).

## Removing it

```sh
vikix windows remove
```

It asks first, then deletes the VM and its disk. `~/Windows`, with your files in it, stays.

## When it goes wrong

| What happens | What to do |
|---|---|
| `create` says it needs 8 GB of memory | The laptop has less; Windows 11 won't run well in a VM on it |
| The install seems stuck | `vikix windows` shows its screen. The install's log is `~/.local/state/vikix/windows-install.log` |
| No *Windows is ready* after an hour | Open it with `vikix windows` and look: Windows may be waiting on a question |
| The Windows window doesn't open | `vikix windows status` says what's missing |
| A notification says the VM is on its old network | Restart Windows (Start → Restart); `vikix windows status` then says it's on the private one |
| Windows is slow | Give it more memory or processors (see [Changing it](#changing-it)), and close what you don't need on both sides |
| Windows won't shut down | `vikix windows stop --force` switches it off, like pulling the plug |

The [README](../README.md#windows-in-a-vm) has how it works underneath.
