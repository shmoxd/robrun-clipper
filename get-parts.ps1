<#
.SYNOPSIS
  Downloads a YouTube video and splits it into fixed-length parts.

.EXAMPLE
  .\get-parts.ps1 "https://youtu.be/VIDEO_ID" -Minutes 10

.EXAMPLE
  .\get-parts.ps1 "https://youtu.be/VIDEO_ID" -Minutes 5 -Quality 720 -KeepFull

.NOTES
  By default parts are copied without re-encoding (fast, no quality loss), so cut
  points snap to the nearest keyframe and parts can differ from -Minutes by a few
  seconds. Use -Exact to re-encode and get parts of exactly -Minutes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url,

    # Length of each part, in minutes.
    [int]$Minutes = 10,

    # Maximum resolution: 2160, 1440, 1080, 720, 480...
    [int]$Quality = 1080,

    # Also keep the original full video in .\downloads
    [switch]$KeepFull,

    # Re-encode so every part is exactly -Minutes long (slower, slight quality loss).
    [switch]$Exact
)

$ErrorActionPreference = 'Stop'
$root   = $PSScriptRoot
$env:PATH = "$(Join-Path $root 'bin');$env:PATH"   # lets yt-dlp find deno for YouTube
$ytdlp  = Join-Path $root 'bin\yt-dlp.exe'
$ffmpeg = Join-Path $root 'bin\ffmpeg.exe'
$dl     = Join-Path $root 'downloads'
$parts  = Join-Path $root 'parts'
New-Item -ItemType Directory -Force -Path $dl, $parts | Out-Null

if ($Minutes -lt 1) { throw "-Minutes must be at least 1." }

$format = "bv*[ext=mp4][height<=$Quality]+ba[ext=m4a]/b[ext=mp4][height<=$Quality]/bv*[height<=$Quality]+ba/b[height<=$Quality]/b"

Write-Host "Downloading video (max ${Quality}p)..." -ForegroundColor Cyan
$pathFile = Join-Path $env:TEMP "ytdlp-path-$PID.txt"
Remove-Item -LiteralPath $pathFile -ErrorAction SilentlyContinue

& $ytdlp --no-playlist --no-progress --no-colors --merge-output-format mp4 `
    -f $format -o "$dl\%(id)s.%(ext)s" --print-to-file "after_move:filepath" $pathFile $Url

if ($LASTEXITCODE -ne 0) { throw "yt-dlp failed (exit code $LASTEXITCODE)." }

$file = Get-Content -LiteralPath $pathFile -Encoding UTF8 |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
    Select-Object -Last 1
Remove-Item -LiteralPath $pathFile -ErrorAction SilentlyContinue

if (-not $file) { throw "Download failed: no output file was produced." }

$file = (Resolve-Path -LiteralPath $file).Path
Write-Host "Downloaded: $file" -ForegroundColor Green

$base    = [IO.Path]::GetFileNameWithoutExtension($file)
$seconds = $Minutes * 60

function Format-Time([double]$s) {
    $ts = [TimeSpan]::FromSeconds($s)
    if (($ts.TotalHours -ge 1)) { '{0:h\:mm\:ss}' -f $ts } else { '{0:m\:ss}' -f $ts }
}

$ffprobe = Join-Path $root 'bin\ffprobe.exe'

if ($Exact) {
    Write-Host "Splitting into exact $Minutes-minute parts (re-encoding)..." -ForegroundColor Cyan
    $total = [double](& $ffprobe -v error -show_entries format=duration -of csv=p=0 $file)
    $count = [math]::Ceiling($total / $seconds)
    for ($i = 0; $i -lt $count; $i++) {
        $startSec = $i * $seconds
        $durSec   = [math]::Min($seconds, $total - $startSec)
        $outPart  = Join-Path $parts ('{0}_part{1:D3}.mp4' -f $base, $i)
        & $ffmpeg -hide_banner -loglevel error -y -ss $startSec -i $file -t $durSec `
            -map 0:v:0 -map 0:a:0? -c:v libx264 -preset veryfast -crf 18 -c:a aac -b:a 192k `
            -movflags +faststart $outPart
        if ($LASTEXITCODE -ne 0) { throw "Splitting failed on part $i (ffmpeg exit $LASTEXITCODE)." }
        Write-Progress -Activity 'Splitting' -Status "Part $($i + 1)/$count" -PercentComplete ((($i + 1) / $count) * 100)
    }
    Write-Progress -Activity 'Splitting' -Completed
}
else {
    Write-Host "Splitting into ~$Minutes-minute parts (no re-encode)..." -ForegroundColor Cyan
    & $ffmpeg -hide_banner -loglevel error -y -i $file `
        -map 0:v:0 -map 0:a:0? -c copy -f segment `
        -segment_time $seconds -reset_timestamps 1 -avoid_negative_ts make_zero `
        "$parts\${base}_part%03d.mp4"
    if ($LASTEXITCODE -ne 0) { throw "Splitting failed (ffmpeg exit $LASTEXITCODE)." }
}

if (-not $KeepFull) { Remove-Item -LiteralPath $file -Force }

$created = Get-ChildItem -LiteralPath $parts -Filter "${base}_part*.mp4" | Sort-Object Name

$rows    = @()
$elapsed = 0.0
foreach ($p in $created) {
    $d = & $ffprobe -v error -show_entries format=duration -of csv=p=0 $p.FullName
    $dur = [double]$d
    $rows += [pscustomobject]@{
        Part  = $p.Name
        Start = (Format-Time $elapsed)
        End   = (Format-Time ($elapsed + $dur))
        MB    = [math]::Round($p.Length / 1MB, 1)
    }
    $elapsed += $dur
}

$indexPath = Join-Path $parts "${base}_index.txt"
$rows | ForEach-Object { "{0}  {1} -> {2}  ({3} MB)" -f $_.Part, $_.Start, $_.End, $_.MB } |
    Set-Content -LiteralPath $indexPath -Encoding UTF8

Write-Host ""
Write-Host "$($created.Count) parts ($(Format-Time $elapsed) total) in .\parts :" -ForegroundColor Green
$rows | Format-Table -AutoSize
Write-Host "Times are relative to each part; index saved to $indexPath" -ForegroundColor DarkGray
