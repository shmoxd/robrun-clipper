@echo off
setlocal
set "OC="
for /f "delims=" %%D in ('dir /b /ad /o-n "%APPDATA%\ai.opencode.desktop\cli" 2^>nul') do if not defined OC set "OC=%APPDATA%\ai.opencode.desktop\cli\%%D\opencode-cli.exe"
if not defined OC (
  echo OpenCode CLI not found under %APPDATA%\ai.opencode.desktop\cli 1>&2
  exit /b 1
)
"%OC%" %*
