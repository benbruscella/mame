# pinviz

A minimal pinball playfield for testing MAME pinball drivers.

The emulated machine is the real thing: the ROM, switch matrix, solenoids,
lamps, displays and sound. This plugin adds the one part MAME does not have,
a ball. It is enough physics to play a game and watch the driver react, not a
simulator: one ball, walls, flippers, slingshots, pop bumpers, drop and
stand-up targets, saucers, lanes and the outhole, drawn as lines over the left
part of the window.

A table definition in `tables/<system>.lua` says where things are and which
input port field each one closes. Solenoid outputs from the driver drive the
ball the other way: serving, the outhole kick, saucer kickers, drop target
resets and the flipper enable relay. Tables exist for `centaur` and `playboy`.

    mame centaur -plugin pinviz

Keys: left and right Shift for the flippers (or whatever the table names),
Space to plunge. The usual MAME keys coin up and start the game.

Environment variables: `PINVIZ_AUTOPILOT=1` plays by itself, which makes a
driver regression test out of it; `PINVIZ_LOG=1` prints the event log to the
console.
