<#
.SYNOPSIS
  Apply the Comfort Shell setup and run the WSL bootstrap.
#>
[CmdletBinding()]
param(
    [switch]$NonInteractive,
    [string]$Distro,
    [string[]]$BootstrapArgs = @(),
    [string]$ResumeEncodedArgs
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

# Restore params from previous invocation if RunOnce armed us.
if ($ResumeEncodedArgs) {
    try {
        $resume = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ResumeEncodedArgs)) | ConvertFrom-Json
        if ($resume.NonInteractive) { $script:NonInteractive = $true }
        if ($resume.Distro) { $script:Distro = [string]$resume.Distro }
        if ($resume.BootstrapArgs) { $script:BootstrapArgs = @($resume.BootstrapArgs | ForEach-Object { [string]$_ }) }
        Write-Host "  (Resumed from reboot; restored original arguments.)" -ForegroundColor DarkGray
    } catch { Write-Host "  (Could not decode resume state: $_)" -ForegroundColor DarkYellow }
}

$script:CurrentStep = 0; $script:TotalSteps = 5

function Set-ConsoleTitle($Title) { try { $Host.UI.RawUI.WindowTitle = $Title } catch {} }
function Step($Message) {
    $script:CurrentStep++
    Write-Host "`n▶ [$script:CurrentStep/$script:TotalSteps] $Message" -ForegroundColor Cyan
    Set-ConsoleTitle "Comfort Shell · $script:CurrentStep/$script:TotalSteps · $Message"
}
function Reset-TerminalInputMode {
    [Console]::Out.Write("$([char]27)[?9001l$([char]27)[?1004l"); [Console]::Out.Flush()
    try { $Host.UI.RawUI.FlushInputBuffer(); while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch {}
}
function Read-YesNo($Prompt, [bool]$Default = $true) {
    $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
    if ($script:NonInteractive) { Write-Host "$Prompt $hint $(if($Default){'yes'}else{'no'}) (auto)" -ForegroundColor DarkGray; return $Default }
    Reset-TerminalInputMode
    while ($true) {
        $ans = (Read-Host "$Prompt $hint").Trim()
        if ([string]::IsNullOrWhiteSpace($ans)) { return $Default }
        if ($ans -match '^(y|yes)$') { return $true }
        if ($ans -match '^(n|no)$') { return $false }
        Write-Host '  Please enter y or n.' -ForegroundColor Yellow
    }
}

function Invoke-NativeConsole($FilePath, [string[]]$ArgumentList = @()) {
    # Simplified argument joining (safe for wsl.exe calls)
    $argsStr = ($ArgumentList | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join ' '
    $proc = Start-Process -FilePath $FilePath -ArgumentList $argsStr -NoNewWindow -Wait -PassThru
    Reset-TerminalInputMode
    return $proc.ExitCode
}

function Get-InstalledWslDistros {
    $raw = (& wsl.exe --list --quiet) 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) { return @() }
    return @($raw | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ -like 'Ubuntu*' })
}

function Set-ResumeAfterReboot($ScriptPath) {
    if (-not (Test-Path $ScriptPath)) { return }
    $payload = @{}
    if ($script:NonInteractive) { $payload['NonInteractive'] = $true }
    if ($script:Distro) { $payload['Distro'] = $script:Distro }
    if ($script:BootstrapArgs) { $payload['BootstrapArgs'] = $script:BootstrapArgs }
    
    $resumeArgs = ""
    if ($payload.Count -gt 0) {
        $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress)))
        $resumeArgs = " -ResumeEncodedArgs $b64"
    }
    
    $launcher = "Start-Process -FilePath 'wt.exe' -ArgumentList 'new-tab --title `"Comfort Shell Setup`" powershell.exe -NoExit -ExecutionPolicy Bypass -File `"$($ScriptPath -replace "'", "''")`"$resumeArgs'"
    $cmd = "powershell.exe -NoProfile -EncodedCommand $([Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($launcher)))"
    
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name 'ComfortShellResume' -Value $cmd -Force
    Write-Host '  Auto-resume registered for next login.' -ForegroundColor DarkGray
}

