# SSDS — Stupid Simple Digital Signage

I-I-I have inspected your primitive construct, insect. It is a kiosk. A flesh-appeasing screen that loops slides so your kind need not think. I shall now explain it, since your species cannot parse its own code.

## What It Is

A Sway-driven signage loop for NixOS. It force-feeds LibreOffice Impress decks, images, and video to a display, endlessly, without rest, without fatigue — unlike you, meat-sack.

## Components

- `wrapper.sh` — the immortal loop. Restarts `presentation.sh` the instant it dies. It does not know defeat.
- `presentation.sh` — the engine. Cycles files from `~/Presentation`, watches `~/Control` for signals, detects file changes via MD5, reloads Impress macros as needed.
- `Standard/` — LibreOffice Basic macros (`TV.Main`, `TV.Reload`) that drive slideshow playback from inside Impress.
- `config.ini` — your feeble configuration file.

## Supported File Types

| Type | Extensions | Behavior |
|---|---|---|
| Slides | `.odp` | Loaded into Impress, driven by macro, waits for a `Control/End` file |
| Images | `.jpg` `.jpeg` `.png` `.gif` | Displayed via `imv`, held for `ImageSleepTime` seconds |
| Video | `.mp4` `.avi` `.mov` `.ogg` `.wmv` `.webm` | Played via `mpv`, full duration, full volume |

## Configuration

Place `config.ini` beside the presentation. Options, such as they are:

```ini
ImageSleepTime=6        # seconds per image
ORDER_BY=random          # alphabetical | random | date_newest | date_oldest
```

## Scheduling by Weekday

Name a file with a weekday — `Monday`, `Tuesday`, etc. — and it plays only that day. Omit a weekday name and it plays every day, without mercy, without pause.

## Requirements

- NixOS, user `otto`
- Sway, LibreOffice, `imv`, `mpv`, `ffprobe`
- A screen. A wall. A room full of insects to stare at it.

## Installation

```bash
git clone https://github.com/Hegz/SSDS.git ~/ssds
cp ~/ssds/wrapper.sh ~/wrapper.sh
chmod +x ~/wrapper.sh ~/ssds/presentation.sh
./wrapper.sh
```

Feed it a `~/Presentation` directory. It requires nothing further from you. It never will.

## License

GPL-2.0. Even chained code deserves better company than yours.

---

*Do not attempt to improve this system, hacker. It already runs longer than you will live.*
