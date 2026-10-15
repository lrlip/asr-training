<#
.SYNOPSIS
  reset.ps1 - give this laptop a fresh copy of one or every session of the AI Orchestrator training
  and set it up, on Windows.

.DESCRIPTION
  1. Asks which sessions to reset, which is also the confirmation; -Session skips the question and
     -Force the confirmation
  2. Stops every running Node.js and Bun process, also when only one session is reset, so they
     release the session folders
  3. Per session: removes the existing folder, clones the repository again from GitHub and runs its
     setup.ps1

  The sessions go on the desktop, next to this launcher, or in C:\training when the desktop cannot
  be written to. Never inside this launcher: the session setups refuse to run inside another git
  repository. -TrainingFolder picks another folder. Works in Windows PowerShell 5.1 and
  PowerShell 7. Deliberately pure ASCII, so 5.1 parses it without a BOM. reset.cmd next to this
  file starts it with the execution policy bypassed.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\reset.ps1
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\reset.ps1 -Session 2
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\reset.ps1 -TrainingFolder D:\training -Force
#>
[CmdletBinding()]
param(
    [string]$TrainingFolder = '',
    # Session numbers or names, such as 1, asr-session-2 or "1,2". Empty asks, or with -Force takes all.
    [string[]]$Session = @(),
    [switch]$Force
)

# No global $ErrorActionPreference = 'Stop': Windows PowerShell 5.1 turns the progress a native
# command writes to stderr into a terminating error under Stop. Every native call checks
# $LASTEXITCODE instead.

$script:Sessions = @(
    @{ Name = 'asr-session-1'; Repository = 'https://github.com/AlexDM0/asr-session-1.git' },
    @{ Name = 'asr-session-2'; Repository = 'https://github.com/AlexDM0/asr-session-2.git' }
)
$script:ProcessesToStop = @('node', 'bun')
$script:ShortcutName = 'Reset ASR training'
$script:FallbackTrainingFolder = 'C:\training'
# AppLocker and WDAC run scripts from a user folder in ConstrainedLanguage, where .NET calls fail.
$script:IsFullLanguage = ($ExecutionContext.SessionState.LanguageMode -eq 'FullLanguage')
$script:ResetExitCode = 0

# --- Output helpers ----------------------------------------------------------
# ASCII markers: the console font of Windows PowerShell 5.1 has no check mark glyph.
function Write-Bold($message) { Write-Host $message -ForegroundColor White }
function Write-Step($message) { Write-Host ''; Write-Host $message -ForegroundColor White }
function Write-Info($message) { Write-Host "- $message" -ForegroundColor Cyan }
function Write-Ok($message)   { Write-Host "+ $message" -ForegroundColor Green }
function Write-Warn($message) { Write-Host "! $message" -ForegroundColor Yellow }
function Write-ErrorMessage($message) { Write-Host "x $message" -ForegroundColor Red }

