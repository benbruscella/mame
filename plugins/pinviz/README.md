# pinviz

A minimal pinball playfield for testing MAME pinball drivers.

The emulated machine is the real thing: the ROM, switch matrix, solenoids,
lamps, displays and sound. This plugin adds the one part MAME does not have,
a ball. It is enough physics to play a game and watch the driver react, not a
simulator: one ball, walls, flippers, slingshots, pop bumpers, drop and
stand-up targets, saucers, lanes, one-way gates and the outhole, drawn over
the playfield panel.

    mame centaur -plugin pinviz

Keys: left and right Shift for the flippers (or whatever the table names),
Space to plunge. The usual MAME keys coin up and start the game.

Environment variables:

- `PINVIZ_AUTOPILOT=1` plays by itself, which turns the plugin into a driver
  regression test.
- `PINVIZ_LOG=1` prints every switch closure and solenoid fire to the console.
- `PINVIZ_FLIPTEST=<speed>` drops balls onto the left flipper at that speed in
  inches per second and reports how many were hit and how many passed through,
  as a check on the flipper collision.

## Where a table comes from

Two sources, so that neither repeats the other.

**The machine's layout says where things are.** A per-game layout marks its
playfield panel with items whose ids are `pinviz:pfx` and `pinviz:pfy`, and each
playfield switch with an item whose id is `pinviz:<port>:<mask>`. A second item
for the same switch gets a `:2` suffix, a third `:3`, and so on. pinviz reads
those positions when the machine starts. The layout is then the single place a
playfield is drawn, and adding the ids to an existing layout is most of the work
of supporting a machine. `src/mame/layout/by35_centaur.lay` and the two by17
layouts are examples.

**The table in `tables/<system>.lua` says what each switch is**, and supplies
what a picture cannot: walls, rails, flippers, physics constants, and which
solenoid serves the ball, kicks the outhole, resets a drop target bank or
releases a saucer. A feature identifies its switch, its kind, and for a segment
an orientation within the layout item (`h`, `v`, `d`, `u`) and a length in
inches. A feature may also carry its own coordinates, for a machine whose layout
has no ids; Playboy does that.

A layout that draws only the playfield leaves no room for the shooter lane, so a
table can set `lay_width` and `lay_length` to say how much of itself the panel
covers. The rest of the table, the lane included, sits outside the picture.

`tables/bally_body.lua` holds the parts every machine on Bally's solid state
cabinet shares: the outline, the shooter lane and its gate, the outlane and
inlane rails, and the flippers. A table for one of those machines takes the
skeleton and adds only its own features.

## Machines

| Table | Layout supplies positions | Notes |
|---|---|---|
| `centaur` | yes | Geometry traced from a playfield photograph. |
| `playboy` | no, coordinates in the table | Its layout has no ids yet. |
| `matahari` | yes | Walls come from the shared Bally body, not the real playfield. |
| `pwerplay` | yes | Same. Plays a full five ball game. |
| `hs_l4` | yes | Williams System 11. Switches and solenoids are from Williams' tech chart; the layout arranges the real features rather than tracing the playfield. |

A machine with a ball trough will not start a game until the trough reads full, so
a table can list its trough switches. pinviz then holds one closed per ball at
home, hands one to the shooter lane when the feeder solenoid fires, and takes one
back when the outhole kicker returns a drained ball. High Speed needs this.

A table can also set `output_prefix`, because not every driver calls its outputs
`solenoid<n>`: System 11 publishes `out0` to `out85`.

High Speed shows FACTORY SETTING on a fresh NVRAM and needs one reset before it
will accept a coin, as the `s11.cpp` header says.

For Mata Hari, Power Play and High Speed only the switch positions are real. The
walls are a generic cabinet, so the ball does not travel the paths it would on
the machine, and play is unevenly distributed: Mata Hari's ball spends most of
its time on the two upper pop bumpers. Tightening those needs a playfield
reference for each, the way Centaur's did.
