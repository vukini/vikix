# layertest.ps1: a small red form, opaque or see-through as a whole, for
# trying how FreeRDP's RemoteApp draws Windows' layered windows (layertest.py
# opens it). Closes itself after 7 seconds; logs to C:\Users\Public.
param([double]$opacity = 1.0)
Start-Transcript -Path "$env:PUBLIC\vikix-layertest.log" -Force | Out-Null
"Z: $(Test-Path 'Z:\') Y: $(Test-Path 'Y:\') user $env:USERNAME session $([System.Diagnostics.Process]::GetCurrentProcess().SessionId)"
try {
  Add-Type -AssemblyName System.Windows.Forms
  $f = New-Object System.Windows.Forms.Form
  $f.Text = 'layertest'; $f.StartPosition = 'Manual'
  $f.Location = New-Object System.Drawing.Point(100, 100)
  $f.Size = New-Object System.Drawing.Size(320, 160)
  $f.BackColor = [System.Drawing.Color]::Red; $f.TopMost = $true
  $f.Opacity = $opacity
  $l = New-Object System.Windows.Forms.Label
  $l.Text = 'LAYER TEST'; $l.AutoSize = $true; $l.ForeColor = 'White'
  $l.Font = New-Object System.Drawing.Font('Segoe UI', 20)
  $l.Location = New-Object System.Drawing.Point(20, 30); $f.Controls.Add($l)
  $t = New-Object System.Windows.Forms.Timer; $t.Interval = 7000
  $t.Add_Tick({ $f.Close() }); $t.Start()
  [System.Windows.Forms.Application]::Run($f)
  'form closed'
} catch { "ERROR: $_" }
Stop-Transcript | Out-Null