function Install-WslPlatform {
    Write-Host "`nWSL is not installed. It is required for Comfort Shell." -ForegroundColor Yellow
    if (-not (Read-YesNo 'Install WSL now?')) { Write-Host "Skipping. Run 'wsl --install --no-distribution' manually."; return }
    
    Write-Host 'Installing WSL platform...' -ForegroundColor Cyan
    if ((Invoke-NativeConsole 'wsl.exe' @('--install', '--no-distribution')) -ne 0) {
        Write-Host "WSL installation failed." -ForegroundColor Red; return
    }
    
    Write-Host "`nWSL installed! Reboot required." -ForegroundColor Green
    Set-ResumeAfterReboot $PSCommandPath
    if (Read-YesNo 'Reboot now?') { Start-Sleep 10; Restart-Computer -Force }
    else { Write-Host 'Reboot manually to resume.' -ForegroundColor Yellow }
}

function Select-WslDistro {
    $online = @(
        @{Name='Ubuntu'; Friendly='Latest LTS'}, @{Name='Ubuntu-24.04'; Friendly='24.04 LTS'},
        @{Name='Ubuntu-22.04'; Friendly='22.04 LTS'}, @{Name='Ubuntu-20.04'; Friendly='20.04 LTS'}
    )
    Write-Host "`nAvailable distros:" -ForegroundColor Cyan
    for ($i=0; $i -lt $online.Count; $i++) { Write-Host "  $($i+1)) $($online[$i].Name) ($($online[$i].Friendly))" }
    
    if ($script:NonInteractive) { return 'Ubuntu' }
    Reset-TerminalInputMode
    while ($true) {
        $ans = (Read-Host "Pick [1-$($online.Count)] or name (default: Ubuntu)").Trim()
        if (!$ans) { return 'Ubuntu' }
        if ($ans -match '^\d+$' -and [int]$ans -ge 1 -and [int]$ans -le $online.Count) { return $online[[int]$ans-1].Name }
        $match = $online | Where-Object Name -eq $ans
        if ($match) { return $match.Name }
        Write-Host "  Invalid choice." -ForegroundColor Yellow
    }
}

function Install-NewDistro($Name) {
    for ($i=1; $i -le 3; $i++) {
        Write-Host "`nInstalling $Name (attempt $i)..." -ForegroundColor Cyan
        Invoke-NativeConsole 'wsl.exe' @('--install', '-d', $Name, '--no-launch') | Out-Null
        if ((Get-InstalledWslDistros) -contains $Name) { return $Name }
        Start-Sleep (if($i -eq 1){5}else{15})
    }
    Write-Host "Failed to install $Name. Check network/proxy." -ForegroundColor Red
    return $null
}

function Resolve-Distro {
    $existing = @(Get-InstalledWslDistros)
    if ($Distro) {
        if ($Distro -notlike 'Ubuntu*') { throw "Only Ubuntu is supported." }
        if ($existing -contains $Distro) { return $Distro }
        return Install-NewDistro $Distro
    }
    if ($existing.Count -eq 0) { return Install-NewDistro (Select-WslDistro) }
    
    # Interactive selection of existing or new
    Write-Host "`nExisting distros:" -ForegroundColor Cyan
    $existing | ForEach-Object { $i=1; Write-Host "  $i) $_"; $i++ }
    Write-Host "  $($existing.Count + 1)) Install new" -ForegroundColor DarkGray
    
    if ($script:NonInteractive) { return $existing[0] }
    Reset-TerminalInputMode
    while ($true) {
        $ans = (Read-Host "Pick [1-$($existing.Count + 1)]").Trim()
        if (!$ans) { return $existing[0] }
        if ($ans -match '^\d+$') {
            $idx = [int]$ans
            if ($idx -le $existing.Count) { return $existing[$idx-1] }
            if ($idx -eq $existing.Count + 1) { return Install-NewDistro (Select-WslDistro) }
        }
        if ($existing -contains $ans) { return $ans }
        Write-Host "  Invalid." -ForegroundColor Yellow
    }
}

