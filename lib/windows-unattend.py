#!/usr/bin/env python3
"""windows-unattend.py — the autounattend.xml that installs Windows by itself.

vikix-windows runs it for `vikix windows create` and puts the result on a
small disc next to the Windows ISO; Windows setup looks for the file on
every disc and follows it. The password comes on stdin, never on the
command line (where `ps` would show it).

  windows-unattend.py --user NAME --ui-lang en-US [--locale en-GB]
                      [--input de-DE] [--timezone "GMT Standard Time"]
                      [--key XXXXX-XXXXX-XXXXX-XXXXX-XXXXX]  < password

What it answers, pass by pass:
  windowsPE    the language; the CPU/TPM checks skipped (LabConfig), since an older
               CPU is fine in a VM; the whole VM disk for Windows; the key
  specialize   the computer's name
  oobeSystem   a local account (no Microsoft account), logged in once by
               itself; the setup questions answered; the time zone; and
               at that first login, vikix-firstlogon.cmd from the same disc
"""

import argparse
import sys
from xml.sax.saxutils import escape

# Microsoft's published generic key for Windows 11 Pro: it chooses the
# edition and installs, but doesn't activate. A key of your own replaces it.
GENERIC_PRO_KEY = "VK7JG-NPHTM-C97JM-9MPGT-3V66T"

# The drives the discs may get: the Windows ISO, the virtio drivers and the
# answer disc are three, in some order, after C:.
DRIVES = "DEFGHI"

NS = ('xmlns="urn:schemas-microsoft-com:unattend" '
      'xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"')


def component(name, body, arch="amd64"):
    return (f'    <component name="{name}" processorArchitecture="{arch}" '
            'publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">\n'
            + body + '    </component>\n')


def commands(tag, lines, key="Path"):
    """RunSynchronous / FirstLogonCommands blocks, numbered in order."""
    out = [f"      <{tag}>\n"]
    item = "RunSynchronousCommand" if tag == "RunSynchronous" else "SynchronousCommand"
    for i, line in enumerate(lines, 1):
        out.append(f'        <{item} wcm:action="add"><Order>{i}</Order>'
                   f"<{key}>{escape(line)}</{key}></{item}>\n")
    out.append(f"      </{tag}>\n")
    return "".join(out)


def password(value):
    return f"<Password><Value>{escape(value)}</Value><PlainText>true</PlainText></Password>"


