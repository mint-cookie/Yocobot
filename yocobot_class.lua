local Yocobot = {memory_addresses = { [1] = {["board"] = 0x300, ["cursor_x"] = 0x373, ["cursor_y"] = 0x374, ["fuse"] = 0x940, ["panic"] = 0x952, ["slave"] = 0x954, ["name"] = 0x1146}, [2] = {["board"] = 0x400, ["cursor_x"] = 0x473, ["cursor_y"] = 0x474, ["fuse"] = 0xA40, ["panic"] = 0xA52, ["slave"] = 0xA54, ["name"] = 0x1166}}, player_index = 0}

function Yocobot:new(p)
	local o = {player_index = p}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Yocobot:get_next_input()
	return {}
end

function Yocobot:read_fuse()
	return mainmemory.readbyte(self.memory_addresses[self.player_index]["fuse"])
end

function Yocobot:read_panic()
	return mainmemory.read_u16_le(self.memory_addresses[self.player_index]["panic"])
end

function Yocobot:read_slave()
	return mainmemory.read_u16_le(self.memory_addresses[self.player_index]["slave"])
end

function Yocobot:read_cursor()
	return math.ceil((mainmemory.readbyte(self.memory_addresses[self.player_index]["cursor_x"]) + 8) / 16), math.ceil((mainmemory.readbyte(self.memory_addresses[self.player_index]["cursor_y"]) + 8) / 16)
end

function Yocobot:read_board()
	local b = {}
	for i = 1, 5 do
		b[i] = {}
		for j = 1, 5 do
			b[i][j] = mainmemory.readbyte(self.memory_addresses[self.player_index]["board"] + (i - 1) + 8 * (j - 1))
		end
	end
	return b
end

function Yocobot:read_position(x, y)
	return mainmemory.readbyte(self.memory_addresses[self.player_index]["board"] + (x - 1) + 8 * (y - 1))
end

return Yocobot