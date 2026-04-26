# oretime

An [Ashita v4](https://ashitaxi.com/) addon for Final Fantasy XI that watches the Vana'diel moon and tells you when the phase is right for digging elemental ore.

## What it does

Elemental ore digs are gated by moon percent. `oretime` reads the in-game Vana'diel timestamp from `FFXiMain.dll`, computes the current moon percent, and reports whether you're inside the dig window (**7%–21%**).

The addon:

- Checks moon state on login / zone-in (packet `0x000A`).
- Polls every frame and re-checks when the Vana'diel day rolls over.
- Reports either `Time to dig for ore!` with days/real-hours remaining, or how many days/real-hours until the window opens.

One Vana'diel day ≈ 57.6 real minutes, so estimates are converted to real-world time for convenience.

## Installation

1. Drop the `oretime/` folder into `<Ashita>/addons/`.
2. In-game: `/addon load oretime`.

## Commands

| Command | Description |
| --- | --- |
| `/oretime` | Show current moon percent and dig-window status. |
| `/oretime check` | Same as above (explicit form). |

## Notes

- Moon range constants live at the top of `oretime.lua` (`MOON_MIN = 7`, `MOON_MAX = 21`) — adjust if you want a different window.
- Moon formula: `((42 - ((days + 26) % 84)) * 100) / 42`, absolute value, rounded.
- The memory pointer for the Vana'diel timestamp is resolved once via `ashita.memory.find` and cached.
