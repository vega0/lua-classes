local getmetatable = getmetatable
local setmetatable = setmetatable
local type = type
local assert = assert
local debug = {getinfo = debug.getinfo,
	getlocal = debug.getlocal}
local unpack = unpack
local print = print
local string = {dump = string.dump}
local getfenv = getfenv
local setfenv = setfenv
local require = require

--@module functional
module "functional"

--- Установить комбинированную индексацию у таблицы t.
-- _t Может содержать как таблицы так и функции.
-- Перебор происходит в порядке возрастания индекса.
--@tparam table t объект.
--@tparam table _t Таблица поиска.
function combine_indexing_with(t, _t)
	local mt = getmetatable(t)
	if not mt then
		mt = {}
		setmetatable(t, mt)
	else
		if mt.__index ~= nil then
			_t = {mt.__index, unpack(_t)}
		end
	end
	mt.__index =  (#_t < 2) and _t[1] or
		function (self, key)
			for i = 1, #_t do
				local _t = _t [i]
				local val = (type (_t) == "function") and 
					_t(self, key) or _t [key]
				if val ~= nil then return val end
			end
		end
--	return mt, t, _t
end

--- Является ли параметр C функцией.
--@tparam function val
--@treturn boolean
function is_c_function(val)
	assert(type(val) == "function")
	return (debug.getinfo(val).what == "C")
end

--- Является ли функция бестельной (пустой)?
--@tparam function f
--@treturn boolean
function is_empty_function(f)
	assert(not is_c_function(f))
	return #string.dump(f) == #string.dump(function() end)
end

--- Произвести проверку аргументов функций.
--@example 
-- 	local function test (number_a, string_b) functional.check_args() print(number_a, string_b) end
-- 	test(12, "hello") -- ok
-- 	test(nil, 12) -- false
function check_args()
	local i = 1
	while true do
		local name, value = debug.getlocal(2, i)
		if not name then break end
		local _type = name:match("^(.-)_")
		if _type ~= nil then
			assert(type(value) == _type, ("#%i must be %s value.")
				:format(i, _type) )
		end
		i = i + 1
	end
end