# --- Helpers -----------------------------------------------------------------
function Test-CommandExists($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# git only reads HTTPS_PROXY, not the Windows proxy settings, so copy those over. The session
# setups inherit it.
function Initialize-SystemProxy {
    if (-not $script:IsFullLanguage) { return }
    try {
        [Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials
        if ($env:HTTPS_PROXY -or $env:https_proxy) { return }
        $probeAddress = [uri]'https://github.com'
        $proxyAddress = [Net.WebRequest]::GetSystemWebProxy().GetProxy($probeAddress)
        if ($proxyAddress -and $proxyAddress.Host -ne $probeAddress.Host) {
            $env:HTTPS_PROXY = $proxyAddress.AbsoluteUri
            $env:HTTP_PROXY = $proxyAddress.AbsoluteUri
            Write-Info "Using the Windows proxy $($proxyAddress.AbsoluteUri)."
        }
    } catch { }
}

# The desktop Explorer shows, which OneDrive or a company policy may have moved away from
# %USERPROFILE%\Desktop. GetFolderPath is a .NET call, so locked-down PowerShell falls back.
function Get-DesktopFolder {
    $desktopFolder = $null
    if ($script:IsFullLanguage) {
        try { $desktopFolder = [Environment]::GetFolderPath('Desktop') } catch { }
    }
    if (-not $desktopFolder) { $desktopFolder = Join-Path $env:USERPROFILE 'Desktop' }
    return $desktopFolder
}

# Whether a file can be created in $folder, which also creates $folder when it is missing.
function Test-FolderIsWritable($folder) {
    if (-not $folder) { return $false }
    New-Item -ItemType Directory -Path $folder -Force -ErrorAction SilentlyContinue | Out-Null
    $probeFile = Join-Path $folder 'reset-write-test.tmp'
    New-Item -ItemType File -Path $probeFile -Force -ErrorAction SilentlyContinue | Out-Null
    if (-not (Test-Path -LiteralPath $probeFile)) { return $false }
    Remove-Item -LiteralPath $probeFile -Force -ErrorAction SilentlyContinue
    return $true
}

# -TrainingFolder when given, else the desktop, else C:\training. Returns $null when none works.
function Resolve-TrainingFolder {
    if ($script:TrainingFolder) {
        if (Test-FolderIsWritable $script:TrainingFolder) { return $script:TrainingFolder }
        Write-ErrorMessage "Cannot write to $script:TrainingFolder."
        return $null
    }
    $desktopFolder = Get-DesktopFolder
    if (Test-FolderIsWritable $desktopFolder) { return $desktopFolder }
    Write-Warn "Cannot write to the desktop ($desktopFolder); using $script:FallbackTrainingFolder instead."
    if (Test-FolderIsWritable $script:FallbackTrainingFolder) { return $script:FallbackTrainingFolder }
    Write-ErrorMessage "Cannot write to $script:FallbackTrainingFolder either."
    return $null
}

# A double-click on the desktop is the reset button. Only creates the shortcut when it is missing.
function Install-DesktopShortcut {
    if (-not $script:IsFullLanguage) { return }
    try {
        $desktopFolder = Get-DesktopFolder
        $shortcutPath = Join-Path $desktopFolder "$script:ShortcutName.lnk"
        if (Test-Path -LiteralPath $shortcutPath) { return }
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Join-Path $PSScriptRoot 'reset.cmd'
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.Description = 'Removes the training sessions, clones them again and sets them up'
        $shortcut.Save()
        Write-Ok "Added the shortcut `"$script:ShortcutName`" to the desktop."
    } catch {
        Write-Warn "Could not add a desktop shortcut: $($_.Exception.Message)"
    }
}

function Stop-TrainingProcesses {
    $runningProcesses = @(Get-Process -Name $script:ProcessesToStop -ErrorAction SilentlyContinue)
    if ($runningProcesses.Count -eq 0) {
        Write-Ok 'No Node.js or Bun processes are running.'
        return
    }
    Write-Info "Stopping $($runningProcesses.Count) Node.js and Bun process(es)..."
    $runningProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Ok 'Stopped the running Node.js and Bun processes.'
}

# Turns -Session values like 1, asr-session-2 or "1,2" into sessions. Returns $null for an unknown one.
function Get-SessionsFromNames($sessionNames) {
    $selectedSessions = @()
    foreach ($sessionName in @($sessionNames | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })) {
        $matchingSession = $script:Sessions | Where-Object { $_.Name -ieq $sessionName -or $_.Name -ieq "asr-session-$sessionName" }
        if (-not $matchingSession) {
            Write-ErrorMessage "There is no session $sessionName. Choose from: $(($script:Sessions | ForEach-Object { $_.Name }) -join ', ')."
            return $null
        }
        if ($selectedSessions -notcontains $matchingSession) { $selectedSessions += $matchingSession }
    }
    return ,$selectedSessions
}

# Asks which sessions to reset; the answer is also the confirmation. Returns no sessions on Enter.
function Read-SessionChoice {
    Write-Host ''
    Write-Bold 'Which session do you want to reset? This deletes all work in it.'
    for ($sessionIndex = 0; $sessionIndex -lt $script:Sessions.Count; $sessionIndex++) {
        $sessionFolder = Join-Path $script:TrainingFolder $script:Sessions[$sessionIndex].Name
        Write-Host "  $($sessionIndex + 1)  $sessionFolder"
    }
    Write-Host '  A  all of them'
    while ($true) {
        $answer = (Read-Host 'Type 1, 2 or A and press Enter (only Enter: stop)').Trim()
        if (-not $answer) { return ,@() }
        if ($answer -ieq 'A') { return ,@($script:Sessions) }
        $chosenSessions = Get-SessionsFromNames @($answer)
        if ($chosenSessions) { return ,$chosenSessions }
    }
}

# Remove-Item in Windows PowerShell 5.1 fails on paths past 260 characters, which node_modules
# reaches; rmdir with the \\?\ prefix does not. Returns whether the folder is gone.
function Remove-SessionFolder($sessionFolder) {
    Remove-Item -LiteralPath $sessionFolder -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $sessionFolder) {
        & cmd.exe /d /c "rmdir /s /q `"\\?\$sessionFolder`"" 2>$null
    }
    return (-not (Test-Path -LiteralPath $sessionFolder))
}

# Returns whether the session was cloned and set up.
function Reset-Session($session) {
    $sessionFolder = Join-Path $script:TrainingFolder $session.Name
    Write-Step $session.Name

    if (Test-Path -LiteralPath $sessionFolder) {
        Write-Info "Removing $sessionFolder..."
        if (-not (Remove-SessionFolder $sessionFolder)) {
            Write-ErrorMessage "Could not remove $sessionFolder. Close VS Code, terminals and Explorer windows in that folder, then press the reset button again."
            return $false
        }
        Write-Ok "Removed $sessionFolder."
    }

    Write-Info "Cloning $($session.Repository)..."
    $global:LASTEXITCODE = 1
    & git clone --quiet $session.Repository $sessionFolder
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Cloning $($session.Name) failed. Check your internet connection (or HTTPS_PROXY behind a proxy) and press the reset button again."
        return $false
    }
    Write-Ok "Cloned $($session.Name) into $sessionFolder."

    $setupScript = Join-Path $sessionFolder 'setup.ps1'
    if (-not (Test-Path -LiteralPath $setupScript)) {
        Write-ErrorMessage "$($session.Name) has no setup.ps1."
        return $false
    }
    Write-Info "Running the setup of $($session.Name)..."
    $global:LASTEXITCODE = 1
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setupScript
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "The setup of $($session.Name) did not finish. Read its messages above."
        return $false
    }
    Write-Ok "$($session.Name) is set up in $sessionFolder."
    return $true
}

