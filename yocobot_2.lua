--[[
CONFIG-O-MATIC
PUT IN THE NAME YOU WANT TO ENTER TO TURN ON THE BOT.
IT CAN WORK ON THE PLAYER 1 OR PLAYER 2 SIDE (BUT NOT BOTH).
BE SURE TO USE ALL CAPS IN THIS VALUE
]]
local bot_name = "YB2"

-- upgrade over yocobot_1: this one can also make vertical matches
-- it prioritizes the row/col that has the best density
-- the real yoshi's cookie starts here
local last_keytable = {}
-- board[1][1] is bottom left of board, board[5][1] is bottom right
-- board[1][5] is top left of board, board[5][5] is top right
local playerone_board = {}

local piece_lookup = { [0] = "empty", [1] = "heart", [2] = "bloom", [3] = "green", [4] = "check", [5] = "torus", [13] = "yoshi" }
local board_size = 5 -- who knows why i bothered to not hard-code this
local game_state_address = 0x47
local player_one_addresses = {["board"] = 0x300, ["cursor_x"] = 0x373, ["cursor_y"] = 0x374, ["fuse"] = 0x940, ["panic"] = 0x952, ["slave"] = 0x954, ["name"] = 0x1146}
local player_two_addresses = {["board"] = 0x400, ["cursor_x"] = 0x473, ["cursor_y"] = 0x474, ["fuse"] = 0xA40, ["panic"] = 0xA52, ["slave"] = 0xA54, ["name"] = 0x1166}
local player_addresses = { [1] = player_one_addresses, [2] = player_two_addresses }
-- all of the p2 addresses are 0x100 more than the p1 addresses except for name, so a full lookup table is probably kind of overkill

