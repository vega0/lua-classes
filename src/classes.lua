--- Скрипт реализующий модель OOP на стыке модулей и метатаблиц.
--@script

require "functional"

--[[
if functional.is_c_function(type) then
	local _type = type
	function type(arg)
		local mt = getmetatable(arg)
		if not mt then return _type(arg) end
		if mt.__type ~= nil then
			assert(type(mt.__type) == "string", "mt.__type must be string value.")
			return mt.__type
		end
		return _type(arg)
	end
end
]]

--- Таблица пространств классов.
--@local
--@table _classes
local _classes = {}

--- Проверить vararg На правильность структуры.
--@tparam vararg ...
--@local
local function _check_string_classes(...)
	for i, str in ipairs({...}) do
		assert(type(str) == "string")
		assert(_classes[str] ~= nil, "Attempt to inherit from non existance class=" .. str ..".")
	end
end

--- Новое пространство для класса.
--@tparam string name Название создаваемого класса
--@tparam vararg ... Список наследования.
--@treturn table _t
local function _new_env(name, ...)
	local _t = {
		_M = {}, -- Статическое пространство класса
		_I = {}, -- Системная информация о классе.
	}
	for i, str in ipairs({...}) do
		table.insert(_t._I, _classes[str]._M )
	end
	functional.combine_indexing_with(_t._M, _t._I)
	return _t
end

--- Функция декларирования класса.
--@tparam string name Название класса
--@tparam vararg ... Список наследования.
function class(name, ...)
	_check_string_classes(...)
	local _t = _classes [name]
	if not _t then
		_t = _new_env(name, ...)
		_classes [name] = _t
		_t._M._NAME = name -- Название класса.
	end
	setfenv(2, _t._M)
end

--- Связать объект со сборщиком биомусора. :D
--@tparam table obj
local function _set_gc(mt, obj)
	local objmt = mt
	if _VERSION == "Lua 5.1" then
		local prox = newproxy (true)
		getmetatable(prox).__gc = obj.dtor
		mt.prox = prox
	else
		getmetatable(obj).__gc = obj.dtor
	end
end

--- Произвести шаг сборки объекта.
--@tparam function _C функция сборки класса.
-- Определяется в классе функцией с названием _
--@tparam table _M статическая таблица класса.
--@tparam table obj Ссылка на собираемый объект.
--@tparam table dtors Ссылка на таблицу для заполнения деструкторами.
local function _do_build(_C, _M, obj, dtors)
	local _pub = {} -- Таблица сборки.
	functional.combine_indexing_with(_pub, {_M, obj})
	setfenv(_C, _pub)
	_C( obj ) -- Вызов сборщика объекта.
	local acc_ctor = rawget(_pub, "ctor")
	if acc_ctor then
		if not obj.ctor then
			obj.ctor = acc_ctor
		else
			local ctor = obj.ctor
			obj.ctor = function(...)
				ctor (...)
				acc_ctor (...)
			end
		end
		rawset(_pub, "ctor", nil)
	end
	for k, v in pairs(_pub) do
		obj [k] = v -- Объединяем публичные ключи с создаваемым объектом.
	end
	table.insert(dtors, rawget(_pub, "dtor"))
end

--- Деактивировать объекта obj.
--@tparam table obj
local function _deactivate(obj)
	local mt = getmetatable(obj)
	if mt.prox then
		getmetatable(mt.prox).__gc = nil
	else
		mt.__gc = nil
	end
	setmetatable(obj, nil)
end

--- Собрать деконструктор объекту.
--@tparam table obj
--@tparam table dtors
local function _set_dtors (obj, dtors)
	if #dtors < 2 then
		obj.dtor = dtors[1]
	else
		obj.dtor = function (...)
			for i = #dtors, 1, -1 do
				dtors [i] (...)
			end
			obj.dtor = nil
			_deactivate (obj)
		end
	end
end

local function _merge_metamethods (_M, mt)
	for k, v in pairs(_M) do
		if k:match("^__") then
			mt[k] = v
			_M[k] = nil
		end
	end
end

--- Собрать объект.
--@tparam table _t _M/_I pair
local function _run_construction(_t)
	local dtors, blocks, mt =
		{}, {}, {__type = _t._M._NAME}
	local function construct(_t, obj)
		local _M = _t._M
		--assert(not blocks[_M._NAME], "Cycle inheritance found.")
		--blocks[_M._NAME] = true
		for i = #_t._I, 1, -1 do
			local _M = _t._I [i]
			construct (_classes[_M._NAME] , obj)
		end
		_merge_metamethods (_M, mt)
		local _C = _M._
		if not _C then return end
		_do_build(_C, _M, obj, dtors)
	end
	local obj = {}
	construct (_t, obj)
	_set_dtors(obj, dtors)
	_set_gc(mt, obj)
	setmetatable(obj, mt)
	functional.combine_indexing_with(obj, {_t._M})
	return obj
end
do
	local mt = {}
	mt.__index = mt

	--- Создание экземпляра класса.
	--@tparam string name
	--@tparam vararg ... Наследование.
	function mt:__call(name, ...)
		local _t = _classes [name]
		assert(_t ~= nil, "Cannot create non existance class.")
		local obj = _run_construction (_t)
		obj.ctor(...)
		obj.ctor = nil
		return obj
	end

--	function mt:__index(name)
--		return function(...)
--			return self(name, ...)
--		end
--	end

	function mt.GetClasses()
		local t = {}
		for k, v in pairs(_classes) do
			table.insert(t, v._M)
		end
		return t
	end

--[[GLOBAL]] Class = setmetatable({}, mt)
end