def unattend(a, secret):
    ui, locale, inp = a.ui_lang, a.locale or a.ui_lang, a.input or a.locale or a.ui_lang
    user = escape(a.user)
    intl_pe = (f"      <SetupUILanguage><UILanguage>{ui}</UILanguage></SetupUILanguage>\n"
               f"      <InputLocale>{inp}</InputLocale>\n"
               f"      <SystemLocale>{locale}</SystemLocale>\n"
               f"      <UILanguage>{ui}</UILanguage>\n"
               f"      <UserLocale>{locale}</UserLocale>\n")
    intl = (f"      <InputLocale>{inp}</InputLocale>\n"
            f"      <SystemLocale>{locale}</SystemLocale>\n"
            f"      <UILanguage>{ui}</UILanguage>\n"
            f"      <UserLocale>{locale}</UserLocale>\n")

    # Setup refuses a CPU older than it likes, and checks for a TPM and
    # Secure Boot. The VM has those two; the CPU is the host's.
    #
    # The disk driver isn't loaded here. vikix-windows puts it on the answer
    # disc in a $WinPEDriver$ folder, which setup reads on any disc by
    # itself, for setup and for the installed Windows both. Two ways that
    # don't work in Windows 11 25H2: PnpCustomizationsWinPE's DriverPaths
    # stops setup (0x80070103 - 0x40031) at a drive letter that doesn't
    # exist, and the drive letters aren't known; and drvload loads the
    # driver for setup only, so the installed Windows can't find its disk.
    labconfig = [f'reg add HKLM\\SYSTEM\\Setup\\LabConfig /v {v} /t REG_DWORD /d 1 /f'
                 for v in ("BypassCPUCheck", "BypassTPMCheck", "BypassSecureBootCheck", "BypassRAMCheck")]
    setup = commands("RunSynchronous", labconfig)
    disk = """      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>300</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>3</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>
      <ImageInstall>
        <OSImage>
          <InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>
        </OSImage>
      </ImageInstall>
"""
    key = escape(a.key or GENERIC_PRO_KEY)
    userdata = (f"      <UserData>\n"
                f"        <AcceptEula>true</AcceptEula>\n"
                f"        <ProductKey><Key>{key}</Key><WillShowUI>OnError</WillShowUI></ProductKey>\n"
                f"      </UserData>\n")

    firstlogon = commands("FirstLogonCommands", [
        "cmd /c for %d in (" + " ".join(DRIVES) + ") do @if exist %d:\\vikix-answers.txt call %d:\\vikix-firstlogon.cmd",
    ], key="CommandLine")
    oobe = ("      <OOBE>\n"
            "        <HideEULAPage>true</HideEULAPage>\n"
            "        <HideLocalAccountScreen>true</HideLocalAccountScreen>\n"
            "        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>\n"
            "        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>\n"
            "        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>\n"
            "        <ProtectYourPC>3</ProtectYourPC>\n"
            "      </OOBE>\n"
            "      <UserAccounts>\n"
            "        <LocalAccounts>\n"
            '          <LocalAccount wcm:action="add">\n'
            f"            <Name>{user}</Name>\n"
            "            <Group>Administrators</Group>\n"
            f"            {password(secret)}\n"
            "          </LocalAccount>\n"
            "        </LocalAccounts>\n"
            "      </UserAccounts>\n"
            "      <AutoLogon>\n"
            "        <Enabled>true</Enabled>\n"
            f"        <Username>{user}</Username>\n"
            f"        {password(secret)}\n"
            "        <LogonCount>1</LogonCount>\n"
            "      </AutoLogon>\n")
    tz = f"      <TimeZone>{escape(a.timezone)}</TimeZone>\n" if a.timezone else ""

    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            f"<!-- Written by vikix-windows (lib/windows-unattend.py). -->\n"
            f"<unattend {NS}>\n"
            '  <settings pass="windowsPE">\n'
            + component("Microsoft-Windows-International-Core-WinPE", intl_pe)
            + component("Microsoft-Windows-Setup", setup + disk + userdata)
            + "  </settings>\n"
            '  <settings pass="specialize">\n'
            + component("Microsoft-Windows-Shell-Setup",
                        f"      <ComputerName>{escape(a.computer_name)}</ComputerName>\n")
            + "  </settings>\n"
            '  <settings pass="oobeSystem">\n'
            + component("Microsoft-Windows-International-Core", intl)
            + component("Microsoft-Windows-Shell-Setup", oobe + tz + firstlogon)
            + "  </settings>\n"
            "</unattend>\n")


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--user", required=True)
    p.add_argument("--ui-lang", required=True, help="the ISO's language, e.g. en-US")
    p.add_argument("--locale", help="formats and region, e.g. en-GB (default: --ui-lang)")
    p.add_argument("--input", help="keyboard, as a locale, e.g. de-DE (default: --locale)")
    p.add_argument("--timezone", help='a Windows time zone name, e.g. "GMT Standard Time"')
    p.add_argument("--key", help="a product key (default: the generic Pro key; not activated)")
    p.add_argument("--computer-name", default="vikix-windows")
    a = p.parse_args()
    secret = sys.stdin.readline().rstrip("\n")
    if not secret:
        sys.exit("windows-unattend.py: no password on stdin")
    if len(a.computer_name) > 15:
        sys.exit("windows-unattend.py: a computer name has at most 15 characters")
    sys.stdout.write(unattend(a, secret))


if __name__ == "__main__":
    main()