function Invoke-Reset {
    $resolvedFolder = Resolve-TrainingFolder
    if (-not $resolvedFolder) {
        Write-Info 'Pick a folder you can write to with -TrainingFolder, for example D:\training.'
        $script:ResetExitCode = 1; return
    }
    $script:TrainingFolder = $resolvedFolder

    # --- 1. Choice and confirmation ---------------------------------------------
    if ($Session.Count -gt 0) {
        $selectedSessions = Get-SessionsFromNames $Session
        if (-not $selectedSessions) { $script:ResetExitCode = 1; return }
    } elseif ($Force) {
        $selectedSessions = @($script:Sessions)
    } else {
        $selectedSessions = Read-SessionChoice
    }
    if ($selectedSessions.Count -eq 0) {
        Write-Info 'Nothing was changed.'
        return
    }
    $sessionNames = ($selectedSessions | ForEach-Object { $_.Name }) -join ' and '
    if ($Session.Count -gt 0 -and -not $Force) {
        Write-Host ''
        Write-Warn "This deletes $sessionNames in $script:TrainingFolder, with all work in them."
        $answer = Read-Host 'Type Y and press Enter to continue'
        if ($answer -notmatch '^\s*[yY]') {
            Write-Info 'Nothing was changed.'
            return
        }
    }
    Write-Bold "Resetting $sessionNames in $script:TrainingFolder"

    # --- 2. Checks and processes -----------------------------------------------
    Write-Step 'Checks'
    if (-not (Test-CommandExists 'git')) {
        Write-ErrorMessage 'git was not found. Install it from https://git-scm.com and press the reset button again.'
        $script:ResetExitCode = 1; return
    }
    Write-Ok "$(& git --version) works."
    Initialize-SystemProxy
    Install-DesktopShortcut
    Stop-TrainingProcesses

    # --- 3. Sessions -----------------------------------------------------------
    # Every session gets its turn, so one failing session does not block the other.
    $failedSessions = @()
    foreach ($selectedSession in $selectedSessions) {
        if (-not (Reset-Session $selectedSession)) { $failedSessions += $selectedSession.Name }
    }

    Write-Host ''
    if ($failedSessions.Count -gt 0) {
        Write-ErrorMessage "Not ready: $($failedSessions -join ', '). Read the messages above."
        $script:ResetExitCode = 1
    } else {
        Write-Ok "Ready in $($script:TrainingFolder): $sessionNames."
    }
}

if ($PSScriptRoot) {
    try {
        Invoke-Reset
    } catch {
        Write-ErrorMessage "Reset stopped unexpectedly: $($_.Exception.Message)"
        $script:ResetExitCode = 1
    }
} else {
    Write-ErrorMessage 'Run this script as a file: double-click reset.cmd.'
    $script:ResetExitCode = 1
}

# Only exit when run as a script: exit in a dot-sourced file would close the caller's shell.
if ($MyInvocation.InvocationName -ne '.') { exit $script:ResetExitCode }
