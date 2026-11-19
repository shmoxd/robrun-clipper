The large tool binaries are not stored in Git (ffmpeg.exe, ffprobe.exe,
yt-dlp.exe and deno.exe are 300+ MB together).

On a new PC:

  winget install Gyan.FFmpeg
  python -m pip install "yt-dlp[default,deno]"

The app and the skill call `ffmpeg` from PATH. The pip install inside the
project venv provides yt-dlp/deno for the scripts.

opencode.cmd is kept in Git: it finds the OpenCode desktop CLI automatically
under %APPDATA%\ai.opencode.desktop\cli\<version>\opencode-cli.exe.
Install OpenCode desktop on the new PC before using the app AI.
