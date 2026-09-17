-- license:BSD-3-Clause
-- copyright-holders:Ben Bruscella
--
-- pinviz table definition for Bally Centaur (1981).
--
-- Feature positions were read off a straight-on photograph of a bare Centaur
-- playfield with a one inch grid overlaid, so the layout follows the real
-- machine: the Queen's Chamber lane with its four inline drop targets down the
-- far left, the two pop bumpers at the top, the O-R-B-S drop target bank curving
-- under them, the orb release tunnel and bonus multiplier lane up the right, the
-- right four-bank along a diagonal beside it, slingshots, in and out lanes and
-- flippers. No artwork is used. Units are inches, origin top left, y down the
-- table towards the flippers.
--
-- Switch numbers follow the switch matrix (PinWiki / Pinitech). Solenoid indices
-- are the 4-bit decoder values the driver reports as solenoid0..15; see the
-- solenoid table in src/mame/pinball/by35.cpp for the manual numbering.

local W, L = 20.25, 42.0
local LANE = 19.0             -- left edge of the shooter lane
local CX = 9.5                -- playfield centre line, excluding the shooter lane

local function mirror(x) return 2 * CX - x end

-- top: a flattened arch rather than a semicircle, the real top is squarish
local top = { { 0, 6.0 }, { 0.6, 3.6 }, { 2.0, 1.9 }, { 4.2, 0.9 }, { 7.0, 0.5 }, { 10.2, 0.4 },
	{ 13.5, 0.55 }, { 16.0, 0.95 }, { 18.0, 1.8 }, { 19.4, 3.2 }, { W, 5.5 } }
local walls = {}
for i = 1, #top - 1 do walls[#walls + 1] = { top[i][1], top[i][2], top[i + 1][1], top[i + 1][2] } end