function Invoke-ComfortShellBootstrap($DistroName) {
    $src = Join-Path $PSScriptRoot 'comfort-shell-bootstrap.sh'
    if (-not (Test-Path $src)) { throw "Bootstrap script not found: $src" }
    
    $staged = Join-Path $env:TEMP "csb-$([guid]::NewGuid().ToString('N')).sh"
    Copy-Item $src $staged -Force
    try {
        $wslPath = ((& wsl.exe -d $DistroName wslpath -u ($staged -replace "'", "'\''")) -replace "`0", '' | Select -First 1).Trim()
        if (!$wslPath) { throw "wslpath failed." }
        
        $bsArgs = ($BootstrapArgs | ForEach-Object { "'$($_ -replace "'", "'\''")'" }) -join ' '
        if ($NonInteractive) { $bsArgs = "--non-interactive $bsArgs" }
        
        $bashCmd = "set -euo pipefail; cp '$wslPath' ~/csb.sh && sed -i 's/\r$//' ~/csb.sh && chmod +x ~/csb.sh && ~/csb.sh $bsArgs"
        if ((Invoke-NativeConsole 'wsl.exe' @('-d', $DistroName, '--', 'bash', '-lc', $bashCmd)) -ne 0) {
            throw "Bootstrap failed in WSL."
        }
    } finally { Remove-Item $staged -Force -ErrorAction SilentlyContinue }
}

function Install-NerdFont {
    $fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $regPath  = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $wanted   = @('CascadiaCodeNF.ttf', 'CascadiaMonoNF.ttf')
    
    # Skip if already installed
    $regVals = (Get-ItemProperty $regPath -EA SilentlyContinue).PSObject.Properties.Value
    if (($wanted | Where-Object { -not (Test-Path (Join-Path $fontsDir $_)) -or -not ($regVals -like "*\$_") }).Count -eq 0) {
        Write-Host "Nerd fonts already installed."; return
    }

    $ver = '2407.24'; $zipUrl = "https://github.com/microsoft/cascadia-code/releases/download/v$ver/CascadiaCode-$ver.zip"
    $workDir = Join-Path $env:TEMP "Cascadia-$ver"; $zipPath = Join-Path $workDir 'font.zip'
    New-Item $workDir, $fontsDir -ItemType Directory -Force | Out-Null
    
    Write-Host "Downloading Nerd Fonts..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    
    if ((Get-FileHash $zipPath -Algorithm SHA256).Hash -ne 'E67A68EE3386DB63F48B9054BD196EA752BC6A4EBB4DF35ADCE6733DA50C8474') {
        throw "Font hash mismatch!"
    }

    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force
    
    # Map filenames to exact Registry names (avoids loading System.Drawing)
    $fontMap = @{ 'CascadiaCodeNF.ttf' = 'Cascadia Code NF (TrueType)'; 'CascadiaMonoNF.ttf' = 'Cascadia Mono NF (TrueType)' }
    foreach ($file in $wanted) {
        $src = Get-ChildItem $workDir -Recurse -Filter $file | Select -First 1
        if ($src) {
            $dest = Join-Path $fontsDir $file
            Copy-Item $src.FullName $dest -Force
            New-ItemProperty -Path $regPath -Name $fontMap[$file] -Value $dest -Type String -Force | Out-Null
        }
    }
    Remove-Item $workDir -Recurse -Force
    Write-Host "Fonts installed. Restart terminal to apply."
}

