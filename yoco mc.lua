-- yoco emcee

--while true do
	--runframe_y2()
	--emu.frameadvance()
--end

-- load bots
local directory = "yocobots/"
local bot_roster = {}
local player_one = nil
local player_two = nil
--local bot_table = {}
Yocobot = loadfile("yocobot_class.lua")()

for filename in io.popen('dir "'..directory..'" /b'):lines() do
	local botname = ""
	_, _, botname = string.find(filename, "^([^%.]+)%.lua$")
	--console.log("file with name " .. filename)
	--console.log("bot with name " .. (botname or "NOPE"))
	local loadpath = directory .. filename
	--console.log("loadpath: " .. loadpath)
	--bot_table[botname] = loadfile(loadpath)
	--local wulgus = bot_table[botname]();
	--console.log("return value: " .. (wulgus or "NIL"))
	--loadstring(botname .. "()")()
	local botname = ""
	_, _, botname = string.find(filename, "^([^%.]+)%.lua$")
	local loadpath = directory .. filename
	local bot_class = loadfile(loadpath)()
	if bot_class ~= nil then
		--local bot_obj = bot_class:new()
		--console.log("bot did this thing: " .. bot_obj:do_thing())
		--bot_table[bot_obj.name] = bot_obj
		bot_roster[bot_class.name] = bot_class
	else
		console.log("not a bot.")
	end
end

--local bot_class = loadfile("yocobots/gelato.lua")()
--bot_table = {["GEL"] = bot_class:new(1)}

console.log("BOT ROSTER:")
for name, bot in pairs(bot_roster) do
	console.log(name .. " by " .. bot.author)
end

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

function is_player_one_name_match(bot_name)
	for i = 1, 3 do
		ch = convert_char_byte(string.byte(bot_name, i))
		mem = mainmemory.readbyte(Yocobot.memory_addresses[1]["name"] + (i - 1))
		if ch ~= mem then
			--console.output(string.format("name match failed: char %s is %s in var, %s in mem", i, ch, mem))
			return false
		end
	end
	--console.output("bot is player one.")
	return true
end

function is_player_two_name_match(bot_name)
	for i = 1, 3 do
		ch = convert_char_byte(string.byte(bot_name, i))
		mem = mainmemory.readbyte(Yocobot.memory_addresses[2]["name"] + (i - 1))
		if ch ~= mem then
			--console.output(string.format("name match failed: char %s is %s in var, %s in mem", i, ch, mem))
			return false
		end
	end
	--console.output("bot is player two")
	return true
end

function is_game_active()
	game_state = mainmemory.readbyte(0x47)
	if game_state == 11 then
		return true
	end
	if game_state == 7 then
		check_names()
	end
	return false
end

function should_press_start()
	game_state = mainmemory.readbyte(0x47)
	if player_one ~= nil and player_two ~= nil and game_state == 7 then
		return true
	end
	return false
end
function check_names()
	player_one = nil
	player_two = nil
	for name, bot in pairs(bot_roster) do
		-- does player 1 have this name?
		-- does player 2 have this name?
		if is_player_one_name_match(name) then
			console.log(name .. " registered as player 1.")
			player_one = bot:new(1)
		end
		if is_player_two_name_match(name) then
			console.log(name .. " registered as player 2.")
			player_two = bot:new(2)
		end
	end
	if player_one ~= nil then
		console.log("Player 1 is " .. player_one.name .. " written by " .. player_one.author)
	end
	if player_two ~= nil then
		console.log("Player 2 is " .. player_two.name .. " written by " .. player_two.author)
	end
end

while true do
	if is_game_active() then
		if player_one ~= nil then
			joypad.set(player_one:get_next_input(), 1)
		end
		if player_two ~= nil then
			joypad.set(player_two:get_next_input(), 2)
		end
	elseif should_press_start() then
		joypad.set({A=true}, 1)
	end
	emu.frameadvance()
end