local more = {
	-- side walls
	{ 0, 6.0, 0, L }, { W, 5.5, W, L },
	-- shooter lane wall
	{ LANE, 11.5, LANE, L },
	-- Queen's Chamber lane on the far left: right hand wall, open at the bottom
	{ 2.7, 1.6, 2.7, 20.6 },
	-- top lane guides, three lanes between four guides
	{ 5.6, 3.4, 5.6, 6.2 }, { 7.6, 3.2, 7.6, 6.0 }, { 9.7, 3.0, 9.7, 5.8 }, { 11.8, 2.9, 11.8, 5.7 },
	-- orb release tunnel / bonus lane on the right: inner wall
	{ 16.8, 3.6, 16.8, 13.4 },
	-- wall behind the right four-bank
	{ 18.2, 16.0, 18.2, 21.2 },
	-- outlane dividers and inlane guides
	{ 2.0, 27.4, 2.0, 32.4 }, { mirror(2.0), 27.4, mirror(2.0), 32.4 },
	{ 4.0, 27.4, 4.0, 28.2 }, { mirror(4.0), 27.4, mirror(4.0), 28.2 },
	-- outlane dividers and inlane guides
	{ 2.0, 27.4, 2.0, 32.4 }, { mirror(2.0), 27.4, mirror(2.0), 32.4 },
	{ 4.0, 27.4, 4.0, 28.2 }, { mirror(4.0), 27.4, mirror(4.0), 28.2 },
	-- sling undersides
	{ 4.3, 31.2, 5.4, 31.2 }, { mirror(4.3), 31.2, mirror(5.4), 31.2 },
	-- lower guides from the inlanes down to the flippers
	{ 4.0, 31.2, 5.8, 33.6 }, { mirror(4.0), 31.2, mirror(5.8), 33.6 },
	-- apron edges below the outlanes
	{ 0, 34.0, 4.6, 37.6 }, { LANE, 34.0, mirror(4.6), 37.6 },
}
for _, s in ipairs(more) do walls[#walls + 1] = s end

local posts = {
	{ 3.0, 5.5, 0.4 }, { 3.0, 8.4, 0.4 }, { 15.0, 7.2, 0.4 },
	{ 9.9, 16.5, 0.45 }, { 1.5, 23.5, 0.35 }, { 17.4, 23.5, 0.35 },
}

-- ORBS bank: four drop targets on an arc under the pops, facing down-left
local function orbs(x0, y0, x1, y1, mask, name)
	return { x0, y0, x1, y1, switch = { ':X3', mask }, name = name, drop = true, reset = 'solenoid0' }
end
-- right four-bank along a diagonal, facing left, #1 at the top
local function right4(y, mask, name)
	local x = 16.3 + (y - 16.8) * 0.37
	return { x, y, x + 0.35, y + 0.85, switch = { ':X3', mask }, name = name, drop = true, reset = 'solenoid8' }
end
-- inline drop targets across the Queen's Chamber lane, #1 nearest the entrance
local function inline(y, mask, name)
	return { 0.7, y, 2.7, y, switch = { ':X5', mask }, name = name, drop = true, reset = 'solenoid7' }
end

return {
	name = 'Centaur',
	width = W, length = L,
	ball_radius = 0.53,
	gravity = 43.0,
	rolling_friction = 0.12,
	wall_restitution = 0.45,

	walls = walls,
	-- one way gate flap over the top of the shooter lane
	gates = { { W, 8.4, LANE - 0.4, 10.0 } },
	posts = posts,

	serve_solenoids = { 'solenoid13', 'solenoid14' },   -- ball kick to playfield, ball release
	serve_position = { LANE + 0.6, 39.0 },
	launch_speed = 118,
	outhole_solenoid = 'solenoid6',
	outhole_switch = { ':X0', 0x80 },
	flipper_enable = 'solenoid18',
	drain_y = 38.6,
	drain_x = { 0, LANE },      -- the shooter lane runs below the drain line

	flippers = {
		{ pivot = { 5.8, 33.6 }, length = 3.1, rest = 32, up = -28, key = 'KEYCODE_LSHIFT' },
		{ pivot = { mirror(5.8), 33.6 }, length = 3.1, rest = 148, up = 208, key = 'KEYCODE_RSHIFT' },
	},

	slings = {
		{ 4.3, 28.2, 5.4, 31.2, kick = 55, switch = { ':X4', 0x10 }, name = 'Left Slingshot' },
		{ mirror(4.3), 28.2, mirror(5.4), 31.2, kick = 55, switch = { ':X4', 0x20 }, name = 'Right Slingshot' },
		-- rubbers on the lower guides, the "10 point rebound" switches
		{ 4.0, 31.2, 5.8, 33.6, kick = 25, switch = { ':X4', 0x02 }, name = '10 Points Rebound' },
		{ mirror(4.0), 31.2, mirror(5.8), 33.6, kick = 25, switch = { ':X4', 0x02 }, name = '10 Points Rebound' },
	},

	bumpers = {
		{ 7.6, 9.5, 1.15, kick = 65, switch = { ':X4', 0x80 }, name = 'Left Thumper Bumper' },
		{ 12.1, 8.5, 1.15, kick = 65, switch = { ':X4', 0x40 }, name = 'Right Thumper Bumper' },
	},

	targets = {
		-- O R B S, left to right, reset by Sol 9 (value 0)
		orbs(7.4, 13.3, 8.3, 13.0, 0x80, 'Drop Target O'),
		orbs(8.4, 13.0, 9.3, 12.75, 0x40, 'Drop Target R'),
		orbs(10.3, 12.65, 11.2, 12.45, 0x20, 'Drop Target B'),
		orbs(11.3, 12.45, 12.2, 12.3, 0x10, 'Drop Target S'),
		-- right four-bank, reset by Sol 4 (value 8)
		right4(16.8, 0x08, 'Right 4 Drop Target #1'),
		right4(17.75, 0x04, 'Right 4 Drop Target #2'),
		right4(18.7, 0x02, 'Right 4 Drop Target #3'),
		right4(19.65, 0x01, 'Right 4 Drop Target #4'),
		-- inline drop targets up the Queen's Chamber lane, reset by Sol 3 (value 7)
		inline(11.5, 0x01, 'Inline Drop Target #1'),
		inline(9.4, 0x02, 'Inline Drop Target #2'),
		inline(7.4, 0x04, 'Inline Drop Target #3'),
		inline(5.5, 0x08, 'Inline Drop Target #4'),
		{ 0.7, 3.6, 2.7, 3.6, switch = { ':X2', 0x08 }, name = 'Inline Back Target' },
		-- stand-up targets
		{ 2.7, 17.2, 2.7, 18.3, switch = { ':X2', 0x20 }, name = 'Reset 1-4 Targets Target' },
		{ 13.6, 6.8, 14.4, 7.6, switch = { ':X2', 0x80 }, name = 'Top Spot 1-4 Target' },
		{ 16.8, 12.0, 17.3, 13.0, switch = { ':X2', 0x04 }, name = 'ORBS Right Lane Target' },
		{ 9.2, 11.2, 10.4, 11.0, switch = { ':X1', 0x08 }, name = 'ORBS Back Targets' },
	},

	sensors = {
		{ 6.6, 5.0, 0.7, switch = { ':X0', 0x10 }, name = 'Top Lane Left' },
		{ 8.6, 4.7, 0.7, switch = { ':X0', 0x08 }, name = 'Top Lane Middle' },
		{ 10.7, 4.4, 0.7, switch = { ':X0', 0x04 }, name = 'Top Lane Right' },
		{ 3.4, 7.4, 0.6, switch = { ':X1', 0x08 }, name = 'Top Left Rollover Button' },
		{ 1.3, 24.2, 0.6, switch = { ':X2', 0x02 }, name = 'Left Side Rollover Button' },
		{ 1.0, 29.6, 0.7, switch = { ':X5', 0x80 }, name = 'Left Outlane' },
		{ 3.0, 29.6, 0.7, switch = { ':X5', 0x40 }, name = 'Left Return Lane' },
		{ mirror(1.0), 29.6, 0.7, switch = { ':X5', 0x10 }, name = 'Right Outlane' },
		{ mirror(3.0), 29.6, 0.7, switch = { ':X5', 0x20 }, name = 'Right Return Lane' },
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