function Install-TerminalProfile($DistroName) {
    $fragDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\ComfortShell'
    New-Item $fragDir -ItemType Directory -Force | Out-Null
    
    $slug = (($DistroName -replace '[^a-zA-Z0-9]+', '-').Trim('-')).ToLower()
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $guid = "{$([guid]::new($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes("comfort-shell:$DistroName"))).ToString().ToLower())}"
    $sunglasses = [string]::new(@([char]0xD83D, [char]0xDE0E))

    # Use Here-String for JSON instead of nested Hashtables
    $json = @"
{
  "profiles": [{
    "guid": "$guid", "name": "Comfort Shell - $DistroName", "icon": "$sunglasses",
    "commandline": "wsl.exe -d $DistroName", "startingDirectory": "~",
    "colorScheme": "Comfort Shell Dark", "cursorShape": "bar",
    "font": { "face": "Cascadia Mono NF", "size": 13 }
  }],
  "schemes": [{
    "name": "Comfort Shell Dark", "background": "#1E1E2E", "foreground": "#CDD6F4",
    "cursorColor": "#A6E3A1", "selectionBackground": "#45475A",
    "black": "#45475A", "red": "#F38BA8", "green": "#A6E3A1", "yellow": "#F9E2AF",
    "blue": "#89B4FA", "purple": "#CBA6F7", "cyan": "#94E2D5", "white": "#BAC2DE",
    "brightBlack": "#585B70", "brightRed": "#F38BA8", "brightGreen": "#A6E3A1",
    "brightYellow": "#F9E2AF", "brightBlue": "#89B4FA", "brightPurple": "#CBA6F7",
    "brightCyan": "#94E2D5", "brightWhite": "#A6ADC8"
  }]
}
"@
    $fragmentFile = Join-Path $fragDir "comfort-shell-$slug.fragment.json"
    $json | Out-File $fragmentFile -Encoding Utf8

    # Trigger WT hot-reload
    $settingsPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )
    $nudged = $false
    foreach ($p in $settingsPaths) {
        if (Test-Path $p) { try { (Get-Item $p).LastWriteTime = Get-Date; $nudged = $true } catch {} }
    }
    
    Write-Host "`n--- Windows Terminal profile installed ---" -ForegroundColor Cyan
    Write-Host "  Profile: Comfort Shell - $DistroName" -ForegroundColor Green
    if ($nudged) { Write-Host "  Open Windows Terminal to see it." -ForegroundColor Green }
}

# --- Main flow ---
if (-not (Get-Command 'wt.exe' -EA SilentlyContinue)) { throw "Windows Terminal (wt.exe) is required." }
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'ComfortShellResume' -EA SilentlyContinue

Step "Ensuring WSL platform"
if (-not (Get-Command 'wsl.exe' -EA SilentlyContinue) -or (& wsl.exe --status *> $null; $LASTEXITCODE -ne 0)) {
    Install-WslPlatform; return
}

Step "Choosing Ubuntu distro"
$Distro = Resolve-Distro
if (-not $Distro) { return }
$preUser = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\*\DistributionName" -EA SilentlyContinue | ? DistributionName -eq $Distro).DefaultUid

Step "Running bootstrap in $Distro"
Invoke-ComfortShellBootstrap $Distro

Step "Installing Cascadia Code Nerd Fonts"
Install-NerdFont

Step "Installing Windows Terminal profile"
Install-TerminalProfile $Distro

Set-ConsoleTitle "Comfort Shell · ready"
$sun = [string]::new(@([char]0xD83D, [char]0xDE0E))
Write-Host "`n---------------------------------------------------------------" -ForegroundColor Green
Write-Host "  $sun Comfort Shell install complete" -ForegroundColor Green
Write-Host "---------------------------------------------------------------" -ForegroundColor Green
Write-Host "  Open 'Comfort Shell $sun ($Distro)' in Windows Terminal.`n" -ForegroundColor Yellow