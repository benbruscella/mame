# pinviz

A minimal pinball playfield for testing MAME pinball drivers.

The emulated machine is the real thing: the ROM, switch matrix, solenoids,
lamps, displays and sound. This plugin adds the one part MAME does not have,
a ball. It is enough physics to play a game and watch the driver react, not a
simulator: one ball, walls, flippers, slingshots, pop bumpers, drop and
stand-up targets, saucers, lanes and the outhole, drawn as lines over the left
part of the window.

A table definition in `tables/<system>.lua` says which input port field each
feature closes and how it behaves. Where things are can come from the machine's
own layout: a per-game layout (see `src/mame/layout/by35_centaur.lay`) marks
the playfield panel with items whose ids are `pinviz:pfx` and `pinviz:pfy`, and
each switch with an item whose id is `pinviz:<port>:<mask>` (a second item for
the same switch gets `:2`). pinviz reads those positions at start, so the layout
is the single place a playfield is drawn, and the table adds only what a picture
cannot say: walls, rails, flippers, physics and the solenoid that resets or kicks
each thing. Features may also carry their own coordinates for machines whose
layout has no ids (Playboy). Solenoid outputs from the driver drive the
ball the other way: serving, the outhole kick, saucer kickers, drop target
resets and the flipper enable relay. Tables exist for `centaur` and `playboy`.

    mame centaur -plugin pinviz

Keys: left and right Shift for the flippers (or whatever the table names),
Space to plunge. The usual MAME keys coin up and start the game.

Environment variables: `PINVIZ_AUTOPILOT=1` plays by itself, which makes a
driver regression test out of it; `PINVIZ_LOG=1` prints the event log to the
console.
