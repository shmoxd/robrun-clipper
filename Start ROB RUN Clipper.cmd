@echo off
setlocal
set "BASE=%~dp0"
set "PATH=%BASE%bin;%PATH%"
"%BASE%robrun-clipper\.venv\Scripts\python.exe" "%BASE%robrun-clipper\app.py" "%BASE%robrun-workspace" %*
endlocal