local player_identity = 0 -- 1 for p1, 2 for p2
local current_target_position = {row = 0, col = 0} -- where we want the cookie to end up
local current_target_cookie = 0 -- references piece_lookup
local current_move_start = {row = 0, col = 0} -- where the cookie we are moving starts out
local cursor_pos = {row = 3, col = 3} -- cursor always starts at 3, 3 at the beginning of the game
local current_target_index = 0 -- index of the row or column where we are assembling a clear
local current_target_alignment = "x" -- "r" for row "c" for col, anything else is no good
local current_target_density = 0 -- helper var (maybe doesn't need to be scoped this high up) to tell us how good our best cookie is so far

local joypad_instructions = {} -- buffer to hold controller inputs
local instruction_index = 1 -- lua arrays are weird to someone like me who is new at lua so instead of a real queue, i just keep track of what index i want

local viewing_match_toggler = 0 -- toggle var so that we know the frame on which we stopped watching a match being cleared away

function convert_char_byte(ch)
	if ch >= 48 and ch <= 57 then -- 0-9
		ch = ch - 19
	elseif ch >= 65 and ch <= 90 then -- A-Z
		ch = ch - 65
	elseif ch == 33 then -- !
		ch = 26
	elseif ch == 63 then -- ?
		ch = 27
	elseif ch == 32 or ch == 95 then -- space or _
		ch = 28
	end
	return ch
end

function is_player_one_name_match()
	for i = 1, 3 do
		ch = convert_char_byte(string.byte(bot_name, i))
		mem = mainmemory.readbyte(player_one_addresses["name"] + (i - 1))
		if ch ~= mem then
			--console.output(string.format("name match failed: char %s is %s in var, %s in mem", i, ch, mem))
			return false
		end
	end
	--console.output("bot is player one.")
	return true
end

function is_player_two_name_match()
	for i = 1, 3 do
		ch = convert_char_byte(string.byte(bot_name, i))
		mem = mainmemory.readbyte(player_two_addresses["name"] + (i - 1))
		if ch ~= mem then
			--console.output(string.format("name match failed: char %s is %s in var, %s in mem", i, ch, mem))
			return false
		end
	end
	--console.output("bot is player two")
	return true
end

function reset_game_vars()
	-- see if we are a player
	if is_player_one_name_match() then
		player_identity = 1
	elseif is_player_two_name_match() then
		player_identity = 2
	end
end

function reset_move_vars()
	current_target_index = 0
	current_target_alignment = "x"
	current_target_cookie = 0
	current_target_density = 0
	current_target_position.row = 0
	current_target_position.col = 0
	current_move_start.row = 0
	current_move_start.col = 0
end

function reset_slide_vars()
	current_target_position.row = 0
	current_target_position.col = 0
	current_move_start.row = 0
	current_move_start.col = 0
	cursor_pos.col = math.ceil((mainmemory.readbyte(player_addresses[player_identity]["cursor_x"]) + 8) / 16)
	cursor_pos.row = math.ceil((mainmemory.readbyte(player_addresses[player_identity]["cursor_y"]) + 8) / 16)
end

function load_board(start_index, board)
	for i = 1, 5 do
		board[i] = {}
		for j = 1, 5 do
			board[i][j] = mainmemory.readbyte(start_index + (i - 1) + 8 * (j - 1))
		end
	end
end

function print_board(board)
	for i = 1, 5 do
		console.output(piece_lookup[board[1][6-i]] .. "|" .. piece_lookup[board[2][6-i]] .. "|" .. piece_lookup[board[3][6-i]] .. "|" .. piece_lookup[board[4][6-i]] .. "|" .. piece_lookup[board[5][6-i]])
	end
end

function print_population(population)
	console.output("piece population counts:\n")
	for key, value in pairs(population) do
		console.output(piece_lookup[key] .. " count: " .. value .. "\n")
		if value >= 5 then
			console.output("can try to match " .. piece_lookup[key] .. "\n")
		else
			console.output("can't try to match " .. piece_lookup[key] .. "\n")
		end
	end
end

-- still kind of inefficient but can make both row and column clears, and is passably intelligent about it
function get_row_pop(board, i, t)
    result = 0
    for k = 1, board_size do
        if board[k][i] == t then
            result = result + 1
        end
    end
    return result
end

function get_col_pop(board, i, t)
    result = 0
    for k = 1, board_size do
        if board[i][k] == t then
            result = result + 1
        end
    end
    return result
end

function find_move(board)
	--console.output("start find_move")
	reset_move_vars()
	-- first, count pieces to see which piece type we can attempt to match
	-- piece_population = {0, 0, 0, 0, 0, 0} -- testing version
	piece_population = {0, 0, 0, 0, 0, [13]=0} -- deployment version
	for i = 1, board_size do
		for j = 1, board_size do
			piece_population[board[i][j]] = piece_population[board[i][j]] + 1
		end
	end
	for i = 1, board_size do
		for piece_type, piece_pop in pairs(piece_population) do
			if piece_pop > 4 then
				row_density = get_row_pop(board, i, piece_type)
                col_density = get_col_pop(board, i, piece_type)
				if row_density >= col_density and row_density > current_target_density then
                    current_target_density = row_density
                    current_target_alignment = "r"
                    current_target_index = i
                    current_target_cookie = piece_type
                elseif col_density > current_target_density then
                    current_target_density = col_density
                    current_target_alignment = "c"
                    current_target_index = i
                    current_target_cookie = piece_type
                end
			end
		end
	end
	--console.output(string.format("move decided: assembling %s in %s%d", piece_lookup[current_target_cookie], current_target_alignment, current_target_index))
end

function find_slide(board)
	reset_slide_vars()
	-- find the first spot in our target row/col that doesn't have a target cookie in it. that's the spot we're about to fill
	if current_target_alignment == "r" then
		for i = 1, board_size do
			if board[i][current_target_index] ~= current_target_cookie then
				current_target_position.row = current_target_index
				current_target_position.col = i
				break
			end
		end
		-- find a cookie to put into that spot. the cookie needs to not already be in our target row/col.
		for i = 1, board_size do
			if i ~= current_target_index then
				for j = 0, math.floor(board_size / 2) do
					-- minor optimization: start search at target position's col/row and move outward
					colA = ((current_target_position.col - j) % board_size)
					colB = ((current_target_position.col + j) % board_size)
					if colA == 0 then colA = board_size end
					if colB == 0 then colB = board_size end
					if board[colA][i] == current_target_cookie then
						current_move_start.col = colA
						current_move_start.row = i
						break
					end
					if colB ~= colA and board[colB][i] == current_target_cookie then
						current_move_start.col = colB
						current_move_start.row = i
						break
					end
				end
			end
			if current_move_start.col ~= 0 then
				break
			end
		end
	elseif current_target_alignment == "c" then
		for i = 1, board_size do
			if board[current_target_index][i] ~= current_target_cookie then
				current_target_position.row = i
				current_target_position.col = current_target_index
				break
			end
		end
		-- find a cookie to put into that spot. the cookie needs to not already be in our target row/col.
		for i = 1, board_size do
			if i ~= current_target_index then
				for j = 0, math.floor(board_size / 2) do
					-- minor optimization: start search at target position's col/row and move outward
					rowA = ((current_target_position.row - j) % board_size)
					rowB = ((current_target_position.row + j) % board_size)
					if rowA == 0 then rowA = board_size end
					if rowB == 0 then rowB = board_size end
					if board[i][rowA] == current_target_cookie then
						current_move_start.col = i
						current_move_start.row = rowA
						break
					end
					if rowB ~= rowA and board[i][rowB] == current_target_cookie then
						current_move_start.col = i
						current_move_start.row = rowB
						break
					end
				end
			end
			if current_move_start.row ~= 0 then
				break
			end
		end
	else
		--console.output("invalid target alignment")
	end
	--console.output(string.format("cursor currently at %d, %d", cursor_pos.col, cursor_pos.row))
	--console.output(string.format("slide %s from %d, %d to %d, %d", piece_lookup[current_target_cookie], current_move_start.col, current_move_start.row, current_target_position.col, current_target_position.row))
end

function move_cursor_left(instr, t)
	--console.output(string.format("move cursor left %d", t))
	for i = 1, t do
		for z = 1, 5 do
			table.insert(instr, {Left=true, A=nil, B=nil})
		end
		table.insert(instr, {Left=nil, A=nil, B=true})
	end
end

function move_cursor_down(instr, t)
	--console.output(string.format("move cursor down %d", t))
	for i = 1, t do
		for z = 1, 5 do
			table.insert(instr, {Down=true, A=nil, B=nil})
		end
		table.insert(instr, {Down=nil, A=nil, B=true})
	end
end

function move_cursor_right(instr, t)
	--console.output(string.format("move cursor right %d", t))
	for i = 1, t do
		for z = 1, 4 do
			table.insert(instr, {Right=true, A=nil, B=nil})
		end
		table.insert(instr, {Right=nil, A=nil, B=true})
	end
end

function move_cursor_up(instr, t)
	--console.output(string.format("move cursor up %d", t))
	for i = 1, t do
		for z = 1, 4 do
			table.insert(instr, {Up=true, A=nil, B=nil})
		end
		table.insert(instr, {Up=nil, A=nil, B=true})
	end
end

function slide_left(instr, t)
	--console.output(string.format("slide left %d", t))
	for i = 1, t do
		for z = 1, 4 do
			table.insert(instr, {Left=true, A=true, B=nil})
		end
		for z = 1, 9 do
			table.insert(instr, {Left=nil, A=nil, B=true})
		end
	end
end

function slide_down(instr, t)
	--console.output(string.format("slide down %d", t))
	for i = 1, t do
		for z = 1, 4 do
			table.insert(instr, {Down=true, A=true, B=nil})
		end
		for z = 1, 9 do
			table.insert(instr, {Down=nil, A=nil, B=true})
		end
	end
end

function slide_right(instr, t)
	--console.output(string.format("slide right %d", t))
	for i = 1, t do
		for z = 1, 4 do
			table.insert(instr, {Right=true, A=true, B=nil})
		end
		for z = 1, 9 do
			table.insert(instr, {Right=nil, A=nil, B=true})
		end
	end
end

function slide_up(instr, t)
	--console.output(string.format("slide up %d", t))
	for i = 1, t do
		for z = 1, 4 do
			table.insert(instr, {Up=true, A=true, B=nil})
		end
		for z = 1, 9 do
			table.insert(instr, {Up=nil, A=nil, B=true})
		end
	end
end

function buffer_input(instr, t)
	--console.output(string.format("buffer %d", t))
	for i = 1, t do
		table.insert(instr, {A=nil, B=true})
	end
end

function define_instructions()
	instruction_index = 1
	joypad_instructions = {}
	-- move cursor to correct position
	-- when assembling a row:
	-- the column should be the target position's column
	-- the row should be the cookie's current row
	-- when assembling a col:
	-- the column should be the cookie's current column
	-- the row should be the target position's row
	-- move cursor horizontally
	column_diff = 0
	if current_target_alignment == "r" then
		column_diff = (cursor_pos.col - current_target_position.col) % 5
	else
		column_diff = (cursor_pos.col - current_move_start.col) % 5
	end
	if column_diff == 1 then -- move cursor left once
		move_cursor_left(joypad_instructions, 1)
	elseif column_diff == 2 then -- move cursor left twice
		move_cursor_left(joypad_instructions, 2)
	elseif column_diff == 3 then -- move cursor right twice
		move_cursor_right(joypad_instructions, 2)
	elseif column_diff == 4 then -- move cursor right once
		move_cursor_right(joypad_instructions, 1)
	end
	-- move cursor vertically
	row_diff = 0
	if current_target_alignment == "r" then
		row_diff = (cursor_pos.row - current_move_start.row) % 5
	else
		row_diff = (cursor_pos.row - current_target_position.row) % 5
	end
	if row_diff == 1 then -- move cursor down once
		move_cursor_down(joypad_instructions, 1)
	elseif row_diff == 2 then -- move cursor down twice
		move_cursor_down(joypad_instructions, 2)
	elseif row_diff == 3 then -- move cursor up twice
		move_cursor_up(joypad_instructions, 2)
	elseif row_diff == 4 then -- move cursor up once
		move_cursor_up(joypad_instructions, 1)
	end
	-- slide piece into position
	column_diff = (current_move_start.col - current_target_position.col) % 5
	row_diff = (current_move_start.row - current_target_position.row) % 5
	-- when matching a row, slide horizontally then vertically
	-- when matching a column, slide vertically then horizontally
	if current_target_alignment == "r" then
		if column_diff == 1 then -- slide left once
			slide_left(joypad_instructions, 1)
		elseif column_diff == 2 then -- slide left twice
			slide_left(joypad_instructions, 2)
		elseif column_diff == 3 then -- slide right twice
			slide_right(joypad_instructions, 2)
		elseif column_diff == 4 then -- slide right once
			slide_right(joypad_instructions, 1)
		end
		if row_diff == 1 then -- slide down once
			slide_down(joypad_instructions, 1)
		elseif row_diff == 2 then -- slide down twice
			slide_down(joypad_instructions, 2)
		elseif row_diff == 3 then -- slide up twice
			slide_up(joypad_instructions, 2)
		elseif row_diff == 4 then -- slide up once
			slide_up(joypad_instructions, 1)
		end
	else
		if row_diff == 1 then -- slide down once
			slide_down(joypad_instructions, 1)
		elseif row_diff == 2 then -- slide down twice
			slide_down(joypad_instructions, 2)
		elseif row_diff == 3 then -- slide up twice
			slide_up(joypad_instructions, 2)
		elseif row_diff == 4 then -- slide up once
			slide_up(joypad_instructions, 1)
		end
		if column_diff == 1 then -- slide left once
			slide_left(joypad_instructions, 1)
		elseif column_diff == 2 then -- slide left twice
			slide_left(joypad_instructions, 2)
		elseif column_diff == 3 then -- slide right twice
			slide_right(joypad_instructions, 2)
		elseif column_diff == 4 then -- slide right once
			slide_right(joypad_instructions, 1)
		end
	end
	buffer_input(joypad_instructions, 2) -- arbitrary guess at buffer for safety
end

function experiencing_misery()
	-- return true if we're panicked or slaved, because those status effects make us unable to act.
	return mainmemory.readbyte(player_addresses[player_identity]["panic"]) + mainmemory.readbyte(player_addresses[player_identity]["panic"] + 1) + mainmemory.readbyte(player_addresses[player_identity]["slave"]) + mainmemory.readbyte(player_addresses[player_identity]["panic"] + 1) > 0
end

function abandon_ship()
	-- check the memory of the top right, which will flicker onto 0 for both col and row matches
	-- if it's zero, some kind of pre-emptive match happened and we need to abandon our current plan
	-- this function is... kind of shaky, and i don't really like it.
	top_right = mainmemory.readbyte(player_addresses[player_identity]["board"] + 0x24) -- top right
	fuse = mainmemory.readbyte(player_addresses[player_identity]["fuse"]) -- fuse timer
	return top_right == 0 and fuse > 0 and current_target_position.col > 0
end

function read_row(start_index, row)
	r = {}
	for i = 1, board_size do
		r[i] = mainmemory.readbyte(start_index + 8 * (row - 1) + (i - 1))
	end
	return r
end

function read_col(start_index, col)
	c = {}
	for i = 1, board_size do
		c[i] = mainmemory.readbyte(start_index + (col - 1) + 8 * (i - 1))
	end
	return c
end

function is_set_match(test_set)
	match_cookie = 0
	for j = 1, board_size do
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

function is_viewing_match()
	-- if any row or column has all the same values in its nonzero spots, return true
	-- else, return false
	for i = 1, board_size do
		test_set = read_row(player_addresses[player_identity]["board"], i)
		if is_set_match(test_set) then
			if viewing_match_toggler == 0 then
				viewing_match_toggler = 1
			end
			return true
		end
		test_set = read_col(player_addresses[player_identity]["board"], i)
		if is_set_match(test_set) then
			if viewing_match_toggler == 0 then
				viewing_match_toggler = 1
			end
			return true
		end
	end
	if viewing_match_toggler == 1 then
		instruction_index = 1
		joypad_instructions = {}
		buffer_input(joypad_instructions, 6)
		viewing_match_toggler = 0
		return true
	end
	return false
end

function is_game_active()
	--[[ a brief explanation of this:
		byte 0x000047 in RAM holds what i like to call the 'game state'
		it gets set to different values during the course of the actual game (not in menus).
		importantly, it is 11 when the game is running and input can be accepted (assuming that a negative status effect isn't stopping you).
		any other state (paused, countdown, postgame or between-game animations) will have another value.
		most of those specific values aren't really important for what we need here, though.
		10 is useful because it's the state we are in while the game is counting down to actually starting, which means that it always comes right before 11.
	]]
	game_state = mainmemory.readbyte(game_state_address);
	if game_state == 11 then
		return true
	end
	if game_state == 10 then
		reset_game_vars()
		reset_move_vars()
	end
	return false
end

while true do
	-- if we're in an active game, figure out what to do about it
	if is_game_active() then
		if player_identity > 0 then
			-- if panicked or slaved, or watching a match, abandon current instructions and wait one frame
			-- this could probably be changed to be better once i fix abandon_ship to make sense and not be hacked together
			if experiencing_misery() or abandon_ship() then
				joypad_instructions = {}
				buffer_input(joypad_instructions, 1)
				reset_move_vars()
			elseif joypad_instructions[instruction_index] then
				joypad.set(joypad_instructions[instruction_index], player_identity)
				instruction_index = instruction_index + 1		
			elseif is_viewing_match() then
			else
				-- if we're not in a status effect, and we're out of instructions, and we're not currently watching a beautiful match go by... then it's time to bake
				load_board(player_addresses[player_identity]["board"], playerone_board)
				if current_target_cookie == 0 then
					find_move(playerone_board)
				end
				find_slide(playerone_board)
				define_instructions()
			end
		end
	end
	emu.frameadvance()
end