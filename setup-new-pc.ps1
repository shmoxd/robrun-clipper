#Requires -Version 5.1
<#
.SYNOPSIS
  Sets up the ROB RUN Clipper on a fresh Windows 10/11 PC.

.DESCRIPTION
  Installs the tools the repo does not store (Git, GitHub CLI, ffmpeg, Python 3.12),
  creates robrun-clipper\.venv, installs requirements.txt, copies the tool binaries
  into bin\, links the OpenCode skill, and checks the Python imports.

  Run it from the repository root, after cloning:

    powershell -ExecutionPolicy Bypass -File .\setup-new-pc.ps1

  Re-running is safe: existing tools, venv and links are kept.
#>
[CmdletBinding()]
param(
    # Skip the winget installs (use when Git/ffmpeg/Python are managed another way).
    [switch]$SkipSystemPackages,

    # Do not create the %USERPROFILE%\.config\opencode\skills junction.
    [switch]$SkipSkillLink
)

$ErrorActionPreference = 'Stop'
$root  = $PSScriptRoot
$skill = Join-Path $root 'robrun-clipper'
$venv  = Join-Path $skill '.venv'
$venvPython = Join-Path $venv 'Scripts\python.exe'
$bin   = Join-Path $root 'bin'

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Have([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user, $env:Path) | Where-Object { $_ }) -join ';'
}

if (-not (Test-Path (Join-Path $skill 'app.py'))) {
    throw "Run this script from the repository root (robrun-clipper\app.py not found)."
}

if (-not $SkipSystemPackages) {
    if (-not (Have 'winget')) {
        throw 'winget not found. Install "App Installer" from the Microsoft Store, then rerun.'
    }

    $packages = @(
        @{ Id = 'Git.Git';              Cmd = 'git'    },
        @{ Id = 'GitHub.cli';           Cmd = 'gh'     },
        @{ Id = 'Gyan.FFmpeg';          Cmd = 'ffmpeg' },
        @{ Id = 'Python.Python.3.12';   Cmd = 'python' }
    )

    foreach ($p in $packages) {
        Refresh-Path
        if (Have $p.Cmd) {
            Write-Step "$($p.Id) is already installed"
            continue
        }
        Write-Step "Installing $($p.Id)"
        winget install --id $p.Id -e --source winget --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "winget returned $LASTEXITCODE for $($p.Id). Continue if it is actually installed."
        }
    }
    Refresh-Path
}

if (-not (Test-Path $venvPython)) {
    Write-Step 'Creating the Python 3.12 virtual environment'
    $made = $false
    if (Have 'py') {
        & py -3.12 -m venv $venv
        $made = ($LASTEXITCODE -eq 0) -and (Test-Path $venvPython)
    }
    if (-not $made) {
        $python = (Get-Command python -ErrorAction SilentlyContinue).Source
        if (-not $python) { throw 'Python 3.12 not found. Install Python.Python.3.12, open a new terminal, and rerun.' }
        & $python -m venv $venv
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $venvPython)) { throw 'Could not create robrun-clipper\.venv.' }
    }
}

Write-Step 'Installing the Python requirements (several minutes)'
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r (Join-Path $skill 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'pip install failed. Read the error above, then rerun.' }

Write-Step 'Copying ffmpeg/ffprobe/yt-dlp/deno into bin\'
New-Item -ItemType Directory -Force -Path $bin | Out-Null
foreach ($tool in 'ffmpeg', 'ffprobe') {
    $cmd = Get-Command "$tool.exe" -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command $tool -ErrorAction SilentlyContinue }
    if ($cmd) {
        Copy-Item -LiteralPath $cmd.Source -Destination (Join-Path $bin "$tool.exe") -Force
    } else {
        Write-Warning "$tool not found on PATH. Install Gyan.FFmpeg, open a new terminal and rerun."
    }
}
foreach ($tool in 'yt-dlp', 'deno') {
    $src = Join-Path $venv "Scripts\$tool.exe"
    if (Test-Path $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $bin "$tool.exe") -Force
    } else {
        Write-Warning "$tool.exe not found in .venv\Scripts (yt-dlp[default,deno] should provide it)."
    }
}

if (-not $SkipSkillLink) {
    Write-Step 'Linking the OpenCode skill'
    $link = Join-Path $env:USERPROFILE '.config\opencode\skills\robrun-clipper'
    New-Item -ItemType Directory -Force -Path (Split-Path $link) | Out-Null
    if (Test-Path $link) {
        Write-Host "Already exists: $link"
    } else {
        New-Item -ItemType Junction -Path $link -Target $skill | Out-Null
        Write-Host "Linked: $link -> $skill"
    }
}

Write-Step 'Checking the Python imports'
& $venvPython -c "import faster_whisper, av, cv2, mediapipe, numpy, streamlink, PIL, yt_dlp; print('Python dependencies OK')"
if ($LASTEXITCODE -ne 0) { throw 'The import check failed. Read the error above.' }

Write-Step 'Checking the tool binaries'
foreach ($tool in 'ffmpeg', 'ffprobe', 'yt-dlp', 'deno') {
    $exe = Join-Path $bin "$tool.exe"
    if (-not (Test-Path $exe)) { throw "$tool.exe is missing from bin\." }
}

Write-Host @"

Done. Next steps:
  1. Install OpenCode desktop (same app as on the other PC) and sign in.
  2. Open this folder in OpenCode, or double-click "Start ROB RUN Clipper.cmd".
  3. The app opens at http://localhost:8765 with the workspace in robrun-workspace\.
"@ -ForegroundColor Green
