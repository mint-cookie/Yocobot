if Yocobot ~= nil then
	Gelatobot = Yocobot:new(1)

	Gelatobot.name = "GEL"
	Gelatobot.author = "medibot"
	
	function Gelatobot:new(p)
		local o = {player_index = p, joypad_instructions = {}, instruction_index  = 1, current_target_index = 0, current_target_alignment = "x", current_target_cookie = 0, current_target_density = 0, current_target_position = {row = 0, col = 0}, cursor_pos = {row = 3, col = 3}, current_move_start = {row = 0, col = 0}, viewing_match_toggler = 0, local_board = {}}
		setmetatable(o, self)
		self.__index = self
		return o
	end
	
	function Gelatobot:get_next_input()
		local command = {}
		if self:experiencing_misery() or self:abandon_ship() then
			-- zaffo!
			self:reset_move_vars()
			command = {A=nil, B=true}
		elseif self.joypad_instructions[self.instruction_index] then
			command = self.joypad_instructions[self.instruction_index]
			self.instruction_index = self.instruction_index + 1
		elseif self:is_viewing_match() then -- nothin doin
			command = {A=nil, B=true}
		else
			self.local_board = self:read_board()
			if self.current_target_cookie == 0 then
				self:find_move()
			end
			self:find_slide()
			self:define_instructions()
		end
		
		return command
	end
	
	function Gelatobot:get_row_pop(row, t)
		result = 0
		for k = 1, 5 do
			if self.local_board[k][row] == t then
				result = result + 1
			end
		end
		return result
	end
	
	function Gelatobot:get_col_pop(col, t)
		result = 0
		for k = 1, 5 do
			if self.local_board[col][k] == t then
				result = result + 1
			end
		end
		return result
	end
	
	function Gelatobot:find_move()
		self:reset_move_vars()
		local piece_population = {0, 0, 0, 0, 0, [13]=0}
		for i = 1, 5 do
			for j = 1, 5 do
				piece_population[self.local_board[i][j]] = piece_population[self.local_board[i][j]] + 1
			end
		end
		for i = 1, 5 do
			for piece_type, piece_pop in pairs(piece_population) do
				if piece_pop > 4 then
					row_density = self:get_row_pop(i, piece_type)
					col_density = self:get_col_pop(i, piece_type)
					if row_density >= col_density and row_density > self.current_target_density then
						self.current_target_density = row_density
						self.current_target_alignment = "r"
						self.current_target_index = i
						self.current_target_cookie = piece_type
					elseif col_density > self.current_target_density then
						self.current_target_density = col_density
						self.current_target_alignment = "c"
						self.current_target_index = i
						self.current_target_cookie = piece_type
					end
				end
			end
		end
	end
	
	function Gelatobot:find_slide()
		self:reset_slide_vars()
		if self.current_target_alignment == "r" then
			for i = 1, 5 do
				if self.local_board[i][self.current_target_index] ~= self.current_target_cookie then
					self.current_target_position.row = self.current_target_index
					self.current_target_position.col = i
					break
				end
			end
			-- find a cookie to put into that spot. the cookie needs to not already be in our target row/col.
			for i = 1, 5 do
				if i ~= self.current_target_index then
					for j = 0, 2 do
						-- minor optimization: start search at target position's col/row and move outward
						colA = ((self.current_target_position.col - j) % 5)
						colB = ((self.current_target_position.col + j) % 5)
						if colA == 0 then colA = 5 end
						if colB == 0 then colB = 5 end
						if self.local_board[colA][i] == self.current_target_cookie then
							self.current_move_start.col = colA
							self.current_move_start.row = i
							break
						end
						if colB ~= colA and self.local_board[colB][i] == self.current_target_cookie then
							self.current_move_start.col = colB
							self.current_move_start.row = i
							break
						end
					end
				end
				if self.current_move_start.col ~= 0 then
					break
				end
			end
		elseif self.current_target_alignment == "c" then
			for i = 1, 5 do
				if self.local_board[self.current_target_index][i] ~= self.current_target_cookie then
					self.current_target_position.row = i
					self.current_target_position.col = self.current_target_index
					break
				end
			end
			-- find a cookie to put into that spot. the cookie needs to not already be in our target row/col.
			for i = 1, 5 do
				if i ~= self.current_target_index then
					for j = 0, 2 do
						-- minor optimization: start search at target position's col/row and move outward
						rowA = ((self.current_target_position.row - j) % 5)
						rowB = ((self.current_target_position.row + j) % 5)
						if rowA == 0 then rowA = 5 end
						if rowB == 0 then rowB = 5 end
						if self.local_board[i][rowA] == self.current_target_cookie then
							self.current_move_start.col = i
							self.current_move_start.row = rowA
							break
						end
						if rowB ~= rowA and self.local_board[i][rowB] == self.current_target_cookie then
							self.current_move_start.col = i
							self.current_move_start.row = rowB
							break
						end
					end
				end
				if self.current_move_start.row ~= 0 then
					break
				end
			end
		else
			--console.output("invalid target alignment")
		end
	end
	
	function Gelatobot:define_instructions()
		self.instruction_index = 1
		self.joypad_instructions = {}
		-- move cursor to correct position
		-- when assembling a row:
		-- the column should be the target position's column
		-- the row should be the cookie's current row
		-- when assembling a col:
		-- the column should be the cookie's current column
		-- the row should be the target position's row
		-- move cursor horizontally
		column_diff = 0
		if self.current_target_alignment == "r" then
			column_diff = (self.cursor_pos.col - self.current_target_position.col) % 5
		else
			column_diff = (self.cursor_pos.col - self.current_move_start.col) % 5
		end
		if column_diff == 1 then -- move cursor left once
			self:move_cursor_left(1)
		elseif column_diff == 2 then -- move cursor left twice
			self:move_cursor_left(2)
		elseif column_diff == 3 then -- move cursor right twice
			self:move_cursor_right(2)
		elseif column_diff == 4 then -- move cursor right once
			self:move_cursor_right(1)
		end
		-- move cursor vertically
		row_diff = 0
		if self.current_target_alignment == "r" then
			row_diff = (self.cursor_pos.row - self.current_move_start.row) % 5
		else
			row_diff = (self.cursor_pos.row - self.current_target_position.row) % 5
		end
		if row_diff == 1 then -- move cursor down once
			self:move_cursor_down(1)
		elseif row_diff == 2 then -- move cursor down twice
			self:move_cursor_down(2)
		elseif row_diff == 3 then -- move cursor up twice
			self:move_cursor_up(2)
		elseif row_diff == 4 then -- move cursor up once
			self:move_cursor_up(1)
		end
		-- slide piece into position
		column_diff = (self.current_move_start.col - self.current_target_position.col) % 5
		row_diff = (self.current_move_start.row - self.current_target_position.row) % 5
		-- when matching a row, slide horizontally then vertically
		-- when matching a column, slide vertically then horizontally
		if self.current_target_alignment == "r" then
			if column_diff == 1 then -- slide left once
				self:slide_left(1)
			elseif column_diff == 2 then -- slide left twice
				self:slide_left(2)
			elseif column_diff == 3 then -- slide right twice
				self:slide_right(2)
			elseif column_diff == 4 then -- slide right once
				self:slide_right(1)
			end
			if row_diff == 1 then -- slide down once
				self:slide_down(1)
			elseif row_diff == 2 then -- slide down twice
				self:slide_down(2)
			elseif row_diff == 3 then -- slide up twice
				self:slide_up(2)
			elseif row_diff == 4 then -- slide up once
				self:slide_up(1)
			end
		else
			if row_diff == 1 then -- slide down once
				self:slide_down(1)
			elseif row_diff == 2 then -- slide down twice
				self:slide_down(2)
			elseif row_diff == 3 then -- slide up twice
				self:slide_up(2)
			elseif row_diff == 4 then -- slide up once
				self:slide_up(1)
			end
			if column_diff == 1 then -- slide left once
				self:slide_left(1)
			elseif column_diff == 2 then -- slide left twice
				self:slide_left(2)
			elseif column_diff == 3 then -- slide right twice
				self:slide_right(2)
			elseif column_diff == 4 then -- slide right once
				self:slide_right(1)
			end
		end
		self:buffer_input(2) -- arbitrary guess at buffer for safety
	end
	
	function Gelatobot:move_cursor_left(t)
		for i = 1, t do
			for z = 1, 5 do
				table.insert(self.joypad_instructions, {Left=true, A=nil, B=true})
			end
			table.insert(self.joypad_instructions, {Left=nil, A=nil, B=true})
		end
	end
	
	function Gelatobot:move_cursor_down(t)
		for i = 1, t do
			for z = 1, 5 do
				table.insert(self.joypad_instructions, {Down=true, A=nil, B=true})
			end
			table.insert(self.joypad_instructions, {Down=nil, A=nil, B=true})
		end
	end
	
	function Gelatobot:move_cursor_right(t)
		for i = 1, t do
			for z = 1, 4 do
				table.insert(self.joypad_instructions, {Right=true, A=nil, B=true})
			end
			table.insert(self.joypad_instructions, {Right=nil, A=nil, B=true})
		end
	end
	
	function Gelatobot:move_cursor_up(t)
		for i = 1, t do
			for z = 1, 4 do
				table.insert(self.joypad_instructions, {Up=true, A=nil, B=true})
			end
			table.insert(self.joypad_instructions, {Up=nil, A=nil, B=true})
		end
	end
	
	function Gelatobot:slide_left(t)
		for i = 1, t do
			for z = 1, 4 do
				table.insert(self.joypad_instructions, {Left=true, A=true, B=nil})
			end
			for z = 1, 9 do
				table.insert(self.joypad_instructions, {Left=nil, A=nil, B=true})
			end
		end
	end
	
	function Gelatobot:slide_down(t)
		for i = 1, t do
			for z = 1, 4 do
				table.insert(self.joypad_instructions, {Down=true, A=true, B=nil})
			end
			for z = 1, 9 do
				table.insert(self.joypad_instructions, {Down=nil, A=nil, B=true})
			end
		end
	end
	
	function Gelatobot:slide_right(t)
		for i = 1, t do
			for z = 1, 4 do
				table.insert(self.joypad_instructions, {Right=true, A=true, B=nil})
			end
			for z = 1, 9 do
				table.insert(self.joypad_instructions, {Right=nil, A=nil, B=true})
			end
		end
	end
	
	function Gelatobot:slide_up(t)
		for i = 1, t do
			for z = 1, 4 do
				table.insert(self.joypad_instructions, {Up=true, A=true, B=nil})
			end
			for z = 1, 9 do
				table.insert(self.joypad_instructions, {Up=nil, A=nil, B=true})
			end
		end
	end
	
	function Gelatobot:buffer_input(t)
		for i = 1, t do
			table.insert(self.joypad_instructions, {A=nil, B=true})
		end
	end
	
	function Gelatobot:experiencing_misery()
		return self:read_panic() + self:read_slave() > 0
	end
	
	function Gelatobot:abandon_ship() -- yeahhhhhhh about this
		return self:read_position(5, 5) == 0
	end
	
	function Gelatobot:is_viewing_match()
		local test_set = {}
		for i = 1, 5 do
			test_set = self:read_row(i)
			if self:is_set_match(test_set) then
				if self.viewing_match_toggler == 0 then
					self.viewing_match_toggler = 1
				end
				return true
			end
			test_set = self:read_col(i)
			if self:is_set_match(test_set) then
				if self.viewing_match_toggler == 0 then
					self.viewing_match_toggler = 1
				end
				return true
			end
		end
		if self.viewing_match_toggler == 1 then
			self.instruction_index = 1
			self.joypad_instructions = {}
			self:buffer_input(6)
			self.viewing_match_toggler = 0
			return true
		end
		return false
	end
	
	function Gelatobot:read_row(row)
		local r = {}
		for i = 1, 5 do
			r[i] = self:read_position(i, row)
		end
		return r
	end
	
	function Gelatobot:read_col(col)
		local c = {}
		for i = 1, 5 do
			c[i] = self:read_position(col, i)
		end
		return c
	end
	
	function Gelatobot:reset_move_vars()
		self.current_target_index = 0
		self.current_target_alignment = "x"
		self.current_target_cookie = 0
		self.current_target_density = 0
		self.current_target_position.row = 0
		self.current_target_position.col = 0
		self.current_move_start.row = 0
		self.current_move_start.col = 0
	end
	
	function Gelatobot:reset_slide_vars()
		self.current_target_position.row = 0
		self.current_target_position.col = 0
		self.current_move_start.row = 0
		self.current_move_start.col = 0
		self.cursor_pos.col, self.cursor_pos.row = self:read_cursor()
	end

	function Gelatobot:is_set_match(test_set)
		local match_cookie = 0
		for j = 1, 5 do
			if match_cookie == 0 then -- set the first entry as the thing we're looking for
				match_cookie = test_set[j]
			elseif test_set[j] ~= 0 and test_set[j] ~= match_cookie then -- if it's not 0 and not equal to our target, it can't be part of a valid set
				match_cookie = -1
			end
		end
		if match_cookie ~= -1 then
			return true
		end
		return false
	end
	
	
	return Gelatobot
end