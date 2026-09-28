@echo off
rem vikix-firstlogon.cmd - Windows runs this once, at the first login after
rem the unattended install (the answer file's FirstLogonCommands), from the
rem answer disc. vikix-windows copies it there with Windows line endings.
rem
rem It installs what makes the VM pleasant, then leaves a file that tells
rem vikix-windows the install is done (read through the guest agent):
rem   virtio guest tools  drivers, the guest agent, clipboard and resizing
rem   WinFsp              which the shared folder (Z:) needs
rem   the shared folder   its service, started now and at every boot
rem   no sleep            Windows sleeping inside the VM only gets in the way
rem And it deletes the answer file's copies Windows keeps: they hold the
rem password in plain text.

setlocal
set VIKIX=C:\ProgramData\vikix
mkdir %VIKIX% 2>nul
set LOG=%VIKIX%\firstlogon.log
echo Vikix first login, %DATE% %TIME% > %LOG%

set VIRTIO=
set ANSWERS=
for %%d in (D E F G H I) do if exist %%d:\virtio-win-guest-tools.exe set VIRTIO=%%d:
for %%d in (D E F G H I) do if exist %%d:\vikix-answers.txt set ANSWERS=%%d:
echo virtio drivers on %VIRTIO%, answers on %ANSWERS% >> %LOG%

echo --- virtio guest tools >> %LOG%
if defined VIRTIO "%VIRTIO%\virtio-win-guest-tools.exe" /install /quiet /norestart >> %LOG% 2>&1
echo exit %ERRORLEVEL% >> %LOG%

echo --- WinFsp >> %LOG%
if defined ANSWERS msiexec /i "%ANSWERS%\winfsp.msi" /qn /norestart >> %LOG% 2>&1
echo exit %ERRORLEVEL% >> %LOG%

echo --- shared folder service >> %LOG%
rem The guest tools register it; if a version doesn't, register it here
rem from the driver disc (it needs WinFsp, installed above).
sc query VirtioFsSvc >nul 2>&1
if errorlevel 1 if defined VIRTIO (
  mkdir "%ProgramFiles%\VioFS" 2>nul
  copy /y "%VIRTIO%\viofs\w11\amd64\virtiofs.exe" "%ProgramFiles%\VioFS\" >> %LOG% 2>&1
  sc create VirtioFsSvc binpath= "\"%ProgramFiles%\VioFS\virtiofs.exe\"" start= auto depend= WinFsp.Launcher/VirtioFsDrv DisplayName= "VirtIO-FS Service" >> %LOG% 2>&1
)
sc config VirtioFsSvc start= auto >> %LOG% 2>&1
sc start VirtioFsSvc >> %LOG% 2>&1

echo --- power >> %LOG%
powercfg /change standby-timeout-ac 0 >> %LOG% 2>&1
powercfg /change monitor-timeout-ac 0 >> %LOG% 2>&1
powercfg /hibernate off >> %LOG% 2>&1

echo --- the answer file's copies >> %LOG%
del /f /q C:\Windows\Panther\unattend.xml >> %LOG% 2>&1
del /f /q C:\Windows\Panther\unattend-original.xml >> %LOG% 2>&1
del /f /q C:\Windows\System32\Sysprep\unattend.xml >> %LOG% 2>&1

echo done, %DATE% %TIME% >> %LOG%
echo ready > %VIKIX%\ready
