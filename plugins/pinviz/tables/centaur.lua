-- license:BSD-3-Clause
-- copyright-holders:Ben Bruscella
--
-- pinviz table definition for Bally Centaur (1981).
--
-- This is a test playfield, not a reproduction. Feature positions are approximate,
-- laid out from the manual's switch chart so that every playfield switch the game
-- reads can be reached by the ball. Units are inches, origin at the top left of
-- the playfield, x to the right, y down the table towards the flippers.
--
-- Switch numbers follow the switch matrix (PinWiki / Pinitech). Solenoid indices are
-- the 4-bit decoder values the driver reports as solenoid0..15 outputs; see the
-- solenoid table in src/mame/pinball/by35.cpp for the manual numbering.

local W, L = 20.25, 42.0      -- playfield width and length
local LANE = 19.25            -- left edge of the shooter lane
local CX = LANE / 2           -- playfield centre line (excluding the shooter lane)

local function mirror(x) return LANE - x end

-- top arc: semicircle over the playfield, ball comes up the shooter lane into it
local arc = {}
do
	local cx, cy, r = W / 2, W / 2, W / 2
	local n = 16
	for i = 0, n - 1 do
		local a0 = math.pi + (i / n) * math.pi
		local a1 = math.pi + ((i + 1) / n) * math.pi
		arc[#arc + 1] = { cx + r * math.cos(a0), cy + r * math.sin(a0), cx + r * math.cos(a1), cy + r * math.sin(a1) }
	end
end

local walls = {
	-- side walls below the arc
	{ 0, W / 2, 0, L },
	{ W, W / 2, W, L },
	-- shooter lane wall
	{ LANE, W / 2 + 1.0, LANE, L },
	-- lane guides above the top lanes (three lanes between four posts)
	{ 7.4, 1.5, 7.4, 4.6 }, { 9.3, 1.5, 9.3, 4.6 }, { 11.2, 1.5, 11.2, 4.6 }, { 13.1, 1.5, 13.1, 4.6 },
	-- wall behind the left ORBS drop target bank and the right 4 bank
	{ 1.4, 13.0, 1.4, 20.6 }, { 1.4, 20.6, 2.4, 20.6 },
	{ 18.7, 13.0, 18.7, 20.6 }, { 18.7, 20.6, 17.8, 20.6 },
	-- inline drop target channel (open at the bottom, back target at the top)
	{ 14.2, 21.0, 14.2, 29.0 }, { 15.9, 21.0, 15.9, 29.0 },
	-- outlane dividers
	{ 1.9, 27.0, 1.9, 36.0 }, { mirror(1.9), 27.0, mirror(1.9), 36.0 },
	-- inlane guides down to the sling tops
	{ 3.9, 29.5, 3.9, 31.4 }, { mirror(3.9), 29.5, mirror(3.9), 31.4 },
	-- sling undersides
	{ 3.9, 35.4, 5.6, 35.4 }, { mirror(3.9), 35.4, mirror(5.6), 35.4 },
	-- a few posts as obstacles in the middle
}
for _, s in ipairs(arc) do walls[#walls + 1] = s end

local posts = {
	{ CX, 17.0, 0.45 }, { CX - 3.0, 22.5, 0.45 }, { CX + 3.0, 22.5, 0.45 },
}

return {
	name = 'Centaur',
	width = W, length = L,
	ball_radius = 0.53,
	gravity = 43.0,             -- in/s^2 down the incline
	rolling_friction = 0.12,    -- fraction of velocity lost per second
	wall_restitution = 0.45,

	walls = walls,
	posts = posts,

	-- serve: a ball appears in the shooter lane on either of these, then is plunged
	serve_solenoids = { 'solenoid13', 'solenoid14' },   -- ball kick to playfield, ball release
	serve_position = { LANE + 0.5, 39.5 },
	launch_speed = 115,
	outhole_solenoid = 'solenoid6',
	outhole_switch = { ':X0', 0x80 },
	flipper_enable = 'solenoid18',
	drain_y = 41.3,

	flippers = {
		{ pivot = { 6.4, 38.6 }, length = 3.1, rest = 32, up = -28, key = 'KEYCODE_LSHIFT' },
		{ pivot = { mirror(6.4), 38.6 }, length = 3.1, rest = 148, up = 208, key = 'KEYCODE_RSHIFT' },
	},

	-- rubber faces that kick the ball and close a switch
	slings = {
		{ 3.9, 31.4, 5.6, 35.4, kick = 55, switch = { ':X4', 0x10 }, name = 'Left Slingshot' },
		{ mirror(3.9), 31.4, mirror(5.6), 35.4, kick = 55, switch = { ':X4', 0x20 }, name = 'Right Slingshot' },
		-- rubbers on the lower guides, the "10 point rebound" switches
		{ 3.9, 35.4, 6.4, 38.6, kick = 25, switch = { ':X4', 0x02 }, name = '10 Points Rebound' },
		{ mirror(3.9), 35.4, mirror(6.4), 38.6, kick = 25, switch = { ':X4', 0x02 }, name = '10 Points Rebound' },
	},

	bumpers = {
		{ 6.5, 9.5, 1.1, kick = 65, switch = { ':X4', 0x80 }, name = 'Left Thumper Bumper' },
		{ 13.5, 9.5, 1.1, kick = 65, switch = { ':X4', 0x40 }, name = 'Right Thumper Bumper' },
	},

	-- targets: segments that close a switch when hit. drop = true removes the target
	-- until the named solenoid output fires.
	targets = {
		-- left ORBS bank (O R B S, top to bottom), reset by Sol 9 (value 0)
		{ 2.4, 13.5, 2.4, 15.1, switch = { ':X3', 0x80 }, name = 'Drop Target O', drop = true, reset = 'solenoid0' },
		{ 2.4, 15.1, 2.4, 16.7, switch = { ':X3', 0x40 }, name = 'Drop Target R', drop = true, reset = 'solenoid0' },
		{ 2.4, 16.7, 2.4, 18.3, switch = { ':X3', 0x20 }, name = 'Drop Target B', drop = true, reset = 'solenoid0' },
		{ 2.4, 18.3, 2.4, 19.9, switch = { ':X3', 0x10 }, name = 'Drop Target S', drop = true, reset = 'solenoid0' },
		-- right 4 bank (#1 top to #4 bottom), reset by Sol 4 (value 8)
		{ 17.8, 13.5, 17.8, 15.1, switch = { ':X3', 0x08 }, name = 'Right 4 Drop Target #1', drop = true, reset = 'solenoid8' },
		{ 17.8, 15.1, 17.8, 16.7, switch = { ':X3', 0x04 }, name = 'Right 4 Drop Target #2', drop = true, reset = 'solenoid8' },
		{ 17.8, 16.7, 17.8, 18.3, switch = { ':X3', 0x02 }, name = 'Right 4 Drop Target #3', drop = true, reset = 'solenoid8' },
		{ 17.8, 18.3, 17.8, 19.9, switch = { ':X3', 0x01 }, name = 'Right 4 Drop Target #4', drop = true, reset = 'solenoid8' },
		-- inline drop targets in the channel, #1 nearest the flippers, reset by Sol 3 (value 7)
		{ 14.2, 27.0, 15.9, 27.0, switch = { ':X5', 0x01 }, name = 'Inline Drop Target #1', drop = true, reset = 'solenoid7' },
		{ 14.2, 25.4, 15.9, 25.4, switch = { ':X5', 0x02 }, name = 'Inline Drop Target #2', drop = true, reset = 'solenoid7' },
		{ 14.2, 23.8, 15.9, 23.8, switch = { ':X5', 0x04 }, name = 'Inline Drop Target #3', drop = true, reset = 'solenoid7' },
		{ 14.2, 22.2, 15.9, 22.2, switch = { ':X5', 0x08 }, name = 'Inline Drop Target #4', drop = true, reset = 'solenoid7' },
		{ 14.2, 21.0, 15.9, 21.0, switch = { ':X2', 0x08 }, name = 'Inline Back Target' },
		-- stand-up targets
		{ 16.0, 14.4, 17.0, 15.6, switch = { ':X2', 0x04 }, name = 'ORBS Right Lane Target' },
		{ 4.2, 23.4, 5.2, 24.6, switch = { ':X2', 0x20 }, name = 'Reset 1-4 Targets Target' },
		{ 12.0, 6.2, 13.2, 6.8, switch = { ':X2', 0x80 }, name = 'Top Spot 1-4 Target' },
		{ 3.0, 7.8, 4.0, 8.8, switch = { ':X1', 0x08 }, name = 'Top Left Rollover Button' },
	},

	-- rollovers and lanes: the switch closes while the ball passes through the circle
	sensors = {
		{ 8.35, 3.6, 0.7, switch = { ':X0', 0x10 }, name = 'Top Lane Left' },
		{ 10.25, 3.6, 0.7, switch = { ':X0', 0x08 }, name = 'Top Lane Middle' },
		{ 12.15, 3.6, 0.7, switch = { ':X0', 0x04 }, name = 'Top Lane Right' },
		{ 1.2, 24.5, 0.7, switch = { ':X2', 0x02 }, name = 'Left Side Rollover Button' },
		{ 0.95, 33.5, 0.8, switch = { ':X5', 0x80 }, name = 'Left Outlane' },
		{ 2.9, 33.5, 0.8, switch = { ':X5', 0x40 }, name = 'Left Return Lane' },
		{ mirror(0.95), 33.5, 0.8, switch = { ':X5', 0x10 }, name = 'Right Outlane' },
		{ mirror(2.9), 33.5, 0.8, switch = { ':X5', 0x20 }, name = 'Right Return Lane' },
	},

	solenoid_names = {
		[0] = 'ORBS Drop Target Reset', [1] = 'Right DT #1 Knockdown', [2] = 'Right DT #2 Knockdown',
		[3] = 'Right DT #3 Knockdown', [4] = 'Right DT #4 Knockdown', [5] = 'Knocker', [6] = 'Outhole',
		[7] = 'Inline Drop Target Reset', [8] = 'Right 4 Drop Target Reset', [9] = 'Left Thumper Bumper',
		[10] = 'Right Thumper Bumper', [11] = 'Left Slingshot', [12] = 'Right Slingshot',
		[13] = 'Ball Kick To Playfield', [14] = 'Ball Release', [17] = 'Coin Lockout',
		[18] = 'Flipper Enable Relay', [19] = 'Magnet',
	},
}
