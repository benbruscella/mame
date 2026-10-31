-- license:BSD-3-Clause
-- copyright-holders:Ben Bruscella
--
-- A small web server for pinviz: serves the page in web/ and talks to it over a
-- WebSocket, with nothing to install.
--
-- MAME's sockets take one connection at a time and stop listening while they have
-- it, so the page and the session get a port each. The page's port is free again
-- straight away, which lets a reload work while the old session is still ending.
-- A socket that is listening reads the same as a connection saying nothing, and a
-- browser will open a connection speculatively, so either port starts again now and
-- then until it is spoken to.
--
-- The page asks for each update and MAME writes only in reply. MAME ends with
-- SIGPIPE if it writes to a socket whose reader has gone, and a plugin can neither
-- ignore the signal nor see the disconnect, because a closed socket reads the same
-- as a quiet one. A page that has gone asks for nothing, so nothing is written to it.

local M = {}

local PROBE_FRAMES = 60       -- how long a socket waits to be spoken to before starting again
local QUIET_FRAMES = 300      -- a session has this long between messages

local function sha1(msg)
	local function rol(x, n) return ((x << n) | (x >> (32 - n))) & 0xffffffff end
	local h0, h1, h2, h3, h4 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0
	local padded = msg .. '\128' .. string.rep('\0', (55 - #msg) % 64) .. string.pack('>I8', #msg * 8)
	for chunk = 1, #padded, 64 do
		local w = { string.unpack('>I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4', padded, chunk) }
		for i = 17, 80 do w[i] = rol(w[i - 3] ~ w[i - 8] ~ w[i - 14] ~ w[i - 16], 1) end
		local a, b, c, d, e = h0, h1, h2, h3, h4
		for i = 1, 80 do
			local f, k
			if i <= 20 then f, k = (b & c) | (~b & d), 0x5a827999
			elseif i <= 40 then f, k = b ~ c ~ d, 0x6ed9eba1
			elseif i <= 60 then f, k = (b & c) | (b & d) | (c & d), 0x8f1bbcdc
			else f, k = b ~ c ~ d, 0xca62c1d6 end
			local t = (rol(a, 5) + (f & 0xffffffff) + e + k + w[i]) & 0xffffffff
			e, d, c, b, a = d, c, rol(b, 30), a, t
		end
		h0, h1, h2, h3, h4 = (h0 + a) & 0xffffffff, (h1 + b) & 0xffffffff, (h2 + c) & 0xffffffff, (h3 + d) & 0xffffffff, (h4 + e) & 0xffffffff
	end
	return string.pack('>I4I4I4I4I4', h0, h1, h2, h3, h4)
end

local function base64(data)
	local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = (a << 16) | ((b or 0) << 8) | (c or 0)
		local function ch(shift) local v = ((n >> shift) & 63) + 1; return chars:sub(v, v) end
		out[#out + 1] = ch(18) .. ch(12) .. (b and ch(6) or '=') .. (c and ch(0) or '=')
	end
	return table.concat(out)
end

local function frame_text(text)
	local n = #text
	if n < 126 then return string.pack('>BB', 0x81, n) .. text end
	if n < 65536 then return string.pack('>BBI2', 0x81, 126, n) .. text end
	return string.pack('>BBI8', 0x81, 127, n) .. text
end

local TYPES = { html = 'text/html; charset=utf-8', js = 'text/javascript', css = 'text/css', jpg = 'image/jpeg', jpeg = 'image/jpeg', png = 'image/png' }

local function listener(port)
	local self = { received = '', idle = 0 }

	function self.open()
		self.socket = emu.file('', 7)
		self.failed = self.socket:open('socket.127.0.0.1:' .. port) ~= nil
		self.received, self.idle = '', 0
	end

	function self.restart()
		self.socket:close()
		self.open()
	end

	function self.read()
		repeat
			local data = self.socket:read(4096)
			self.received = self.received .. data
		until #data == 0
	end

	-- the head of a request, once all of it has arrived
	function self.request()
		local stop = self.received:find('\r\n\r\n', 1, true)
		if not stop then return nil end
		local head = self.received:sub(1, stop + 3)
		self.received = self.received:sub(stop + 4)
		return head
	end

	-- after a while with nothing said, start listening again
	function self.wait(frames)
		self.idle = self.idle + 1
		if self.idle > frames then self.restart() end
	end

	self.open()
	return self
end

-- the page is on port, and the session on the port after it
function M.new(port, root)
	local self = { session = false }
	local page, live = listener(port), listener(port + 1)
	self.listening = not page.failed and not live.failed

	local function serve_file(path)
		if path == '/' then path = '/index.html' end
		local ext, name
		if path == '/playfield' and self.art then
			ext, name = self.art:match('%.(%w+)$'), self.art
		else
			ext, name = path:match('^/[%w_-]+%.(%w+)$'), root .. '/web' .. path
		end
		local file = ext and TYPES[ext] and io.open(name, 'rb')
		if not file then
			page.socket:write('HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
			return
		end
		local body = file:read('a')
		file:close()
		page.socket:write(string.format('HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n', TYPES[ext], #body) .. body)
	end

	local function poll_page()
		page.read()
		local head = page.request()
		if head then
			serve_file(head:match('^GET ([^ ?]+)') or '')
			page.restart()
		else
			page.wait(PROBE_FRAMES)
		end
	end

	local function handshake(head)
		local key = head:match('[Ss]ec%-[Ww]eb[Ss]ocket%-[Kk]ey: *([^\r\n]+)')
		if not key then return false end
		local accept = base64(sha1(key .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
		live.socket:write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ' .. accept .. '\r\n\r\n')
		return true
	end

	-- reads the page's messages; true if there was at least one, nil if it said goodbye
	local function read_messages(on_message)
		local spoke = false
		while #live.received >= 2 do
			local received = live.received
			local b0, b1 = received:byte(1, 2)
			local len, at = b1 & 0x7f, 3
			if len == 126 then
				if #received < 4 then break end
				len, at = string.unpack('>I2', received, 3), 5
			elseif len == 127 then
				if #received < 10 then break end
				len, at = string.unpack('>I8', received, 3), 11
			end
			if #received < at + 3 + len then break end
			local mask = { received:byte(at, at + 3) }
			local data = { received:byte(at + 4, at + 3 + len) }
			for i = 1, len do data[i] = data[i] ~ mask[(i - 1) % 4 + 1] end
			live.received = received:sub(at + 4 + len)
			local opcode = b0 & 0x0f
			if opcode == 8 then
				return nil
			elseif opcode == 1 then
				spoke = true
				on_message(string.char(table.unpack(data)))
			end
		end
		return spoke
	end

	local function end_session()
		self.session = false
		live.restart()
	end

	-- on_open() gives the first message of a session, on_message(text) takes each
	-- message from the page, and on_update() gives the reply to its latest one
	function self.poll(on_open, on_message, on_update)
		if not self.listening then return end
		poll_page()
		live.read()
		if not self.session then
			local head = live.request()
			if head and handshake(head) then
				self.session = true
				live.idle = 0
				live.socket:write(frame_text(on_open()))
			elseif head then
				live.restart()
			else
				live.wait(PROBE_FRAMES)
			end
			return
		end
		local spoke = read_messages(on_message)
		if spoke == nil then
			end_session()
		elseif spoke then
			live.idle = 0
			local reply = on_update()
			if reply then live.socket:write(frame_text(reply)) end
		else
			live.idle = live.idle + 1
			if live.idle > QUIET_FRAMES then end_session() end
		end
	end

	return self
end

return M
