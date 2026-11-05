-- license:BSD-3-Clause
-- copyright-holders:Ben Bruscella
--
-- pinviz playfield definition for Bally Playboy (1978).
--
-- Positions were read off a straight-on photograph of a bare Playboy playfield with
-- a one inch grid overlaid: the rails, the five lanes down the sides, the slots the
-- targets stand in, the flipper bushings and every lamp insert. No artwork is used.
-- Units are inches, origin top left, y down the table towards the flippers.
--
-- Three pop bumpers, a five target drop bank on a diagonal to the right, five
-- stand-up targets down the left, four top lanes, a centre target, and the kickback
-- grotto at the bottom of the far left lane. Above the lane, the grotto is a passage
-- with a one way gate at each end: a ball shot up the left goes in through the lower
-- gate and on out through the upper one onto the top lanes, and one that falls back
-- drops down the lane to the kickback, which sends it round the same way.

local W, L = 20.25, 42.0
local LANE = 18.0             -- left edge of the shooter lane
local SERVE_Y = 35.0

-- a target's face, centred on x, y, along the direction dx, dy
local function along(x, y, dx, dy, length)
	local n = math.sqrt(dx * dx + dy * dy)
	local hx, hy = dx / n * length / 2, dy / n * length / 2
	return x - hx, y - hy, x + hx, y + hy
end

-- the outer rail, up the side of the shooter lane, over the top and down to the grotto
local arch = { { 0.45, 8.6 }, { 1.7, 6.0 }, { 3.0, 4.6 }, { 5.0, 2.8 }, { 7.0, 1.75 }, { 10.0, 1.1 },
	{ 13.0, 1.55 }, { 15.0, 2.6 }, { 17.0, 4.2 }, { 18.6, 6.3 }, { 19.6, 8.8 }, { W - 0.25, 11.0 }, { W - 0.25, L - 5 } }
local walls = {}
for i = 1, #arch - 1 do walls[#walls + 1] = { arch[i][1], arch[i][2], arch[i + 1][1], arch[i + 1][2] } end

