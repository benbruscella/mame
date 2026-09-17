-- license:BSD-3-Clause
-- copyright-holders:Ben Bruscella
--
-- pinviz: a minimal pinball playfield for testing MAME pinball drivers.
--
-- The emulated machine is the real thing: the ROM, switch matrix, solenoids,
-- lamps, displays and sound. This plugin adds the one part MAME does not have,
-- a ball. It is enough physics to play a game and watch the driver react, not a
-- simulator: one ball, walls, flippers, slingshots, pop bumpers, targets and
-- lanes, drawn as lines over the left part of the window.
--
-- A table definition (plugins/pinviz/tables/<system>.lua) says where things are
-- and which input port field each one closes. Solenoid outputs from the driver
-- drive the ball the other way: serving, the outhole kick, drop target resets
-- and the flipper enable relay.
--
-- Keys: left/right flipper as named in the table (Shift keys for Centaur),
-- Space to plunge. Environment: PINVIZ_AUTOPILOT=1 plays by itself,
-- PINVIZ_LOG=1 prints the event log to the console.

local exports = {
	name = 'pinviz',
	version = '0.1.0',
	description = 'Minimal pinball playfield simulation for testing pinball drivers',
	license = 'BSD-3-Clause',
	author = { name = 'Ben Bruscella' } }

local pinviz = exports

local frame_subscription, start_subscription, stop_subscription

