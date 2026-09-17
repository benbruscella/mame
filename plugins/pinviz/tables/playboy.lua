-- license:BSD-3-Clause
-- copyright-holders:Ben Bruscella
--
-- pinviz table definition for Bally Playboy (1978).
--
-- Feature positions are taken from the switch and solenoid placements in MAME's
-- by35_playboy.lay mockup (320 x 480 layout pixels scaled to a 20.25 x 42 inch
-- playfield), so every switch the game reads can be reached by the ball. It is a
-- test playfield, not a reproduction. Units are inches, origin top left, y down.

local W, L = 20.25, 42.0
local LANE = 19.25

local function px(x, y) return x * W / 320, y * L / 480 end
local function mirror(x) return LANE - x end

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
	{ 0, W / 2, 0, L }, { W, W / 2, W, L },
	{ LANE, W / 2 + 1.6, LANE, L },
	-- top lane guides: five posts, four lanes
	{ 5.2, 3.0, 5.2, 6.4 }, { 7.5, 3.0, 7.5, 6.4 }, { 9.7, 3.0, 9.7, 6.4 }, { 12.0, 3.0, 12.0, 6.4 }, { 14.3, 3.0, 14.3, 6.4 },
	-- kickback grotto lane on the far left, open at the top
	{ 1.5, 17.0, 1.5, 22.0 },
	-- outlane dividers and inlane guides
	{ 1.9, 27.0, 1.9, 36.0 }, { mirror(1.9), 27.0, mirror(1.9), 36.0 },
	{ 3.9, 29.5, 3.9, 31.4 }, { mirror(3.9), 29.5, mirror(3.9), 31.4 },
	{ 3.9, 35.4, 5.6, 35.4 }, { mirror(3.9), 35.4, mirror(5.6), 35.4 },
	-- inlane rails from the bottom of the outlane dividers onto the flippers; a ball
	-- in the inlane is fed to the flipper, a ball in the outlane drops past it
	{ 1.9, 36.0, 6.4, 38.6 }, { mirror(1.9), 36.0, mirror(6.4), 38.6 },
}
for _, s in ipairs(arc) do walls[#walls + 1] = s end

local function drop(x, y, mask, name)
	-- diagonal bank on the right, targets face down-left
	return { x, y, x + 0.5, y - 0.9, switch = { ':X0', mask }, name = name, drop = true, reset = 'solenoid12' }
end

local function standup_left(x, y, mask, name)
	return { x, y, x + 0.6, y + 0.9, switch = { ':X3', mask }, name = name }
end

local b1x, b1y = px(124, 140)
local b2x, b2y = px(197, 140)
local b3x, b3y = px(161, 193)

return {
	name = 'Playboy',
	width = W, length = L,
	ball_radius = 0.53,
	gravity = 43.0,
	rolling_friction = 0.12,
	wall_restitution = 0.45,

	walls = walls,
	-- one way gate flap over the top of the shooter lane, sloping down into the
	-- playfield: a ball coming round the arc rolls off it, a launched ball passes up
	-- through it. Points are listed so the arc side gives a positive cross product.
	gates = { { W, W / 2 + 0.2, LANE - 0.4, W / 2 + 1.6 } },
	posts = { { W / 2, 25.0, 0.45 } },

	-- single ball: it waits in the shooter lane, the game just enables the flippers
	serve_solenoids = {},
	serve_on_flipper_enable = true,
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

	slings = {
		{ 3.9, 31.4, 5.6, 35.4, kick = 55, switch = { ':X4', 0x10 }, name = 'Left Slingshot' },
		{ mirror(3.9), 31.4, mirror(5.6), 35.4, kick = 55, switch = { ':X4', 0x08 }, name = 'Right Slingshot' },
	},

	bumpers = {
		{ b1x, b1y, 1.1, kick = 65, switch = { ':X4', 0x80 }, name = 'Left Thumper Bumper' },
		{ b2x, b2y, 1.1, kick = 65, switch = { ':X4', 0x40 }, name = 'Right Thumper Bumper' },
		{ b3x, b3y, 1.1, kick = 65, switch = { ':X4', 0x20 }, name = 'Bottom Thumper Bumper' },
	},

	targets = {
		drop(14.0, 14.9, 0x10, 'Drop Target 1'),
		drop(14.4, 16.2, 0x08, 'Drop Target 2'),
		drop(14.8, 17.5, 0x04, 'Drop Target 3'),
		drop(15.2, 18.8, 0x02, 'Drop Target 4'),
		drop(15.6, 20.1, 0x01, 'Drop Target 5'),
		{ 16.3, 16.0, 16.9, 17.2, switch = { ':X4', 0x01 }, name = 'Right Standup Target' },
		{ 9.2, 18.6, 10.4, 18.6, switch = { ':X2', 0x01 }, name = 'Centre Target' },
		standup_left(2.5, 19.5, 0x10, 'Left Target 1'),
		standup_left(2.15, 21.2, 0x08, 'Left Target 2'),
		standup_left(1.8, 22.9, 0x04, 'Left Target 3'),
		standup_left(1.45, 24.6, 0x02, 'Left Target 4'),
		standup_left(1.1, 26.3, 0x01, 'Left Target 5'),
	},

	-- the kickback grotto: ball is held until the kickback solenoid fires it back up
	saucers = {
		{ 0.8, 20.5, 0.9, switch = { ':X3', 0x80 }, solenoid = 'solenoid7', kick = { 6, -90 }, timeout = 5, timeout_kick = { 0, 15 }, name = 'Kickback Grotto' },
	},

	sensors = {
		{ 6.35, 6.0, 0.7, switch = { ':X2', 0x10 }, name = 'Top Lane 1' },
		{ 8.6, 6.0, 0.7, switch = { ':X2', 0x08 }, name = 'Top Lane 2' },
		{ 10.85, 6.0, 0.7, switch = { ':X2', 0x04 }, name = 'Top Lane 3' },
		{ 13.15, 6.0, 0.7, switch = { ':X2', 0x02 }, name = 'Top Lane 4' },
		{ 18.5, 14.7, 0.7, switch = { ':X3', 0x40 }, name = 'Right Lane Rollover' },
		{ 2.7, 15.8, 0.8, switch = { ':X3', 0x20 }, name = 'Rollover Button' },
		{ 0.95, 33.5, 0.8, switch = { ':X2', 0x40 }, name = 'Left Outlane' },
		{ mirror(0.95), 33.5, 0.8, switch = { ':X2', 0x20 }, name = 'Right Outlane' },
		{ 2.9, 33.5, 0.8, switch = { ':X2', 0x80 }, name = 'Left Return Lane' },
		{ mirror(2.9), 33.5, 0.8, switch = { ':X2', 0x80 }, name = 'Right Return Lane' },
	},

	solenoid_names = {
		[5] = 'Knocker', [6] = 'Outhole', [7] = 'Kickback Grotto', [8] = 'Left Thumper Bumper',
		[9] = 'Right Thumper Bumper', [10] = 'Bottom Thumper Bumper', [11] = 'Left Slingshot',
		[12] = 'Drop Target Reset', [13] = 'Right Slingshot', [17] = 'Coin Lockout', [18] = 'Flipper Enable Relay',
	},
}
