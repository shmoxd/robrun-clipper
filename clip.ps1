<#
.SYNOPSIS
  Cuts a clip from a video (or from one of the parts). Times accept SS, MM:SS or HH:MM:SS.

.EXAMPLE
  .\clip.ps1 "parts\abc_part000.mp4" 1:23 2:45

.EXAMPLE
  .\clip.ps1 "downloads\abc.mp4" 0:10 0:35 -Out "clips\best-moment.mp4"

.EXAMPLE
  .\clip.ps1 "parts\abc_part003.mp4" 0:05 0:20 -Fast

.NOTES
  By default the clip is re-encoded for frame-accurate cuts. -Fast copies the
  streams instead (instant, no quality loss) but the cut snaps to the nearest
  keyframe, so the clip may start/end a few seconds off.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Start,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$End,

    # Output file. Defaults to .\clips\<name>_<start>-<end>.mp4
    [string]$Out,

    # Stream copy instead of re-encoding: much faster, but keyframe-aligned.
    [switch]$Fast
)

$ErrorActionPreference = 'Stop'
$root   = $PSScriptRoot
$ffmpeg = Join-Path $root 'bin\ffmpeg.exe'

function ConvertTo-Seconds([string]$t) {
    $p = $t.Trim().Split(':') | ForEach-Object { [double]$_ }
    switch ($p.Count) {
        1 { $p[0] }
        2 { $p[0] * 60 + $p[1] }
        3 { $p[0] * 3600 + $p[1] * 60 + $p[2] }
        default { throw "Invalid time '$t' (use SS, MM:SS or HH:MM:SS)." }
    }
}

$s = ConvertTo-Seconds $Start
$e = ConvertTo-Seconds $End
if ($e -le $s) { throw "End ($End) must be after start ($Start)." }
$duration = $e - $s

if (-not (Test-Path -LiteralPath $InputFile)) { throw "File not found: $InputFile" }

if (-not $Out) {
    $clips = Join-Path $root 'clips'
    New-Item -ItemType Directory -Force -Path $clips | Out-Null
    $stamp = ($Start -replace '[:.]', '-') + '_' + ($End -replace '[:.]', '-')
    $Out = Join-Path $clips ("{0}_{1}.mp4" -f [IO.Path]::GetFileNameWithoutExtension($InputFile), $stamp)
}
$outDir = Split-Path -Parent $Out
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

if ($Fast) {
    Write-Host "Cutting clip (fast copy, keyframe-aligned)..." -ForegroundColor Cyan
    # Output-side seek keeps the cut as close as possible with stream copy.
    & $ffmpeg -hide_banner -loglevel error -y -i $InputFile -ss $s -t $duration `
        -map 0:v:0 -map 0:a:0? -c copy -avoid_negative_ts make_zero `
        -movflags +faststart $Out
}
else {
    Write-Host "Cutting clip (re-encoding for exact cut)..." -ForegroundColor Cyan
    & $ffmpeg -hide_banner -loglevel error -y -ss $s -i $InputFile -t $duration `
        -map 0:v:0 -map 0:a:0? -c:v libx264 -preset veryfast -crf 18 `
        -c:a aac -b:a 192k -movflags +faststart $Out
}

if ($LASTEXITCODE -ne 0) { throw "Cutting failed (ffmpeg exit $LASTEXITCODE)." }

Write-Host "Clip created: $Out" -ForegroundColor Green
