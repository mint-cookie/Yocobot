local piece_lookup = { [0] = "empty", [1] = "heart", [2] = "bloom", [3] = "green", [4] = "check", [5] = "torus", [13] = "yoshi" }
if Gelatobot ~= nil then
	Devilbot = Gelatobot:new(1)
	Devilbot.name = "DVL"
	Devilbot.author = "medibot"
	
	function Devilbot:formulate_full_combo()
		self.local_board = self:read_board()
		local piece_population = {0, 0, 0, 0, 0, [13] = 0}
		for i = 1, 5 do
			for j = 1, 5 do
				piece_population[self.local_board[i][j]] = piece_population[self.local_board[i][j]] + 1
			end
		end
		self.combo_plan = self:full_combo_step(5, 5, piece_population, {})
	end
	
	function Devilbot:exclude_piece(plan, alignment)
		for i = table.getn(plan), 1, -1 do
			if plan[i].a == alignment then
				return plan[i].t
			end
		end
		return -1
	end
	
	function Devilbot:full_combo_step(cols, rows, pop, plan)
		-- if cols or rows == 0, we have found success.
		if cols == 0 or rows == 0 then
			return plan
		end
		-- if there is exactly 1 left of a piece type, this path is no good
		for _, piece_pop in pairs(pop) do
			if piece_pop == 1 then
				return nil
			end
		end
		-- try to use each piece
		local plan_result = nil
		for piece_type, piece_pop in pairs(pop) do
			if self:exclude_piece(plan, 'c') ~= piece_type and self:exclude_piece(plan, 'r') ~= piece_type then
				-- try making a row clear
				if cols > 1 and piece_pop >= cols then
					pop[piece_type] = pop[piece_type] - cols
					table.insert(plan, {['t'] = piece_type, ['q'] = cols, ['a'] = 'r'})
					plan_result = self:full_combo_step(cols, rows - 1, pop, plan)
					pop[piece_type] = pop[piece_type] + cols
					if plan_result ~= nil then
						return plan_result
					end
					table.remove(plan)
				end
				-- try making a col clear
				if rows > 1 and piece_pop >= rows then
					pop[piece_type] = pop[piece_type] - rows
					table.insert(plan, {['t'] = piece_type, ['q'] = rows, ['a'] = 'c'})
					plan_result = self:full_combo_step(cols - 1, rows, pop, plan)
					pop[piece_type] = pop[piece_type] + rows
					if plan_result ~= nil then
						return plan_result
					end
					table.remove(plan)
				end
			end
		end
		-- return something, i guess
		return nil
	end
	
	function Devilbot:reset_combo_vars()
		self.combo_plan_index = table.getn(self.combo_plan)
		self.cursor_limit_up = 5
		self.cursor_limit_right = 5
	end
	
	function Devilbot:consec(b, t, q, a, work, o)
		local best_consec = 0
		local start_point = 0
		local temp_best = 0
		local up_count = 0
		local down_count = 0
		
		if a == 'r' then
			if b[1][work] == t and b[5][work] == t then
				-- wrap it (be sure to check for the full five consecutively)
				best_consec = 2 -- we've already got two in a row from the if statement
				for i = 2, 3 do
					if b[i][work] == t then
						best_consec = best_consec + 1
						start_point = i
					else
						break
					end
				end
				if b[4][work] == t then
					best_consec = best_consec + 1
					start_point = 4
				else
					start_point = 5
				end
			else
				-- don't wrap it
				for i = 1, 5 do
					if b[i][work] == t then
						temp_best = temp_best + 1
					else
						if best_consec < temp_best then
							best_consec = temp_best
							start_point = i - best_consec
						elseif best_consec == temp_best then
							-- break tie on origin proximity: if new one is closer to origin, prefer it
							if math.abs(i - best_consec - o) < math.abs(start_point - o) then
								start_point = i - best_consec
							end
						end
						temp_best = 0
					end
				end
			end
		else
			if b[work][1] == t and b[work][5] == t then
				-- wrap it
				best_consec = 2
				for i = 2, 3 do
					if b[work][i] == t then
						best_consec = best_consec + 1
						start_point = i
					else
						break
					end
				end
				if b[work][4] == t then
					best_consec = best_consec + 1
					start_point = 4
				else
					start_point = 5
				end
			else
				-- don't wrap it
				for i = 1, 5 do
					if b[work][i] == t then
						temp_best = temp_best + 1
					else
						if best_consec < temp_best then
							best_consec = temp_best
							start_point = i - best_consec
						elseif best_consec == temp_best then
							-- break tie on origin proximity: if new one is closer to origin, prefer it
							if math.abs(i - best_consec - o) < math.abs(start_point - o) then
								start_point = i - best_consec
							end
						end
						temp_best = 0
					end
				end
			end
		end
		if best_consec < temp_best then
			best_consec = temp_best
			start_point = 6 - best_consec
		end
		
		--console.log(string.format("in %s%d we found %d consecutive pieces of type %s", a, work, best_consec, piece_lookup[t]))
		return best_consec, start_point
		--return best_consec
	end
	
	function Devilbot:perform_slide(alignment, index, direction)
		--console.log(string.format("DEBUG - perform slide: %s %d is sliding %d space(s)", alignment == 'r' and "row" or "col", index, direction))
		local mov = 0
		self.cursor_pos.col, self.cursor_pos.row = self:read_cursor()
		while direction > 2 do
			direction = direction - 5
		end
		while direction < -2 do
			direction = direction + 5
		end
		if direction == 0 then
			return
		end
		if alignment == 'r' then
			mov = (index - self.cursor_pos.row) % 5
			if mov <= 2 then
				self:move_cursor_up(mov)
			elseif mov > 2 then
				self:move_cursor_down(5 - mov)
			end
			if direction > 0 then
				self:slide_right(direction)
			elseif direction < 0 then
				self:slide_left(direction * -1)
			end
		else
			mov = (index - self.cursor_pos.col) % 5
			if mov <= 2 then
				self:move_cursor_right(mov)
			elseif mov > 2 then
				self:move_cursor_left(5 - mov)
			end
			if direction > 0 then
				self:slide_up(direction)
			elseif direction < 0 then
				self:slide_down(direction * -1)
			end
		end
		self:buffer_input(3)
	end
	
	function Devilbot:define_combo_instructions()
		self.instruction_index = 1
		self.joypad_instructions = {}
	
		local consec_pieces = 0
		local consec_start = 0
		local step = self.combo_plan[self.combo_plan_index]
		
		
		
		if step.a == 'r' then
			consec_pieces, consec_start = self:consec(self.local_board, step.t, step.q, step.a, self.cursor_limit_up, 6 - step.q)
			if consec_pieces >= step.q then
				-- we have sufficient consecutive pieces. is the setup complete or not?
				if consec_start <= (6 - step.q) and (consec_start + consec_pieces - step.q) >= (6 - step.q) then
					-- this row's setup is complete
					--console.log(string.format("row for step %d complete.", self.combo_plan_index))
					self.cursor_limit_right = 5 - step.q
					self.cursor_limit_up = self.cursor_limit_up - 1
					--console.log(string.format("new cursor limits: %d, %d", self.cursor_limit_right, self.cursor_limit_up))
					self.combo_plan_index = self.combo_plan_index - 1
				else
					-- row has enough pieces, we need a horizontal slide to finish it off
					local h_move = (consec_start - (6 - step.q)) % 5
					if h_move == 0 then
						--console.log(string.format("WARNING: in combo step %d detected insufficient consecutive pieces, but then determined no horizontal movement necessary.", self.combo_plan_index))
					elseif h_move > 2 then
						-- slide 5 - h_move
						self:perform_slide('r', self.cursor_limit_up, 5 - h_move)
					else
						-- slide -h_move
						self:perform_slide('r', self.cursor_limit_up, h_move * -1)
					end
				end
			else
				-- insufficient pieces. get more pieces.
				-- so we arrange this in kind of a goofy and rarely optimal way but it's easy as heck to write so woooo *takes shirt off and spins it above head*
				-- basically we arrange it starting with the piece that will end up furthest right,
				-- because we shove pieces one at a time into the spots where our row ends up
				local did_slide = false
				if consec_pieces > 0 then
					-- make sure that the first spot is our consec_start
					-- this whole block looks similar to what we do when we have enough pieces but they need a horizontal move
					-- maybe i can actually reuse code or something?
					local h_move = (consec_start - (6 - step.q)) % 5
					--console.log(string.format("insufficient pieces, h_move: %d", h_move))
					--if self.local_board[6 - step.q][self.cursor_limit_up] ~= step.t then
						if h_move == 0 then
							--console.log(string.format("WARNING: in combo step %d detected wrong piece in work start location %d, %d, but then determined no horizontal movement necessary.", self.combo_plan_index, 6 - step.q, self.cursor_limit_up))
						elseif h_move > 2 then
							-- slide 5 - h_move
							self:perform_slide('r', self.cursor_limit_up, 5 - h_move)
							did_slide = true
						else
							-- slide -h_move
							self:perform_slide('r', self.cursor_limit_up, h_move * -1)
							did_slide = true
						end
					--end
				end
				if consec_pieces == 0 or not did_slide then
					-- we might have the pieces we need in this row but they're not all adjacent.
					-- move it out of the row so that we can work with it.
					local got_from_row = false
					for j = 5 - step.q - 1, 1, -1 do
						if self.local_board[j][self.cursor_limit_up] == step.t then
							self:perform_slide('c', j, -1)
							got_from_row = true
							break
						end
					end
					if not got_from_row then
						-- wrangle the extra piece from somewhere else
						local target_spot = {col = self.cursor_limit_right, row = self.cursor_limit_up}
						local got_piece = false
						-- special case, first piece has the whole board unlimited but we don't actually want to shove things at 5,5
						if target_spot.col == 5 and target_spot.row == 5 then
							target_spot.col = 5 - step.q
						end
						--console.log(string.format("DEBUG: target_spot is %d, %d", target_spot.col, target_spot.row))
						-- easy case: there's a piece we want in the target spot's column
						for j = 1, 2 do
							if self.local_board[target_spot.col][(target_spot.row - j - 1) % 5 + 1] == step.t then
								self:perform_slide('c', target_spot.col, j)
								got_piece = true
								break
							elseif self.local_board[target_spot.col][(target_spot.row + j - 1) % 5 + 1] == step.t then
								self:perform_slide('c', target_spot.col, j * -1)
								got_piece = true
								break
							end
						end
						-- decent case: piece is in a row that is within the cursor bounds (but not in our assembly row, because we've already checked for that)
						if not got_piece then
							for j = self.cursor_limit_up - 1, 1, -1 do
								if got_piece then
									break
								end
								for k = 0, 2 do
									if self.local_board[(target_spot.col - k - 1) % 5 + 1][j] == step.t then
										--console.log(string.format("DEBUG - untested! - handling decent case in row assembly with piece at %d, %d", (target_spot.col - k - 1) % 5 + 1, j))
										self:perform_slide('r', j, k)
										self:perform_slide('c', (target_spot.col - 1) % 5 + 1, self.cursor_limit_up - j)
										got_piece = true
										break
									elseif k ~= 0 and self.local_board[(target_spot.col + k - 1) % 5 + 1][j] == step.t then
										--console.log(string.format("DEBUG - untested! - handling decent case in row assembly with piece at %d, %d", (target_spot.col + k - 1) % 5 + 1, j))
										self:perform_slide('r', j, k * -1)
										self:perform_slide('c', (target_spot.col - 1) % 5 + 1, self.cursor_limit_up - j)
										got_piece = true
										break
									end
								end
							end
						end
						-- nasty case: piece is in a row that is outside of cursor bounds
						-- since the row is out of bounds, the col MUST be in cursor bounds
						if not got_piece then
							for j = self.cursor_limit_up + 1, 5 do
								if got_piece then
									break
								end
								for k = target_spot.col, 1, -1 do
									if self.local_board[k][j] == step.t then
										--console.log(string.format("DEBUG - untested! - handling nasty case in row assembly with piece at %d, %d", k, j))
										self:perform_slide('c', k, target_spot.row - j - 1)
										self:perform_slide('r', target_spot.row - 1, target_spot.col - k)
										got_piece = true
										break
									end
								end
							end
						end
					end
				end
			end
		else -- == 'c'
			consec_pieces, consec_start = self:consec(self.local_board, step.t, step.q, step.a, self.cursor_limit_right, 6 - step.q)
			if consec_pieces >= step.q then
				-- we have sufficient consecutive pieces. is the setup complete or not?
				if consec_start <= (6 - step.q) and (consec_start + consec_pieces - step.q) >= (6 - step.q) then
					-- this cols's setup is complete
					--console.log(string.format("col for step %d complete.", self.combo_plan_index))
					self.cursor_limit_right = self.cursor_limit_right - 1
					self.cursor_limit_up = 5 - step.q
					--console.log(string.format("new cursor limits: %d, %d", self.cursor_limit_right, self.cursor_limit_up))
					self.combo_plan_index = self.combo_plan_index - 1
				else
					-- col has enough pieces, we need a vertical slide to finish it off
					local v_move = (consec_start - (6 - step.q)) % 5
					if v_move == 0 then
						--console.log(string.format("WARNING: in combo step %d detected insufficient consecutive pieces, but then determined no vertical movement necessary.", self.combo_plan_index))
					elseif v_move > 2 then
						-- slide 5 - v_move
						self:perform_slide('c', self.cursor_limit_right, 5 - v_move)
					else
						-- slide -v_move
						self:perform_slide('c', self.cursor_limit_right, v_move * -1)
					end
				end
			else
				-- get more pieces in the goofy ol way
				local did_slide = false
				if consec_pieces > 0 then
					-- make sure that the first spot is our consec_start
					-- this whole block looks similar to what we do when we have enough pieces but they need a vertical
					local v_move = (consec_start - (6 - step.q)) % 5
					--if self.local_board[self.cursor_limit_right][6 - step.q] ~= step.t then
						if v_move == 0 then
							--console.log(string.format("WARNING: in combo step %d detected wrong piece in work start location %d, %d, but then determined no vertical movement necessary.", self.combo_plan_index, 6 - step.q, self.cursor_limit_up))
						elseif v_move > 2 then
							-- slide 5 - v_move
							self:perform_slide('c', self.cursor_limit_right, 5 - v_move)
							did_slide = true
						else
							-- slide -v_move
							self:perform_slide('c', self.cursor_limit_right, v_move * -1)
							did_slide = true
						end
					--end
				end
				if consec_pieces == 0 or not did_slide then
					-- maybe the col has what it needs, but they're not adjacent
					local got_from_col = false
					for j = 5 - step.q - 1, 1, -1 do
						if self.local_board[self.cursor_limit_right][j] == step.t then
							self:perform_slide('r', j, -1)
							got_from_col = true
							break
						end
					end
					if not got_from_col then
						-- wrangle from elsewhere
						local target_spot = {col = self.cursor_limit_right, row = self.cursor_limit_up}
						local got_piece = false
						-- special case, first piece has the whole board unlimited but we don't actually want to shove things at 5,5
						if target_spot.col == 5 and target_spot.row == 5 then
							target_spot.row = 5 - step.q
						end
						--console.log(string.format("DEBUG: target_spot is %d, %d", target_spot.col, target_spot.row))
						-- easy case: there's a piece we want in the target spot's row
						for j = 1, 2 do
							if self.local_board[(target_spot.col - j - 1) % 5 + 1][target_spot.row] == step.t then
								self:perform_slide('r', target_spot.row, j)
								got_piece = true
								break
							elseif self.local_board[(target_spot.col + j - 1) % 5 + 1][target_spot.row] == step.t then
								self:perform_slide('r', target_spot.row, j * -1)
								got_piece = true
								break
							end
						end
						-- decent case: piece we want is in a column that is within cursor bounds (but not our assembly column, we checked that already)
						if not got_piece then
							for j = self.cursor_limit_right - 1, 1, -1 do
								if got_piece then
									break
								end
								for k = 0, 2 do
									--if self.local_board[(target_spot.col - k - 1) % 5 + 1][j] == step.t then
									if self.local_board[j][(target_spot.row - k - 1) % 5 + 1] == step.t then
										--console.log(string.format("DEBUG - untested! - handling decent case in col assembly with piece at %d, %d", j, (target_spot.col - k - 1) % 5 + 1))
										self:perform_slide('c', j, k)
										self:perform_slide('r', (target_spot.row - 1) % 5 + 1, self.cursor_limit_right - j)
										got_piece = true
										break
									elseif k ~= 0 and self.local_board[j][(target_spot.row + k - 1) % 5 + 1] == step.t then
										--console.log(string.format("DEBUG - untested! - handling decent case in col assembly with piece at %d, %d", j, (target_spot.col + k - 1) % 5 + 1))
										self:perform_slide('c', j, k * -1)
										self:perform_slide('r', (target_spot.row - 1) % 5 + 1, self.cursor_limit_right - j)
										got_piece = true
										break
									end
								end
							end
						end
						-- nasty case: piece is in a col that is outside cursor bounds
						-- since the col is out of bounds, the row MUST be in bounds
						if not got_piece then
							for j = self.cursor_limit_right + 1, 5 do
								if got_piece then
									break
								end
								for k = target_spot.row, 1, -1 do
									if self.local_board[j][k] == step.t then
										--console.log(string.format("DEBUG - untested! - handling nasty case in row assembly with piece at %d, %d", j, k))
										self:perform_slide('r', k, target_spot.col - j - 1)
										self:perform_slide('c', target_spot.col - 1, target_spot.row - k)
										got_piece = true
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	function Devilbot:get_next_input()
		local command = {}
		if self:experiencing_misery() or self:abandon_ship() then
			-- zaffo!
			self:reset_move_vars()
			self.clear_mode = nil
			command = {A=nil, B=true}
		elseif self.joypad_instructions[self.instruction_index] then
			command = self.joypad_instructions[self.instruction_index]
			self.instruction_index = self.instruction_index + 1
		elseif self:is_viewing_match() then -- nothin doin
			command = {A=nil, B=true}
			self.clear_mode = nil
		else
			self.local_board = self:read_board()
			if self.clear_mode == "single" then
				if self.current_target_cookie == 0 then
					self:find_move()
				end
				self:find_slide()
				self:define_instructions()
			elseif self.clear_mode == "combo" then
				----console.log("combo mode not done yet. making a single...")
				--self.clear_mode = "single"
				self:define_combo_instructions()
			else
				self:formulate_full_combo()
				if self.combo_plan == nil then
					--console.log("-------------------")
					self.clear_mode = "single"
				else
					--console.log("-------------------")
					self.clear_mode = "combo"
					self:reset_combo_vars()
					for _,step in pairs(self.combo_plan) do
						--console.log(string.format("Clear a %s: %d pieces of type %s", (step.a == 'r' and "row" or "col"), step.q, piece_lookup[step.t]))
					end
					-- gotcha check: this combo code can't handle starting with more than one 5, so if we combo with that, make a single instead
					if self.combo_plan[2].q == 5 then
						--console.log("This full combo makes our head hurt. Make a single instead.")
						self.clear_mode = "single"
					end
				end
			end
		end
		return command
	end
	
	-- end of Devilbot functions
	
	-- here be the test area
	--[[bungus = Devilbot:new(1)
	bungus:formulate_full_combo()
	wungus = bungus:get_next_input()
	if bungus.combo_plan == nil then
		--console.log("no combo on this board. make a single.")
	else
		--console.log("combo found! go with the plan")
		for _,step in pairs(bungus.combo_plan) do
			--console.log(string.format("Clear a %s: %d pieces of type %s", (step.a == 'r' and "row" or "col"), step.q, piece_lookup[step.t]))
		end
	end]]
	
	return Devilbot
end