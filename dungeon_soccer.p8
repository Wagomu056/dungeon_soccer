pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- debug print --
dbg = {}
dbg.print = {}
dbg.print.data = function(msg, frame, color)
	local obj = {}
	obj.msg = msg
	obj.frame = frame
	if color != nil then
		obj.color = color
	else
		obj.color = 12
	end

	obj.decrement_frame = function(self)
		self.frame -= 1
	end

	return obj
end

dbg.print.new = function()
	local obj = {}

	obj.table = {}

	obj.set_print = function(self, msg, frame, color)
		local data = dbg.print.data(msg, frame, color)
		add(self.table, data)
	end

	obj.update = function(self)
		for data in all(self.table) do
			if data.frame < 1 then
				del(self.table, data)
			end
		end

		for i, data in pairs(self.table) do
			self.table[i]:decrement_frame()
		end
	end

	obj.draw = function(self)
		local offset = 8
		for i, data in pairs(self.table) do
			print(data.msg, 0, offset * (i - 1), data.color)
		end
	end

	return obj
end

local dbg_print = dbg.print.new()

-- common data --
data = {}
data.vector2 = {}
data.vector2.new = function()
	local obj = {}

	obj.x = 0
	obj.y = 0

	return obj
end

-- anim --
anim = {}
anim.data = {}
anim.data.new = function(sprites, w, h, time, is_loop)
	local obj = {}

	obj.sprites = sprites
	obj.w = w
	obj.h = h
	obj.time = time
	obj.is_loop = is_loop

	return obj
end

anim_table = {}
anim_table["player_idle"] = anim.data.new({0,1}, 1, 2, 0.5, true)
anim_table["player_run"] = anim.data.new({2,3,4,5}, 1, 2, 0.15, true)

anim.controller = {}
anim.controller.new = function()
	local obj = {}

	-- variables
	obj.key_name = ""
	obj.data = {}
	obj.spr_index = 0
	obj.elapsed_time = 0.0

	-- functions
	obj.set = function(self, key_name)
		self.key_name = key_name
		self.data = anim_table[key_name]
		self.spr_index = 0
		self.elapsed_time = 0.0
	end

	obj.update = function(self, delta_time)
		self.elapsed_time += delta_time

		if self.elapsed_time >= self.data.time then
			self.spr_index = (self.spr_index + 1) % #(self.data.sprites)
			self.elapsed_time = 0.0
		end
	end

	obj.get_spr = function(self)
		return self.data.sprites[self.spr_index + 1], self.data.w, self.data.h
	end

	obj.debug_draw = function(self)
		local offset = 8
		local row = 0
		local color = 12
		print(self.key_name, 0, 0, color)
		row += 1
		print(self.spr_index, 0, row * offset, color)
		row += 1
		print(self.elapsed_time, 0, row * offset, color)
		row += 1
		print(self.data.sprites[self.spr_index + 1], 0, row * offset, color)
		row += 1
	end

	return obj
end

-- collision --
local col = {}
col.data = {}
col.data.new = function()
	local obj = {}

	obj.ax = 0
	obj.ay = 0
	obj.bx = 1
	obj.by = 1
	obj.size_x = 1
	obj.size_y = 1

	obj.set_pos = function(self, x, y)
		obj.ax = x
		obj.ay = y
		obj.bx = x + ((self.size_x * 8) - 1)
		obj.by = y + ((self.size_y * 8) - 1)
	end

	obj.set_size = function(self, size_x, size_y)
		self.size_x = size_x
		self.size_y = size_y
	end

	return obj
end

local c_inv_eight = 1 / 8
function check_wall(x, y)
	local map_val = mget(x / 8, y / 8)
	return fget(map_val,0)
end

