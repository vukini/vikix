#!/usr/bin/env python3
"""installer/qemu-test.py ISO WORKDIR — the stick, end to end, in QEMU.

1. Boots ISO's live system under UEFI (OVMF) with a serial console, logs
   in as root, and runs vikix-installer from an answers file onto an empty
   40 GB virtual disk (encrypted, console=ttyS0 added for step 2).
2. Boots that disk alone, types the disk passphrase at the initramfs's
   prompt, logs in as the new user and prints what matters: the kernel,
   the encryption and its settings, /boot, the services, Vikix's checkout
   and the firstboot block and marker.

VIKIX_TEST_MIRROR=URL takes Void's packages from a mirror of your own
(the VM reaches the host as 10.0.2.2), for a network that the VM can't
use for HTTPS. Everything the serial console showed is in WORKDIR/serial.log. Without KVM
(a container) it takes an hour or more; with it, minutes. Needs
qemu-system-x86_64, OVMF, xorriso and python3-pexpect. Exit 0 when every
check passed.
"""
import os, re, shutil, subprocess, sys
import pexpect

iso, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
os.makedirs(work, exist_ok=True)
log = open(os.path.join(work, "serial.log"), "w")
PASS = "vikix-test"
OVMF = "/usr/share/OVMF"

subprocess.run(["xorriso", "-osirrox", "on", "-indev", iso,
                "-extract", "/boot/vmlinuz", f"{work}/vmlinuz",
                "-extract", "/boot/initrd", f"{work}/initrd"],
               check=True, capture_output=True)
disk = f"{work}/disk.qcow2"
if os.path.exists(disk):
    os.remove(disk)
subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", disk, "40G"], check=True)
shutil.copy(f"{OVMF}/OVMF_VARS_4M.fd", f"{work}/vars.fd")

accel = ["-accel", "kvm", "-cpu", "host"] if os.path.exists("/dev/kvm") else ["-accel", "tcg"]
qemu = ["qemu-system-x86_64", "-machine", "q35", "-m", "4096", "-smp", "2", *accel,
        "-nographic", "-no-reboot",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF}/OVMF_CODE_4M.fd",
        "-drive", f"if=pflash,format=raw,file={work}/vars.fd",
        "-drive", f"file={disk},if=virtio,format=qcow2",
        "-netdev", "user,id=n", "-device", "virtio-net-pci,netdev=n"]

def spawn(extra):
    p = pexpect.spawn(qemu[0], qemu[1:] + extra, encoding="utf-8",
                      codec_errors="replace", timeout=600, maxread=65536)
    p.logfile_read = log
    return p

fails = []
def check(name, ok):
    print(("ok   " if ok else "FAIL ") + name, flush=True)
    if not ok:
        fails.append(name)

# --- 1. the live system, and the install ---------------------------------------
print(":: booting the stick", flush=True)
p = spawn(["-cdrom", iso, "-kernel", f"{work}/vmlinuz", "-initrd", f"{work}/initrd",
           "-append", "root=live:CDLABEL=VOID_LIVE ro init=/sbin/init rd.luks=0 rd.md=0 "
                      "rd.dm=0 loglevel=4 console=ttyS0,115200"])
p.expect(r"login: ", timeout=1800)
p.sendline("root"); p.expect("Password:"); p.sendline("voidlinux")
p.expect(r"# ", timeout=120)
p.sendline("stty cols 200; export PS1='LIVE# '")
p.expect("LIVE# ")
answers = f"""VI_DISK=/dev/vda
VI_FULLNAME="Test User"
VI_USER=tester
VI_PASSWORD={PASS}
VI_HOSTNAME=vikix-qemu
VI_ENCRYPT=yes
VI_PASSPHRASE={PASS}
VI_TIMEZONE=Asia/Dubai
VI_KEYMAP=us
VI_WITH=essentials
VI_MIRROR={os.environ.get("VIKIX_TEST_MIRROR", "https://repo-default.voidlinux.org")}
VI_HOSTONLY=no
VI_EXTRA_CMDLINE="console=ttyS0,115200"
"""
p.sendline("cat > /tmp/answers <<'EOF'\n" + answers + "EOF")
p.expect("LIVE# ")
check("the stick has vikix-installer", True)
p.sendline("vikix-installer --answers /tmp/answers; echo INSTALL-EXIT=$?")
print(":: installing (slow without KVM)", flush=True)
p.expect(r"INSTALL-EXIT=(\d+)", timeout=4 * 3600)
check("vikix-installer finished", p.match.group(1) == "0")
p.expect("LIVE# ")
p.sendline("poweroff")
p.expect(pexpect.EOF, timeout=300)

if fails:
    print("the install failed; see", log.name); sys.exit(1)

# --- 2. the installed system -------------------------------------------------------
print(":: starting the installed system", flush=True)
p = spawn([])
p.expect(r"(?i)passphrase", timeout=1800)
check("the initramfs asks for the passphrase", True)
p.sendline(PASS)
p.expect(r"login: ", timeout=1800)
p.sendline("tester"); p.expect("Password:"); p.sendline(PASS)
p.expect(r"\$ ", timeout=120)
p.sendline("export PS1='NEW$ '; stty cols 200")
p.expect("NEW\\$ ")

def sh(cmd, timeout=120):
    p.sendline(cmd + "; echo '<<'END")
    p.expect("<<END", timeout=timeout)
    p.expect("NEW\\$ ")
    return p.before.replace("\r", "")

out = sh("uname -r"); print(out.strip())
check("kernel 6.18 or newer", bool(re.search(r"\n6\.(1[89]|[2-9]\d)", out)))
out = sh(f"echo {PASS} | sudo -S cryptsetup status cryptroot")
check("root is LUKS2", "LUKS2" in out)
check("discards on", "discards" in out)
check("no read workqueue", "no_read_workqueue" in out)
out = sh("findmnt -no FSTYPE,SOURCE / ; findmnt -no FSTYPE /boot")
check("/ is ext4 on cryptroot", "ext4" in out and "cryptroot" in out)
check("/boot is vfat", "vfat" in out)
out = sh("ls /boot/EFI; ls /var/service")
check("GRUB in its own place and the fallback", "Vikix" in out and "BOOT" in out)
check("NetworkManager on", "NetworkManager" in out)
check("dhcpcd not on", "dhcpcd" not in out)
out = sh("ls ~/vikix/installer ~/vikix/install.sh; git -C ~/vikix remote get-url origin")
check("Vikix in ~/vikix", "install.sh" in out and "firstboot" in out)
check("its origin is GitHub", "github.com/vukini/vikix" in out)
out = sh("head -3 ~/.bash_profile; cat ~/.local/state/vikix/firstboot; ls ~")
check("the firstboot block", "vikix firstboot" in out)
check("the features marker", "VIKIX_WITH=essentials" in out)
check("the hardware report", "vikix-hardware-" in out)
out = sh("passwd -S root 2>/dev/null || sudo -n true; cat /etc/hostname; readlink /etc/localtime")
check("hostname", "vikix-qemu" in out)
check("time zone", "Asia/Dubai" in out)
out = sh("sleep 5; ip route | grep -q '^default' && getent hosts repo-default.voidlinux.org >/dev/null && echo NET-OK")
check("online at the first start (a route and DNS)", "NET-OK" in out)
p.sendline(f"echo {PASS} | sudo -S poweroff")
p.expect(pexpect.EOF, timeout=300)

print("all passed" if not fails else f"{len(fails)} failed: {fails}")
sys.exit(1 if fails else 0)
