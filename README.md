# ROB RUN Clipper

A local adaptation of the free [NoCodeHack gta6-clipper](https://gitlab.com/nocodehack.io/gta6-clipper) for **ROB RUN** (Kefir's crime sandbox MMO).

It is the same pipeline — download/record → transcribe → score loud/chat/keyword moments → render 9:16 Shorts with captions and a hook — with the discovery, prompts, hashtags and vocabulary switched from GTA 6 to ROB RUN.

## Quick start

Double-click **`Start ROB RUN Clipper.cmd`**.

It opens the local app at http://localhost:8765 with the workspace in `robrun-workspace\`.

From the app you can:

- click **Newest ROB RUN** to fetch fresh videos and make Shorts,
- paste any YouTube / Twitch / Kick link,
- add streamers and tick **Watch live** to clip chat spikes automatically,
- review, edit, approve or reject each Short.

Nothing is posted unless you connect Blotato and confirm it.

## Install on another PC

The Git repo has the code, fonts, sounds and models. The Python venv and the ~300 MB tool binaries are not committed; the setup script installs or copies them.

Clone the private repo (sign in to GitHub first), then run the setup:

```powershell
git clone https://github.com/shmoxd/robrun-clipper.git
cd robrun-clipper
powershell -ExecutionPolicy Bypass -File .\setup-new-pc.ps1
```

The script uses winget to install Git, GitHub CLI, ffmpeg and Python 3.12 when they are missing, creates `robrun-clipper\.venv`, installs `requirements.txt`, copies `ffmpeg.exe`, `ffprobe.exe`, `yt-dlp.exe` and `deno.exe` into `bin\`, and links the skill into `%USERPROFILE%\.config\opencode\skills\robrun-clipper`. Re-running it is safe.

Manual equivalent:

| Step | Command |
|---|---|
| Tools | `winget install Git.Git GitHub.cli Gyan.FFmpeg Python.Python.3.12` |
| Venv | `py -3.12 -m venv robrun-clipper\.venv` |
| Libraries | `.\robrun-clipper\.venv\Scripts\python.exe -m pip install -r .\robrun-clipper\requirements.txt` |
| Binaries | copy `ffmpeg.exe` + `ffprobe.exe` from PATH and `yt-dlp.exe` + `deno.exe` from `.venv\Scripts` into `bin\` |
| Skill | `New-Item -ItemType Junction -Path "$env:USERPROFILE\.config\opencode\skills\robrun-clipper" -Target (Resolve-Path .\robrun-clipper)` |

Then install OpenCode desktop, sign in, and double-click **`Start ROB RUN Clipper.cmd`**. Open a new terminal after the winget installs so PATH is fresh.

A GPU is optional. On a PC with an NVIDIA card install `requirements-gpu.txt` for faster transcription; without one, Whisper falls back to CPU `base`. On the old i5 test PC a 14-minute video took about 9 minutes to transcribe.

## Command line

Run from any folder (results go to `clips\` there):

```powershell
# download + transcribe the newest ROB RUN videos
.\robrun-clipper\.venv\Scripts\python.exe .\robrun-clipper\watch.py "ROB ?RUN" 5

# score the best windows
.\robrun-clipper\.venv\Scripts\python.exe .\robrun-clipper\nopick.py clips --candidates 30

# render picks.json
.\robrun-clipper\.venv\Scripts\python.exe .\robrun-clipper\batch.py clips\picks.json clips\out
```

The simplest route is to ask the AI in this project: **"make 10 ROB RUN Shorts from the newest videos"**. The `robrun-clipper` skill is linked into `~/.config/opencode/skills/`, so OpenCode can find it from any folder.

The app's AI is **OpenCode** (settings in `%USERPROFILE%\.clipper\blotato.env`): `AI=opencode` and, by default, OpenCode's `opencode/big-pickle` model (free, no account). To use another OpenCode model, add `AI_OPENCODE_MODEL=provider/model` to that file (for example `opencode/deepseek-v4.1-flash-free`). Claude Code is not installed and not required.

### Ask OpenCode from this chat

You do not need the app to make Shorts. In this chat, just say:

- `make 10 ROB RUN Shorts from the newest videos`
- `make Shorts from https://www.youtube.com/watch?v=...`
- `clip TFUE live` or `clip the ROB RUN Twitch category live`
- `open the clipper app`

This chat's agent loads the `robrun-clipper` skill and runs the same pipeline. The app is only the control room (review, edit, approve, schedule).

## ROB RUN tuning

- **Search terms:** `ROB RUN`, `ROB RUN gameplay`, `ROB RUN heist`, `ROB RUN funny moments`, `ROB RUN police chase`.
- **Twitch category:** `ROB RUN`.
- **Streamers:** top channels seen on 19 Nov 2026 (TFUE, aceu, rakanoolive, olofmeister, waolol1, twiks…). Edit them in the app.
- **Whisper vocabulary:** Kefir, Looty Bay, Lenny, Notoriety, B-Coins, Black Market, Shadow Governor, wipe day, raid, bribe…
- **Hashtags:** `#robrun #robrungame #shorts`.
- **Moment rules:** heists, cop chases/arrests, betrayals, base raids, wipe-day chaos, scams, clan fights. Skip menus, maps, inventory and crafting talk.

## What changed from upstream

- `SKILL.md`, `channels.txt`, `streamers.json`, prompts and defaults are ROB RUN-specific.
- `app.py` / `app.html` say ROB RUN and search `ROB ?RUN`.
- `live.py` uses the `ROB RUN` Twitch category (no GTA fallback).
- `transcribe.py` has a ROB RUN vocabulary.
- Hashtags and titles default to `#robrun #robrungame #shorts`.
- Self-updates are disabled so an upstream GTA update cannot overwrite these changes.
- `vision.py`'s GTA V wanted-star detector is left off by default (it was already off upstream).

The `.venv` is local to `robrun-clipper\`; `bin\ffmpeg.exe`, `ffprobe.exe`, `yt-dlp.exe` and `deno.exe` are the binaries already in this project.

## Notes

- Python 3.12, ffmpeg and the Python requirements are installed. If you move the folder, recreate the venv and re-add `bin` to PATH.
- This PC's CPU is an older i5, so local Whisper transcription is slow (tens of minutes per long video). For faster, rougher captions set `CLIPPER_WHISPER=tiny` before a CLI run (default on CPU is `base`); leave it unset for better accuracy.
- Clips belong to their creators. The app ships clip-rule checks; credit streamers and respect their rules.
- Upstream project: MIT license, by NoCodeHack. This adaptation is unofficial and not affiliated with Kefir.