function check_wall_with_size(base_x, base_y, size_x, size_y)
	local count_x = size_x
	local count_y = size_y
	for idx_y = 0, count_y do
		for idx_x = 0, count_x do
			local x = base_x + (idx_x * 8)
			if idx_x == count_x then
				x -= 1
			end

			local y = base_y + (idx_y * 8)
			if idx_y == count_y then
				y -= 1
			end

			if check_wall(x, y) then
				return true
			end
		end
	end

	return false
end

-- class --
local class = {}

class.actor = {}
class.actor.new = function()
	local obj = {}

	obj.init = function(self)
	end
	obj.update = function(self)
	end

	return obj
end

class.object = {}
class.object.new = function()
	local obj = class.actor.new()
	obj.actor_init = obj.init
	obj.actor_update = obj.update

	-- variables
	obj.x = 0
	obj.y = 0
	obj.w = 1
	obj.h = 1
	obj.spr = 0

	-- function
	obj.init = function(self, x, y, w, h)
		self:actor_init()
		if x != nil then
			self.x = x
		end
		if y != nil then
			self.y = y
		end
		if w != nil then
			self.w = w
		end
		if h != nil then
			self.h = h
		end
	end
	obj.update = function(self)
		self:actor_update()
		self:update_pre()
		self:update_control()
		self:update_animation()
	end
	obj.draw = function(self)
		spr(self.spr,self.x,self.y,self.w,self.h)
	end

	obj.update_pre = function(self)
	end

	obj.update_control = function(self)
	end

	obj.update_animation = function(self)
	end

	obj.set_pos = function(self, x, y)
		self.x = x
		self.y = y
	end

	return obj
end

class.chara = {}
class.chara.new = function()
	local obj = class.object.new()
	obj.object_init = obj.init
	obj.object_update_pre = obj.update_pre
	obj.object_update_control = obj.update_control
	obj.object_update_animation = obj.update_animation

	-- variable
	obj.anim_controller = anim.controller.new()
	obj.pre_elapsed_time = 0.0
	obj.delta_time = 0.0
	obj.direction = "right"

	-- function
	obj.init = function(self, x, y, w, h)
		self:object_init(x, y, w, h)
		self.pre_elapsed_time = time()
	end

	obj.update_pre = function(self)
		self:object_update_pre()

		local elapsed_time = time()
		self.delta_time = elapsed_time - self.pre_elapsed_time
		self.pre_elapsed_time = elapsed_time
	end

	obj.update_control = function(self)
		self:object_update_control()
	end

	obj.update_animation = function(self)
		self:object_update_animation()
		self.anim_controller:update(self.delta_time)
		self.spr, self.w, self.h = self.anim_controller:get_spr()
	end

	obj.draw = function(self)
		spr(self.spr, 
			self.x, self.y,
			self.w, self.h,
			self.direction == "left")
	end

	return obj
end