function pinviz.startplugin()

	local sim = nil            -- simulation state, nil when the running machine has no table
	local autopilot = os.getenv('PINVIZ_AUTOPILOT') == '1'
	local console_log = os.getenv('PINVIZ_LOG') == '1'

	local SUBSTEPS = 8
	local FRAME_DT = 1 / 60
	local SWITCH_FRAMES = 5     -- how long a hit holds a matrix switch closed
	local BALL_RESTITUTION_MIN_SPEED = 2.0

	-- --------------------------------------------------------------------
	-- helpers
	-- --------------------------------------------------------------------

	local function load_table(name)
		local ok, tbl = pcall(require, 'pinviz/tables/' .. name)
		if ok and type(tbl) == 'table' then
			return tbl
		end
		return nil
	end

	local function output_proxy(name)
		local root = manager.machine.devices[':']
		return root:output(name)
	end

	local function field(sw)
		local port = manager.machine.ioport.ports[sw[1]]
		if not port then return nil end
		return port:field(sw[2])
	end

	local function log(s, msg)
		local t = manager.machine.time.seconds + (manager.machine.time.msec / 1000)
		local line = string.format('%5.1f %s', t, msg)
		table.insert(s.events, 1, line)
		if #s.events > 14 then table.remove(s.events) end
		if console_log then print('[pinviz] ' .. line) end
	end

	-- --------------------------------------------------------------------
	-- switch handling: a hit closes a switch for a few frames
	-- --------------------------------------------------------------------

	local function pulse_switch(s, sw, name)
		local key = sw[1] .. '/' .. sw[2]
		local p = s.pulses[key]
		if not p then
			local f = field(sw)
			if not f then return end
			p = { field = f, frames = 0, name = name }
			s.pulses[key] = p
		end
		if p.frames == 0 then
			p.field:set_value(1)
			log(s, 'sw  ' .. (name or key))
			if name then s.flash[name] = 12 end
		end
		p.frames = SWITCH_FRAMES
	end

	local function hold_switch(s, sw, on)
		local f = field(sw)
		if not f then return end
		if on then f:set_value(1) else f:clear_value() end
	end

	local function update_pulses(s)
		for key, p in pairs(s.pulses) do
			if p.frames > 0 then
				p.frames = p.frames - 1
				if p.frames == 0 then p.field:clear_value() end
			end
		end
	end

	-- --------------------------------------------------------------------
	-- solenoid outputs: rising edges drive the ball
	-- --------------------------------------------------------------------

	local function watch_output(s, name)
		if not s.outputs[name] then
			s.outputs[name] = { proxy = output_proxy(name), last = 0, rose = false }
		end
	end

	local function update_outputs(s)
		for name, o in pairs(s.outputs) do
			local v = o.proxy:get() or 0
			o.rose = (v ~= 0) and (o.last == 0)
			o.last = v
			if o.rose then
				local idx = tonumber(name:match('^solenoid(%d+)$'))
				local label = idx and s.tbl.solenoid_names and s.tbl.solenoid_names[idx]
				log(s, 'sol ' .. (label or name))
				if label then s.flash[label] = 12 end
			end
		end
	end

	local function rose(s, name)
		local o = s.outputs[name]
		return o and o.rose
	end

	local function output_on(s, name)
		local o = s.outputs[name]
		return o and o.last ~= 0
	end

	-- --------------------------------------------------------------------
	-- ball and geometry
	-- --------------------------------------------------------------------

	-- push the ball out of a segment and reflect it. sv is the surface velocity
	-- (moving flippers), kick an extra outward speed (slings, bumpers).
	local function collide_segment(b, x0, y0, x1, y1, e, svx, svy, kick)
		local dx, dy = x1 - x0, y1 - y0
		local len2 = dx * dx + dy * dy
		if len2 < 1e-9 then return false end
		local t = ((b.x - x0) * dx + (b.y - y0) * dy) / len2
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		local cx, cy = x0 + t * dx, y0 + t * dy
		local nx, ny = b.x - cx, b.y - cy
		local d = math.sqrt(nx * nx + ny * ny)
		if d >= b.r or d < 1e-6 then return false end
		nx, ny = nx / d, ny / d
		b.x, b.y = cx + nx * b.r, cy + ny * b.r
		local rvx, rvy = b.vx - (svx or 0), b.vy - (svy or 0)
		local vn = rvx * nx + rvy * ny
		if vn < 0 then
			b.vx = b.vx - (1 + e) * vn * nx
			b.vy = b.vy - (1 + e) * vn * ny
		end
		if kick and kick > 0 then
			local cur = b.vx * nx + b.vy * ny
			if cur < kick then
				b.vx = b.vx + (kick - cur) * nx
				b.vy = b.vy + (kick - cur) * ny
			end
		end
		return true, nx, ny, t
	end

	local function collide_circle(b, cx, cy, cr, e, kick)
		local nx, ny = b.x - cx, b.y - cy
		local d = math.sqrt(nx * nx + ny * ny)
		local rr = cr + b.r
		if d >= rr or d < 1e-6 then return false end
		nx, ny = nx / d, ny / d
		b.x, b.y = cx + nx * rr, cy + ny * rr
		local vn = b.vx * nx + b.vy * ny
		if vn < 0 then
			b.vx = b.vx - (1 + e) * vn * nx
			b.vy = b.vy - (1 + e) * vn * ny
		end
		if kick and kick > 0 then
			local cur = b.vx * nx + b.vy * ny
			if cur < kick then
				b.vx = b.vx + (kick - cur) * nx
				b.vy = b.vy + (kick - cur) * ny
			end
		end
		return true
	end

	local function flipper_ends(f)
		local a = math.rad(f.angle)
		return f.pivot[1], f.pivot[2], f.pivot[1] + f.length * math.cos(a), f.pivot[2] + f.length * math.sin(a)
	end

	local function new_ball(s, x, y, vx, vy)
		s.ball = { x = x, y = y, vx = vx or 0, vy = vy or 0, r = s.tbl.ball_radius }
	end

	local function serve(s, why)
		local p = s.tbl.serve_position
		new_ball(s, p[1], p[2], 0, 0)
		s.state = 'shooter'
		s.shooter_frames = 0
		log(s, 'ball to shooter lane (' .. why .. ')')
	end

	local function plunge(s)
		local b = s.ball
		local spd = s.tbl.launch_speed * (0.9 + 0.2 * math.random())
		b.vx, b.vy = 0, -spd
		s.state = 'play'
		log(s, 'plunge')
	end

	-- --------------------------------------------------------------------
	-- one physics step
	-- --------------------------------------------------------------------

	local function step(s, dt)
		local tbl, b = s.tbl, s.ball
		if not b or s.state ~= 'play' then return end

		-- gravity down the incline, rolling friction
		b.vy = b.vy + tbl.gravity * dt
		local damp = 1 - tbl.rolling_friction * dt
		b.vx, b.vy = b.vx * damp, b.vy * damp

		b.x = b.x + b.vx * dt
		b.y = b.y + b.vy * dt

		local e = tbl.wall_restitution

		for _, w in ipairs(tbl.walls) do
			collide_segment(b, w[1], w[2], w[3], w[4], e)
		end
		for _, p in ipairs(tbl.posts or {}) do
			collide_circle(b, p[1], p[2], p[3], 0.6)
		end
		-- one way gates (shooter lane top): solid for a ball on the blocked side of the
		-- directed segment (positive cross product), open from the other side
		for _, g in ipairs(tbl.gates or {}) do
			local cross = (g[3] - g[1]) * (b.y - g[2]) - (g[4] - g[2]) * (b.x - g[1])
			if cross > 0 then
				collide_segment(b, g[1], g[2], g[3], g[4], 0.3)
			end
		end

		for i, f in ipairs(s.flippers) do
			local x0, y0, x1, y1 = flipper_ends(f)
			-- surface velocity at the contact point along the flipper
			local hit, nx, ny, t = collide_segment(b, x0, y0, x1, y1, 0.35, 0, 0)
			if hit and f.omega ~= 0 then
				local a = math.rad(f.angle)
				local d = t * f.length
				local svx, svy = -f.omega * d * math.sin(a), f.omega * d * math.cos(a)
				local vn = svx * nx + svy * ny
				if vn > 0 then
					-- surface moving into the ball: add its normal speed
					b.vx = b.vx + 1.4 * vn * nx
					b.vy = b.vy + 1.4 * vn * ny
				end
			end
		end

		for i, sl in ipairs(tbl.slings or {}) do
			local hit = collide_segment(b, sl[1], sl[2], sl[3], sl[4], 0.5, 0, 0, sl.kick)
			if hit then pulse_switch(s, sl.switch, sl.name) end
		end

		for i, bp in ipairs(tbl.bumpers or {}) do
			local hit = collide_circle(b, bp[1], bp[2], bp[3], 0.5, bp.kick)
			if hit then pulse_switch(s, bp.switch, bp.name) end
		end

		for i, tg in ipairs(tbl.targets or {}) do
			if not s.dropped[i] then
				local hit = collide_segment(b, tg[1], tg[2], tg[3], tg[4], 0.6)
				if hit then
					pulse_switch(s, tg.switch, tg.name)
					if tg.drop then
						s.dropped[i] = true
						log(s, 'target down: ' .. tg.name)
					end
				end
			end
		end

		for i, sc in ipairs(tbl.saucers or {}) do
			local dx, dy = b.x - sc[1], b.y - sc[2]
			if s.saucer_cooldown == 0 and (dx * dx + dy * dy) < (sc[3] * sc[3]) then
				b.x, b.y, b.vx, b.vy = sc[1], sc[2], 0, 0
				s.state = 'saucer'
				s.saucer = i
				hold_switch(s, sc.switch, true)
				log(s, 'ball in ' .. sc.name)
				return
			end
		end

		for i, sn in ipairs(tbl.sensors or {}) do
			local dx, dy = b.x - sn[1], b.y - sn[2]
			local inside = (dx * dx + dy * dy) < (sn[3] * sn[3])
			if inside and not s.in_sensor[i] then
				pulse_switch(s, sn.switch, sn.name)
			end
			s.in_sensor[i] = inside
		end

		-- keep the ball on the table
		if b.x < b.r then b.x, b.vx = b.r, math.abs(b.vx) end
		if b.x > tbl.width - b.r then b.x, b.vx = tbl.width - b.r, -math.abs(b.vx) end
		if b.y < b.r then b.y, b.vy = b.r, math.abs(b.vy) end

		-- a ball that has stopped against geometry gets a nudge, as a player would
		local speed2 = b.vx * b.vx + b.vy * b.vy
		if speed2 < 0.25 then
			s.still = (s.still or 0) + 1
			if s.still > 3 * 60 * SUBSTEPS then
				b.vx = b.vx + (math.random() - 0.5) * 40
				b.vy = b.vy - 20 - math.random() * 20
				s.still = 0
				log(s, 'nudge (ball stuck)')
			end
		else
			s.still = 0
		end

		local in_drain_zone = b.y > tbl.drain_y
		if tbl.drain_x then in_drain_zone = in_drain_zone and b.x >= tbl.drain_x[1] and b.x <= tbl.drain_x[2] end
		if in_drain_zone then
			s.state = 'outhole'
			b.vx, b.vy = 0, 0
			b.y = tbl.drain_y
			hold_switch(s, tbl.outhole_switch, true)
			log(s, 'drain, ball in outhole')
		end
	end

	-- --------------------------------------------------------------------
	-- per frame: inputs, outputs, physics, drawing
	-- --------------------------------------------------------------------

	local function update_flippers(s)
		local enabled = s.tbl.flipper_enable == nil or output_on(s, s.tbl.flipper_enable)
		local input = manager.machine.input
		for i, f in ipairs(s.flippers) do
			local want = f.rest
			local pressed = enabled and (input:code_pressed(f.code) or (autopilot and s.auto_flip[i] > 0))
			if pressed then want = f.up end
			local rate = 1400 -- degrees per second
			local delta = want - f.angle
			local move = rate * FRAME_DT
			local prev = f.angle
			if math.abs(delta) <= move then f.angle = want else f.angle = f.angle + (delta > 0 and move or -move) end
			f.omega = math.rad(f.angle - prev) / FRAME_DT
		end
		s.flippers_enabled = enabled
	end

	local function update_autopilot(s)
		local b = s.ball
		for i = 1, #s.flippers do s.auto_flip[i] = math.max(0, s.auto_flip[i] - 1) end
		if not b or s.state ~= 'play' then return end
		local cx = s.tbl.width / 2
		if b.vy > 0 and b.y > s.tbl.length - 9 then
			local i = (b.x < cx) and 1 or 2
			if s.auto_flip[i] == 0 and math.random() < 0.15 then s.auto_flip[i] = 8 end
		end
	end

	local function process_frame()
		local s = sim
		if not s then return end
		local tbl = s.tbl

		update_outputs(s)
		update_pulses(s)
		for k, v in pairs(s.flash) do s.flash[k] = v - 1; if s.flash[k] <= 0 then s.flash[k] = nil end end
		update_autopilot(s)
		update_flippers(s)

		-- drop target resets
		for i, tg in ipairs(tbl.targets or {}) do
			if tg.drop and s.dropped[i] and rose(s, tg.reset) then
				s.dropped[i] = false
			end
		end

		-- serving and the outhole
		for _, name in ipairs(tbl.serve_solenoids or {}) do
			if rose(s, name) and s.state == 'trough' then
				serve(s, name)
			end
		end
		s.saucer_cooldown = math.max(0, s.saucer_cooldown - 1)
		if s.state == 'saucer' then
			local sc = tbl.saucers[s.saucer]
			s.saucer_frames = s.saucer_frames + 1
			-- if the game never fires the kicker (feature not lit) the ball rolls on
			local timeout = s.saucer_frames > (sc.timeout or 6) * 60
			if rose(s, sc.solenoid) or timeout then
				hold_switch(s, sc.switch, false)
				local kick = timeout and (sc.timeout_kick or { 0, 15 }) or sc.kick
				s.ball.vx, s.ball.vy = kick[1], kick[2]
				s.state = 'play'
				s.saucer_cooldown = 30
				log(s, (timeout and 'rolls out of ' or 'kicked out of ') .. sc.name)
			end
		else
			s.saucer_frames = 0
		end
		-- the flipper relay is pulsed during the power-up self test; only a relay that
		-- stays on means a game is in progress
		if s.flippers_enabled then s.relay_frames = s.relay_frames + 1 else s.relay_frames = 0 end
		if tbl.serve_on_flipper_enable and s.state == 'trough' and s.relay_frames == 30 then
			serve(s, 'flippers enabled')
		end
		if s.state == 'outhole' and rose(s, tbl.outhole_solenoid) then
			hold_switch(s, tbl.outhole_switch, false)
			-- on this hardware the outhole kick delivers the ball to the shooter lane
			serve(s, 'outhole kick')
		end
		if s.state == 'trough' and s.relay_frames > 30 then
			s.idle_frames = s.idle_frames + 1
			if s.idle_frames > 4 * 60 then
				serve(s, 'game in progress, no ball')
			end
		else
			s.idle_frames = 0
		end

		if s.state == 'shooter' then
			s.shooter_frames = s.shooter_frames + 1
			local input = manager.machine.input
			if input:code_pressed(s.plunge_code) or (autopilot and s.flippers_enabled) or (s.flippers_enabled and s.shooter_frames > 3 * 60) then
				plunge(s)
			end
		end

		local dt = FRAME_DT / SUBSTEPS
		for i = 1, SUBSTEPS do step(s, dt) end

		if console_log then
			s.log_frames = (s.log_frames or 0) + 1
			if s.log_frames % 180 == 0 and s.ball then
				print(string.format('[pinviz] ball %s at (%.1f, %.1f) v=(%.1f, %.1f)', s.state, s.ball.x, s.ball.y, s.ball.vx, s.ball.vy))
			end
		end
	end

	local function frame_done()
		if sim then sim.draw() end
	end

	-- --------------------------------------------------------------------
	-- drawing
	-- --------------------------------------------------------------------

	local function make_drawer(s)
		local tbl = s.tbl
		local ui = manager.machine.render.ui_container
		local target = manager.machine.render.ui_target

		local C_PANEL, C_FELT, C_EDGE = 0xFF0A0D16, 0xFF12203A, 0xFF3A5A8A
		local C_WALL, C_POST, C_SLING, C_BUMPER = 0xFFD0D8E8, 0xFF9AA4B8, 0xFFFF9A3C, 0xFFFF4A4A
		local C_BUMPER_IN, C_TARGET, C_DROP, C_DOWN = 0xFF7A1A1A, 0xFF5CFF7A, 0xFF4AC8FF, 0x603A6A88
		local C_SENSOR, C_GATE, C_FLIP, C_FLIP_OFF = 0xFF8C8CFF, 0xFF6A6AAA, 0xFFFFD93C, 0xFF6E5C24
		local C_BALL, C_BALL_RIM, C_FLASH = 0xFFF4F4F4, 0xFF9AD0FF, 0xFFFFFFFF
		local C_TEXT, C_TEXT_DIM, C_TITLE = 0xFFE6ECF5, 0xFF8F9BB0, 0xFFFFD93C

		local function flashing(name) return name and s.flash[name] end

		return function()
			local W, H = target.width, target.height
			if W <= 0 or H <= 0 then W, H = 640, 480 end
			local panel_w = 0.5 * W
			local margin = 0.02 * H
			local ppi = math.min((panel_w * 0.72) / tbl.width, (H - 2 * margin) / tbl.length)
			local ox, oy = margin, margin
			local sx, sy = ppi / W, ppi / H
			local function to(x, y) return (ox + x * ppi) / W, (oy + y * ppi) / H end

			-- opaque panel over the layout, then the playfield
			ui:draw_box(0, 0, 0.5, 1, C_PANEL, C_PANEL)
			local ax, ay = to(0, 0)
			local bx, by = to(tbl.width, tbl.length)
			ui:draw_box(ax, ay, bx, by, C_EDGE, C_FELT)

			local function line(x0, y0, x1, y1, c)
				local ux0, uy0 = to(x0, y0)
				local ux1, uy1 = to(x1, y1)
				ui:draw_line(ux0, uy0, ux1, uy1, c)
			end
			local function thick(x0, y0, x1, y1, c, w)
				local dx, dy = x1 - x0, y1 - y0
				local len = math.sqrt(dx * dx + dy * dy)
				if len < 1e-6 then return end
				local nx, ny = -dy / len * w, dx / len * w
				line(x0, y0, x1, y1, c)
				line(x0 + nx, y0 + ny, x1 + nx, y1 + ny, c)
				line(x0 - nx, y0 - ny, x1 - nx, y1 - ny, c)
			end
			local function circle(x, y, r, c, n)
				n = n or 14
				local px, py
				for i = 0, n do
					local a = (i / n) * 2 * math.pi
					local qx, qy = x + r * math.cos(a), y + r * math.sin(a)
					if px then line(px, py, qx, qy, c) end
					px, py = qx, qy
				end
			end
			local function disc(x, y, r, c, rows)
				rows = rows or 8
				for k = -rows, rows - 1 do
					local y0, y1 = y + (k / rows) * r, y + ((k + 1) / rows) * r
					local hw = r * math.sqrt(math.max(0, 1 - ((k + 0.5) / rows) ^ 2))
					local ux0, uy0 = to(x - hw, y0)
					local ux1, uy1 = to(x + hw, y1)
					ui:draw_box(ux0, uy0, ux1, uy1, c, c)
				end
			end

			for _, w in ipairs(tbl.walls) do line(w[1], w[2], w[3], w[4], C_WALL) end
			for _, p in ipairs(tbl.posts or {}) do disc(p[1], p[2], p[3], C_POST, 4) end
			for _, g in ipairs(tbl.gates or {}) do line(g[1], g[2], g[3], g[4], C_GATE) end

			for _, sl in ipairs(tbl.slings or {}) do
				thick(sl[1], sl[2], sl[3], sl[4], flashing(sl.name) and C_FLASH or C_SLING, 0.12)
			end
			for _, bp in ipairs(tbl.bumpers or {}) do
				local hot = flashing(bp.name)
				disc(bp[1], bp[2], bp[3], hot and C_BUMPER or C_BUMPER_IN, 10)
				circle(bp[1], bp[2], bp[3], hot and C_FLASH or C_BUMPER, 16)
				disc(bp[1], bp[2], bp[3] * 0.35, hot and C_FLASH or C_BUMPER, 4)
			end
			for i, tg in ipairs(tbl.targets or {}) do
				local c
				if tg.drop and s.dropped[i] then c = C_DOWN
				elseif flashing(tg.name) then c = C_FLASH
				else c = tg.drop and C_DROP or C_TARGET end
				thick(tg[1], tg[2], tg[3], tg[4], c, 0.08)
			end
			for _, sn in ipairs(tbl.sensors or {}) do
				circle(sn[1], sn[2], sn[3] * 0.6, flashing(sn.name) and C_FLASH or C_SENSOR, 10)
			end
			for _, sc in ipairs(tbl.saucers or {}) do
				circle(sc[1], sc[2], sc[3], flashing(sc.name) and C_FLASH or C_SLING, 12)
			end

			for _, f in ipairs(s.flippers) do
				local x0, y0, x1, y1 = flipper_ends(f)
				local c = s.flippers_enabled and C_FLIP or C_FLIP_OFF
				thick(x0, y0, x1, y1, c, 0.22)
				disc(x0, y0, 0.32, c, 4)
			end

			if s.ball then
				local b = s.ball
				disc(b.x, b.y, b.r, C_BALL, 8)
				circle(b.x, b.y, b.r, C_BALL_RIM, 12)
			end

			-- text column to the right of the table
			local tx = bx + 0.012
			local lh = 0.03
			ui:draw_text(tx, ay, 'pinviz ' .. tbl.name, C_TITLE)
			ui:draw_text(tx, ay + lh, 'ball ' .. s.state, C_TEXT)
			ui:draw_text(tx, ay + 2 * lh, 'flippers ' .. (s.flippers_enabled and 'on' or 'off'), C_TEXT)
			local y = ay + 4 * lh
			for i = 1, math.min(#s.events, 14) do
				local e = s.events[i]
				if #e > 30 then e = e:sub(1, 30) end
				ui:draw_text(tx, y, e, i == 1 and C_TEXT or C_TEXT_DIM)
				y = y + lh
			end
			ui:draw_text(tx, by - lh, 'Shift flip  Space plunge', C_TEXT_DIM)
		end
	end

	-- --------------------------------------------------------------------
	-- lifecycle
	-- --------------------------------------------------------------------

	local function start()
		sim = nil
		local sysname = manager.machine.system.name
		local tbl = load_table(sysname)
		if not tbl then
			emu.print_info('pinviz: no table for ' .. sysname)
			return
		end
		math.randomseed(1)
		local s = {
			tbl = tbl, ball = nil, state = 'trough', events = {}, pulses = {}, outputs = {},
			dropped = {}, in_sensor = {}, flippers = {}, auto_flip = {}, idle_frames = 0,
			shooter_frames = 0, flippers_enabled = false, saucer_cooldown = 0, saucer_frames = 0, relay_frames = 0,
			flash = {},
		}
		local input = manager.machine.input
		for i, f in ipairs(tbl.flippers) do
			s.flippers[i] = { pivot = f.pivot, length = f.length, rest = f.rest, up = f.up,
				angle = f.rest, omega = 0, code = input:code_from_token(f.key) }
			s.auto_flip[i] = 0
		end
		s.plunge_code = input:code_from_token('KEYCODE_SPACE')
		for _, name in ipairs(tbl.serve_solenoids or {}) do watch_output(s, name) end
		watch_output(s, tbl.outhole_solenoid)
		if tbl.flipper_enable then watch_output(s, tbl.flipper_enable) end
		for _, tg in ipairs(tbl.targets or {}) do if tg.reset then watch_output(s, tg.reset) end end
		for _, sc in ipairs(tbl.saucers or {}) do watch_output(s, sc.solenoid) end
		if tbl.solenoid_names then
			for idx, _ in pairs(tbl.solenoid_names) do watch_output(s, 'solenoid' .. idx) end
		end
		s.draw = make_drawer(s)
		sim = s
		emu.print_info('pinviz: table ' .. tbl.name .. ' loaded' .. (autopilot and ' (autopilot)' or ''))
	end

	local function stop()
		if sim then
			for _, p in pairs(sim.pulses) do p.field:clear_value() end
			hold_switch(sim, sim.tbl.outhole_switch, false)
			for _, sc in ipairs(sim.tbl.saucers or {}) do hold_switch(sim, sc.switch, false) end
		end
		sim = nil
	end

	start_subscription = emu.add_machine_reset_notifier(start)
	stop_subscription = emu.add_machine_stop_notifier(stop)
	frame_subscription = emu.add_machine_frame_notifier(process_frame)
	emu.register_frame_done(frame_done, 'pinviz')
end

return exports
