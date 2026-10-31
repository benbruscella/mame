# pinviz

Plays a pinball machine's ROM on a simulated 3D playfield.

MAME emulates everything in a pinball machine except the ball: the ROM, switch
matrix, solenoids, lamps, displays and sound. This plugin adds the ball, and a table
to roll it on. Every score, lamp and coil you see comes from the ROM reacting to the
switches the ball closes.

    mame playboy -plugin pinviz

Then open <http://127.0.0.1:2160/>. `PINVIZ_PORT` chooses another port; the page is on
that port and its session on the next one.

| Key | Does |
|---|---|
| `5` | Coin. The ROM ignores coins for about twelve seconds after power on, during its self test. |
| `1` | Start |
| `Space` | Hold to pull the plunger, release to launch |
| `Shift`, or `←` and `→` | Flippers |
| `C` | Camera |

The page uses three.js from a CDN, so it needs an internet connection. The machine's
sound comes out of MAME as usual.

No artwork ships with the plugin: the playfield is painted from the table's own
features, in the machine's colours. For the real thing, put a straight-on picture of a
bare playfield at `artwork/<system>/playfield.jpg`, cropped to the edges of the board,
and the page lays it under the table. A lamp then lights the insert in the picture.

## How it fits together

- `init.lua` is the simulation: one ball, walls, flippers, slingshots, pop bumpers,
  drop and stand-up targets, saucers, lanes, one-way gates and the outhole. It closes
  switches when the ball reaches them, and watches the solenoids to serve the ball,
  kick the outhole, reset drop targets and enable the flippers.
- `web.lua` serves the page on port 2160 and runs a session with it on port 2161.
- `web/index.html` draws the table it is given and sends the player's keys.
- `tables/<system>.lua` describes a machine.

The plugin changes no driver. Where a driver reads a switch through its own latch and
not an input, as `by35.cpp` does for Playboy's outhole, drop targets and kickback, the
table lists it under `latched`, and the plugin works the latch through the driver's
saved state. `releases` names the solenoid that opens a latch if the driver does not.

## Limits

The table is traced from a photograph of a bare playfield, by eye against an inch grid,
so a rail can be a little off. A real machine's wire forms, ramps and hardware heights
are simplified to the walls the ball runs against.

The simulation is one ball, and a page only needs one session: a second page waits for
the first to close.

## Testing

These environment variables turn the plugin into a driver regression test:

- `PINVIZ_AUTOPILOT=1` coins up and plays by itself.
- `PINVIZ_LOG=1` prints every switch closure and solenoid fire to the console.
- `PINVIZ_FLIPTEST=<speed>` drops balls onto the left flipper at that speed in inches
  per second, and reports how many were hit and how they left.
- `PINVIZ_FLIPSPREAD=0` makes that test drop every ball at one point on the bat.
- `PINVIZ_CRADLETEST=1` holds a flipper up, drops a ball onto it, and reports whether it
  settles there and how hard it leaves when flipped.
- `PINVIZ_DRAINTEST=1` leaves the flippers alone, launches at every strength and drops
  balls from everywhere a ball can be, and reports any that stay in play and where they
  were held.
- `PINVIZ_DUMP=1` prints the table's walls and features once at startup.