class.player = {}
class.player.new = function()
	local obj = class.chara.new()
	obj.chara_init = obj.init
	obj.chara_update_control = obj.update_control
	obj.chara_update_animation = obj.update_animation
	obj.chara_set_pos = obj.set_pos

	-- variable
	obj.pre_anim_state = "idle"
	obj.anim_state = "idle"
	obj.col = col.data.new()
	obj.pre_anim_state = "idle"
	obj.anim_state = "idle"
	obj.request_pos = data.vector2.new()

	-- function
	obj.init = function(self, x, y, w, h)
		self:chara_init(x, y, w, h)
		self.col:set_size(w, h)
		self.anim_controller:set("player_idle")
		self.request_pos.x = 0
		self.request_pos.y = 0
	end

	obj.update_control = function(self)
		self:chara_update_control()
		self:set_request_pos_by_button()
		self:adjust_request_pos()
		self:apply_request_pos()
	end

	obj.update_animation = function(self)
		if self.pre_anim_state != self.anim_state then
			local state = "player_" .. self.anim_state
			self.anim_controller:set(state)
			self.pre_anim_state = self.anim_state
		end

		self:chara_update_animation()
	end

	obj.set_request_pos_by_button = function(self)
		local state = "run"

		local speed = 1
		local x = 0
		local y = 0

		-- y is high prio
		if(btn(2))then
			y = -speed
		elseif(btn(3))then
			y = speed
		elseif(btn(0))then
			x = -speed
			self.direction = "left"
		elseif(btn(1))then
			x = speed
			self.direction = "right"
		else
			state = "idle"
		end

		self.request_pos.x = x
		self.request_pos.y = y

		self:set_anim(state)
	end

	obj.adjust_request_pos = function(self)
		--local next_col = self.col
		local req_pos = self.request_pos
		local x = self.x + req_pos.x
		local y = self.y + req_pos.y
		--next_col:set_pos(x, y)

		if check_wall_with_size(x, y, self.w, self.h) then
			if req_pos.y != 0 then
				if req_pos.y > 0 then
					req_pos.y -= (req_pos.y % 8)
				else
					req_pos.y += (8 - (req_pos.y % 8))
				end
			elseif req_pos.x != 0 then
				if req_pos.x > 0 then
					req_pos.x -= (req_pos.x % 8)
				else
					req_pos.x += (8 - (req_pos.x % 8))
				end
			end

			self.request_pos = req_pos
		end
	end

	obj.apply_request_pos = function(self)
		local x = self.x + self.request_pos.x
		local y = self.y + self.request_pos.y
		self:set_pos(x, y)

		self.request_pos.x = 0
		self.request_pos.y = 0
	end

	obj.set_pos = function(self, x, y)
		self:chara_set_pos(x, y)
		self.col:set_pos(x, y)
	end

	obj.set_anim = function(self, state)
		self.anim_state = state
	end

	return obj
end

class.map_info = {}
class.map_info.new = function()
	local obj = {}

	-- variables
	obj.base_x = 0
	obj.base_y = 0
	obj.size = 16

	-- functions
	obj.draw = function(self)
		map(self.base_x, self.base_y,
			0, 0, self.size, self.size)
	end

	return obj
end

-- global --
local map_info = class.map_info.new()
local player = class.player.new()

-- system --
function _init()
	player:init(8, 8, 1, 2)
end

function _update()
	player:update()
	dbg_print:update()
end

function _draw()
	map_info:draw()
	player:draw()
	dbg_print:draw()
end

__gfx__
00444400000000000004444000044440000444400004444000000000000000000000000000000000000000000000000000000000000000000000000000000000
004fff00004444000004fff00004fff00004fff00004fff000000000000000000000000000000000000000000000000000000000000000000000000000000000
004fff00004fff000044fff00004fff00044fff00004fff000000000000000000000000000000000000000000000000000000000000000000000000000000000
004ff000004fff000000ff000004ff000000ff000004ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000
007c7000004ff0000000c700000cc70000fcc700000cc70000000000000000000000000000000000000000000000000000000000000000000000000000000000
007c7000007c70000007c700000f770000f77700000f770000000000000000000000000000000000000000000000000000000000000000000000000000000000
007f7000007f70000007fff0000f770000f77700000f770000000000000000000000000000000000000000000000000000000000000000000000000000000000
007f7000007f7000000777000007f700000777000007f70000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ccc00000ccc000000ccc00000ccc00000ccc00000ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ccc00000ccc000000ccc00000ccc00000ccc00000ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ccc00000ccc00000cc0f000000cf00000fccf00000cf0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f0f00000f0f0000ff0ff0008ffff0000ff0ff008ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f0f00000f0f000ff08f0000800ff000ff08f000800ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f0f00000f0f000f0080000000ff0000f008000000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f0f00000f0f00080000000000f00000f000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800008888008800000000088000088000000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
8080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818181818180808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818181818180808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181808081818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181808081818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818180818181818082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818180818181818082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818180818181818082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818181818181818082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818080808181818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8081818181818181818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
