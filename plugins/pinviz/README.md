# pinviz

Plays a pinball machine's ROM on a simulated playfield, for testing pinball drivers.

MAME emulates everything in a pinball machine except the ball: the ROM, switch matrix,
solenoids, lamps, displays and sound. This plugin adds the ball, and enough of a
playfield to roll it on: walls, flippers, slingshots, pop bumpers, drop and stand-up
targets, saucers, lanes, one-way gates and the outhole. It closes switches when the ball
reaches them, and watches the solenoids to serve the ball, kick the outhole, reset drop
targets and enable the flippers. The score, the lamps and the coils all come from the
ROM reacting to that.

    mame playboy -plugin pinviz

## Playing

The playfield is drawn as lines over the left of the window, with the ROM's lamps lit
where they are on the machine. The usual MAME keys coin up and start the game. The ROM
ignores coins for about twelve seconds after power on, during its self test.

| Key | Does |
|---|---|
| Left and right Shift | Flippers |
| Space | Hold to pull the plunger back, and let go to launch. The rod at the foot of the shooter lane draws back as it is held, and the gauge beside it shows the strength. |
| PgDn and PgUp | Slow the ball down or speed it up, a tenth at a time, from a tenth of full speed to one and a half times it. The machine runs at full speed throughout. |

Full speed is paced against a real machine: Quench, who knows it well, matched the
ball's pace by eye. `PINVIZ_SPEED=0.6` starts at 60% of it.

A ball held on a raised flipper stays there, ready for the shot. A ball that stops
anywhere else for a while gets a small nudge, as a player would give it. A drained ball
rolls down through the hole at the foot of the apron into the outhole, and the outhole
switch closes as it lands.

Bumpers and slingshots scatter their kicks a little, and a launch the plugin makes by
itself varies in strength, so no two balls play out the same.

## Playfields

`playfields/<system>.lua` describes a machine's playfield in inches, origin top left, y
down towards the flippers. Playboy is the only one so far. It was traced by eye from a
straight-on photograph of a bare playfield with an inch grid over it, with corrections
from Quench, who knows the machine. Wire forms and hardware heights are simplified to the
walls the ball runs against. No artwork is used.

Besides walls, posts and the features with switches, a playfield can give:

- `gates`: one-way gates, each passable from one side only, and `gate_scatter`, how many
  degrees either way a ball's bounce off the blocked side of a gate varies.
- `flipper_rate_up` and `flipper_rate_down`: how fast the bats swing up when the coil
  drives them and back down on the spring, in degrees per second. Coils, springs and
  transformers differ between makers and eras, so the flipper strength belongs to the
  machine. A flipper can also take its own `rate_up` and `rate_down`.
- `outhole`: the hole at the foot of the apron, and the outhole under it.
- `lamps`: where each of the ROM's lamps is, for drawing.
- `closed`: where a ball can never be, under plastics and outside the rails, for the
  drain test.
- `latched` and `releases`: see below.

A playfield can take its feature positions from the machine's layout instead. Items with
ids `pinviz:pfx` and `pinviz:pfy` mark the playfield panel, and an item with the id
`pinviz:<port>:<mask>` marks a switch. The plugin then draws over the layout rather than
beside it.

The plugin changes no driver. Where a driver reads a switch through its own latch and not
an input, as `by35.cpp` does for Playboy's outhole, drop targets and kickback, the
playfield lists it under `latched`, and the plugin works the latch through the driver's
saved state. `releases` names the solenoid that opens a latch if the driver does not.

## Testing

These environment variables turn the plugin into a driver regression test. With any of
them set, the random numbers repeat from run to run, so a result can be reproduced.

- `PINVIZ_AUTOPILOT=1` coins up and plays by itself.
- `PINVIZ_LOG=1` prints every switch closure and solenoid fire to the console.
- `PINVIZ_DRAINTEST=1` leaves the flippers alone, launches at every strength and drops
  balls from everywhere a ball can be, and reports any that stay in play and where they
  were held. The nudge that frees a stuck ball is off, so nothing is hidden.
- `PINVIZ_FLIPTEST=<speed>` drops balls onto the left flipper at that speed in inches per
  second, and reports how many were hit and how they left.
- `PINVIZ_FLIPSPREAD=0` makes that test drop every ball at one point on the bat.
- `PINVIZ_CRADLETEST=1` holds a flipper up, drops a ball onto it, and reports whether it
  settles there and how hard it leaves when flipped.
- `PINVIZ_DUMP=1` prints the playfield's walls and features once at startup.