local more = {
	-- the left side of the table, and the shooter lane's wall
	{ 0.45, 8.6, 0.45, 33.0 }, { LANE, 9.4, LANE, 33.0 },
	-- top lanes, four between five guides; the outer two guides close off the corners
	{ 4.8, 4.9, 4.8, 7.2 }, { 7.0, 3.6, 7.0, 7.05 }, { 9.1, 3.6, 9.1, 7.05 }, { 11.2, 3.6, 11.2, 7.05 },
	-- the grotto: the leftmost top lane guide and the wall below it are the passage's right
	-- side, and the lower gate fills the rest, down to the top of the grotto lane
	{ 4.8, 7.2, 3.4, 8.3 },
	-- the plastic between the grotto lane and the star rollover
	{ 2.05, 9.4, 4.0, 9.4 }, { 4.0, 9.4, 4.0, 12.6 }, { 4.0, 12.6, 2.05, 12.6 },
	-- the island under the top right plastic, whose outer edge is the shooter lane's guide
	{ 14.7, 3.85, 16.0, 4.9 }, { 16.0, 4.9, 17.2, 7.0 }, { 17.2, 7.0, LANE, 9.4 },
	{ LANE, 9.4, 16.5, 7.45 }, { 16.5, 7.45, 13.0, 7.35 }, { 13.0, 7.35, 13.0, 5.1 }, { 13.0, 5.1, 14.7, 3.85 },
	-- the grotto lane: its right wall, which meets the island so there is no gap for a
	-- ball to wedge in, then the wall behind the stand-up targets, and the floor the
	-- kickback sits on
	{ 2.05, 9.4, 2.05, 16.9 }, { 2.05, 16.9, 2.55, 17.1 }, { 2.55, 17.1, 1.1, 23.7 }, { 1.1, 23.7, 0.45, 24.2 },
	{ 0.45, 19.6, 2.2, 18.6 },
	-- round the drop bank: the top, the wall behind the targets, and the right lane's
	-- left wall
	{ 13.2, 12.2, 16.05, 10.3 }, { 13.2, 12.2, 13.65, 12.6 }, { 13.65, 12.6, 15.45, 18.1 },
	{ 15.45, 18.1, 16.05, 17.9 }, { 15.0, 18.2, 15.45, 18.1 }, { 16.05, 10.3, 16.05, 14.6 }, { 16.05, 16.6, 16.05, 17.9 },
	-- the island at the foot of the right lane
	{ 17.65, 20.4, LANE, 20.4 }, { LANE, 25.2, 15.45, 25.2 },
	-- outlane and inlane dividers
	{ 1.9, 26.0, 1.9, 31.5 }, { 16.4, 26.0, 16.4, 31.5 },
	-- the frames of the slingshots, which also carry the inlanes onto the flippers
	{ 3.25, 28.0, 3.25, 31.0 }, { 3.25, 31.0, 5.85, 33.1 }, { 3.25, 28.0, 3.75, 28.6 }, { 5.75, 32.65, 5.85, 33.1 },
	{ 15.1, 28.0, 15.1, 31.0 }, { 15.1, 31.0, 12.5, 33.1 }, { 15.1, 28.0, 14.6, 28.6 }, { 12.6, 32.65, 12.5, 33.1 },
	-- inlane guides. Each runs onto the top of the bat, a little past the pivot, so a
	-- ball rolls straight from one onto the other. A guide that stops short of the pivot
	-- leaves a dimple between its end and the back of the bat that holds a ball for good.
	{ 1.9, 31.5, 6.07, 34.76 }, { 16.4, 31.5, 12.28, 34.76 },
	-- the apron, funnelling the outlanes and the gap between the flippers to the outhole
	{ 0.45, 33.0, 8.0, 39.4 }, { LANE, 33.0, 10.3, 39.4 }, { 8.0, 39.4, 10.3, 39.4 },
}
for _, s in ipairs(more) do walls[#walls + 1] = s end

local function stand_up(x, y, mask, number)
	local x0, y0, x1, y1 = along(x, y, -0.25, 0.97, 1.0)
	return { x0, y0, x1, y1, name = 'Left Target ' .. number, switch = { ':X3', mask } }
end

local function drop(x, y, mask, number)
	local x0, y0, x1, y1 = along(x, y, 1.8, 5.5, 1.14)
	return { x0, y0, x1, y1, name = 'Drop Target ' .. number, switch = { ':X0', mask }, drop = true, reset = 'solenoid12' }
end

local t = {
	name = 'Playboy',
	width = W, length = L, lane = LANE,
	ball_radius = 0.53,
	gravity = 43.0,
	rolling_friction = 0.12,
	wall_restitution = 0.45,

	walls = walls,
	-- One way gates, each passable from one side only. Where the arch meets the playfield,
	-- rather than at the top of the shooter lane: a launch too weak to clear the arch rolls
	-- back to the plunger, and a gate lower down would catch it with nowhere to go. Then
	-- the grotto's two: the lower lets a ball from the playfield into the passage, and the
	-- upper lets it out onto the top lanes, but neither lets one back the other way.
	gates = { { 15.0, 2.6, 14.7, 3.85 }, { 3.4, 8.3, 2.05, 9.4 }, { 4.8, 4.9, 4.75, 3.05 } },
	posts = {
		{ 7.0, 3.6, 0.25 }, { 9.1, 3.6, 0.25 }, { 11.2, 3.6, 0.25 }, { 7.0, 7.05, 0.25 }, { 9.1, 7.05, 0.25 }, { 11.2, 7.05, 0.25 },
		{ 4.8, 4.9, 0.25 }, { 4.35, 14.45, 0.3 }, { 2.4, 12.8, 0.25 }, { 2.15, 15.1, 0.25 }, { 1.9, 26.0, 0.25 }, { 16.4, 26.0, 0.25 },
	},

	serve_position = { (LANE + W - 0.25) / 2, SERVE_Y },
	launch_speed = 95,
	serve_solenoids = {},
	serve_on_flipper_enable = true,
	outhole_solenoid = 'solenoid6',
	outhole_switch = { ':X0', 0x80 },
	flipper_enable = 'solenoid18',
	drain_y = 38.4,
	drain_x = { 0, LANE },

	flippers = {
		-- three inch bats leave nearly two inches between the tips. The ball needs 1.5 to
		-- pass, with the bats' thickness, and much less than that and it balances there.
		{ pivot = { 5.7, 34.8 }, length = 3.0, rest = 32, up = -28, key = 'KEYCODE_LSHIFT' },
		{ pivot = { 12.65, 34.8 }, length = 3.0, rest = 148, up = 208, key = 'KEYCODE_RSHIFT' },
	},

	-- by35.cpp reads these through its own latch rather than an input. It releases the
	-- outhole itself on solenoid6, but this machine runs with the default solenoid
	-- table, so the kickback and the drop targets have to be released here.
	latched = {
		{ ':X0', 0x80 }, { ':X3', 0x80 },
		{ ':X0', 0x01 }, { ':X0', 0x02 }, { ':X0', 0x04 }, { ':X0', 0x08 }, { ':X0', 0x10 },
	},
	releases = {
		solenoid7 = { ':X3', 0x80 },
		solenoid12 = { ':X0', 0x1f },
	},

	bumpers = {
		{ 6.9, 10.6, 1.45, name = 'Left Thumper Bumper', switch = { ':X4', 0x80 }, kick = 65, coil = 'solenoid8' },
		{ 11.25, 10.6, 1.45, name = 'Right Thumper Bumper', switch = { ':X4', 0x40 }, kick = 65, coil = 'solenoid9' },
		{ 9.15, 14.7, 1.45, name = 'Bottom Thumper Bumper', switch = { ':X4', 0x20 }, kick = 65, coil = 'solenoid10' },
	},

	slings = {
		{ 3.75, 28.6, 5.75, 32.65, name = 'Left Slingshot', switch = { ':X4', 0x10 }, kick = 55, coil = 'solenoid11' },
		{ 12.6, 32.65, 14.6, 28.6, name = 'Right Slingshot', switch = { ':X4', 0x08 }, kick = 55, coil = 'solenoid13' },
		-- the rubber on the island at the foot of the right lane
		{ 15.45, 25.2, 17.65, 20.4, name = 'Rebound Rubber', switch = { ':X4', 0x01 }, kick = 25 },
		{ 16.05, 14.6, 16.05, 16.6, name = 'Rebound Rubber', switch = { ':X4', 0x01 }, kick = 25 },
	},

	targets = {
		-- five drop targets standing in the diagonal slot, reset by Sol 13
		drop(13.38, 13.27, 0x10, 1), drop(13.74, 14.37, 0x08, 2), drop(14.10, 15.47, 0x04, 3),
		drop(14.46, 16.57, 0x02, 4), drop(14.82, 17.67, 0x01, 5),
		-- five stand-up targets, each in front of its slot
		stand_up(2.85, 17.6, 0x10, 1), stand_up(2.45, 19.05, 0x08, 2), stand_up(2.1, 20.45, 0x04, 3),
		stand_up(1.7, 21.85, 0x02, 4), stand_up(1.35, 23.3, 0x01, 5),
		{ 8.55, 16.35, 9.75, 16.35, name = 'Centre Target', switch = { ':X2', 0x01 } },
	},

	-- the kickback holds the ball until Sol 8 fires it back up the lane, and the ROM
	-- takes a little over five seconds to do that
	saucers = {
		{ 1.0, 18.05, 0.7, name = 'Kickback Grotto', switch = { ':X3', 0x80 }, solenoid = 'solenoid7',
		  kick = { 0, -92 }, timeout = 8, timeout_kick = { 0, -40 } },
	},

	sensors = {
		{ 5.9, 6.3, 0.7, name = 'Top Lane 1', switch = { ':X2', 0x10 } },
		{ 8.05, 6.3, 0.7, name = 'Top Lane 2', switch = { ':X2', 0x08 } },
		{ 10.15, 6.3, 0.7, name = 'Top Lane 3', switch = { ':X2', 0x04 } },
		{ 12.25, 6.3, 0.7, name = 'Top Lane 4', switch = { ':X2', 0x02 } },
		{ 17.0, 13.5, 0.7, name = 'Right Lane Rollover', switch = { ':X3', 0x40 } },
		{ 3.2, 14.2, 0.75, name = 'Rollover Button', switch = { ':X3', 0x20 } },
		{ 1.2, 30.0, 0.65, name = 'Left Outlane', switch = { ':X2', 0x40 } },
		{ 17.1, 30.0, 0.65, name = 'Right Outlane', switch = { ':X2', 0x20 } },
		{ 2.55, 30.0, 0.6, name = 'Left Return Lane', switch = { ':X2', 0x80 } },
		{ 15.75, 30.0, 0.6, name = 'Right Return Lane', switch = { ':X2', 0x80 } },
	},

	-- the lamp inserts
	lamps = {
		{ n = 47, x = 9.15, y = 2.55, r = 0.42, colour = 'red' },
		{ n = 3, x = 5.9, y = 4.0, r = 0.72, colour = 'white' },
		{ n = 18, x = 8.1, y = 4.0, r = 0.72, colour = 'white' },
		{ n = 33, x = 10.2, y = 4.0, r = 0.72, colour = 'white' },
		{ n = 48, x = 12.25, y = 4.0, r = 0.72, colour = 'white' },
		{ n = 19, x = 1.7, y = 8.15, r = 0.55, colour = 'white' },
		{ n = 5, x = 1.0, y = 11.0, r = 0.42, colour = 'white' },
		{ n = 20, x = 1.0, y = 12.1, r = 0.42, colour = 'white' },
		{ n = 35, x = 1.0, y = 13.2, r = 0.42, colour = 'white' },
		{ n = 50, x = 1.0, y = 14.35, r = 0.42, colour = 'white' },
		{ n = 6, x = 1.0, y = 15.45, r = 0.42, colour = 'white' },
		{ n = 38, x = 4.5, y = 12.2, r = 0.55, colour = 'red' },
		{ n = 23, x = 3.2, y = 14.2, r = 0.72, colour = 'amber' },
		{ n = 53, x = 4.6, y = 16.0, r = 0.55, colour = 'amber' },
		{ n = 49, x = 12.6, y = 15.85, r = 0.55, colour = 'red' },
		{ n = 4, x = 9.15, y = 18.6, r = 0.72, colour = 'white' },
		{ n = 7, x = 4.6, y = 18.0, r = 0.42, colour = 'white' },
		{ n = 22, x = 4.25, y = 19.35, r = 0.42, colour = 'white' },
		{ n = 37, x = 3.8, y = 20.8, r = 0.42, colour = 'white' },
		{ n = 52, x = 3.45, y = 22.3, r = 0.42, colour = 'white' },
		{ n = 8, x = 3.05, y = 23.7, r = 0.42, colour = 'white' },
		{ n = 34, x = 16.1, y = 20.4, r = 0.55, colour = 'white' },
		{ n = 56, x = 1.2, y = 26.35, r = 0.42, colour = 'white' },
		{ n = 41, x = 17.05, y = 26.65, r = 0.42, colour = 'white' },
		{ n = 21, x = 9.1, y = 25.0, r = 0.5, colour = 'white' },
		{ n = 51, x = 7.7, y = 25.6, r = 0.5, colour = 'white' },
		{ n = 36, x = 10.45, y = 25.6, r = 0.5, colour = 'white' },
		{ n = 32, x = 9.15, y = 26.4, r = 0.46, colour = 'white' },
		{ n = 45, x = 6.9, y = 27.0, r = 0.42, colour = 'white' },
		{ n = 1, x = 8.0, y = 27.0, r = 0.42, colour = 'white' },
		{ n = 16, x = 10.35, y = 27.0, r = 0.42, colour = 'white' },
		{ n = 31, x = 11.45, y = 27.0, r = 0.42, colour = 'white' },
		{ n = 30, x = 6.9, y = 28.1, r = 0.42, colour = 'white' },
		{ n = 46, x = 11.45, y = 28.1, r = 0.42, colour = 'white' },
		{ n = 15, x = 6.9, y = 30.95, r = 0.42, colour = 'white' },
		{ n = 2, x = 11.45, y = 30.95, r = 0.42, colour = 'white' },
		{ n = 0, x = 6.9, y = 32.1, r = 0.42, colour = 'white' },
		{ n = 17, x = 11.45, y = 32.1, r = 0.42, colour = 'white' },
		{ n = 40, x = 9.15, y = 33.85, r = 0.45, colour = 'amber' },
	},

	-- everywhere a ball cannot be, for the drain test: under the plastics, behind the
	-- targets, under the apron and outside the rail
	closed = {
		{ { 14.7, 3.85 }, { 16.0, 4.9 }, { 17.2, 7.0 }, { 18.0, 9.4 }, { 16.5, 7.45 }, { 13.0, 7.35 }, { 13.0, 5.1 } },
		{ { 2.05, 9.4 }, { 4.0, 9.4 }, { 4.0, 12.6 }, { 2.05, 12.6 } },
		{ { 13.2, 12.2 }, { 16.05, 10.3 }, { 16.05, 17.9 }, { 15.45, 18.1 }, { 13.65, 12.6 } },
		{ { 15.45, 25.2 }, { 17.65, 20.4 }, { 18.0, 20.4 }, { 18.0, 25.2 } },
		{ { 3.25, 28.0 }, { 3.75, 28.6 }, { 5.75, 32.65 }, { 5.85, 33.1 }, { 3.25, 31.0 } },
		{ { 15.1, 28.0 }, { 14.6, 28.6 }, { 12.6, 32.65 }, { 12.5, 33.1 }, { 15.1, 31.0 } },
		{ { 0.45, 19.6 }, { 2.2, 18.6 }, { 1.1, 23.7 }, { 0.45, 24.2 } },
		{ { 0, 33.0 }, { 0.45, 33.0 }, { 8.0, 39.4 }, { 10.3, 39.4 }, { LANE, 33.0 }, { LANE, 36.6 }, { W, 36.6 }, { W, L }, { 0, L } },
		{ { 0, 0 }, { W, 0 }, { W, 11.0 }, { W - 0.25, 11.0 }, { 19.6, 8.8 }, { 18.6, 6.3 }, { 17.0, 4.2 }, { 15.0, 2.6 }, { 13.0, 1.55 },
			{ 10.0, 1.1 }, { 7.0, 1.75 }, { 5.0, 2.8 }, { 3.0, 4.6 }, { 1.7, 6.0 }, { 0.45, 8.6 }, { 0.45, 33.0 }, { 0, 33.0 } },
	},

	solenoid_names = {
		[5] = 'Knocker', [6] = 'Outhole', [7] = 'Kickback Grotto', [8] = 'Left Thumper Bumper',
		[9] = 'Right Thumper Bumper', [10] = 'Bottom Thumper Bumper', [11] = 'Left Slingshot',
		[12] = 'Drop Target Reset', [13] = 'Right Slingshot', [17] = 'Coin Lockout',
		[18] = 'Flipper Enable Relay',
	},
}

return t
