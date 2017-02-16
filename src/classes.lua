--- Скрипт реализующий модель OOP на стыке модулей и метатаблиц.
--@script
-- 	У классов есть две модели создания. Первая: Каждый наследуемый объект индексируется классом, конструктор объекта принимает
-- в аргумент экземпляры наследуемых объектов.
-- Вторая: Первый аргумент конструктора объекта self представляет конечный объект класса и содержит в себе все публичные методы
-- наследуемых и текущего классов. (!)

require "functional"

if functional.is_c_function(type) then
	rawtype = type
	function type(arg)
		local mt = getmetatable(arg)
		if rawtype(mt) ~= "table" then return rawtype(arg) end
		if mt.__type ~= nil then
			assert(type(mt.__type) == "string", "mt.__type must be string value.")
			return mt.__type
		end
		return rawtype(arg)
	end
end

local combine 	= functional.combine_indexing_with
local impose 	= functional.impose_of_two
local reverse 	= functional.reverse
local insert 	= table.insert
local setfenv 	= setfenv
local getfenv 	= getfenv
local pairs, ipairs = pairs, ipairs

--- Таблица пространств классов.
--@local
--@table _classes
--local
_classes = _classes or {}

local function assert_name(name) assert(type(name) == "string" and _classes[name] ~= nil, "Not valid Class Name " .. name) end
local function assert_names(...) for i, str in ipairs({...}) do assert_name(str) end end
local function get_class(name) return _classes [name] end

do -- Class Declaration Space

--- Новое пространство для класса.
--@tparam string name Название создаваемого класса
--@tparam vararg ... Список наследования.
--@treturn table _t
local function _new_env(name, ...)
	local _t = {
		{_NAME = name}, -- Статическое пространство класса
		_C = false, -- Функция конструкции объекта. (оптимизация см. далее)
		            -- false для построения функции. (!)
	}
	if #{...} > 0 then
		for i, str in ipairs({...}) do
			table.insert(_t, _classes[str] [1])
		end
		local ind = {}
		for i = 2, #_t do
			ind[i-1] = _t[i]
		end
		combine(_t[1], ind)
	end
	return _t
end

--- Функция декларирования класса.
--@tparam string name Название класса
--@tparam vararg ... Список наследования.
function class(name, ...)
	assert_names(...)
	local _t = _new_env(name, ...)
	local _M = _t [1]
	_classes[name] = _t
	setfenv(2, _M)

	local mods = {}
	setmetatable(mods, {__index = function()
		return function()
			return mods
		end
	end})
	return mods
end

end --//Class Declaration Space

do --Class Creation Space

local function _get_metas(_M)
	local mt = {}
	for k, v in pairs(_M) do
		if k:sub(1, 2) == "__" then
			mt[k] = v
			--_M[k] = v
		end
	end
	return mt
end

local rawget = rawget

--- Вызвать конструктор объекта, собрать информацию о метаполях.
-- Вариант 1: Индексация наследуемых объектов через .__index
-- Недостаток: Каждый объект отвечает сам за себя.
--@tparam table _M Статическое окружения
--@tparam table objects Экземпляры наследников.
--@tparam table mt Собираемая метатаблица
--@tparam table obj финальный объект
local function _do_1(_M, objects, mt, dtors)
	local _mt = _get_metas(_M)
	impose(mt, _mt)
	local _C = rawget(_M, "New")
	if not _C then
		print(_M._NAME, "have no object constructor.")
		return
	end

	local self = setmetatable({}, _mt)
	combine(self, objects) ---{_M, unpack(objects)}) -- access to its parent objects
	setfenv(_C, self)
	_C(self, unpack(objects))
	setfenv(_C, {})
	insert(dtors, self.dtor)
	print(_M._NAME, "dtor pushed")
	return self
end

--[[
local function _perform_ctor(obj, self)
	print(obj, self)
	local _ctor = rawget(self, "ctor")
	if not _ctor then
		return
	end
	rawset(self, "ctor", nil)
	local ctor = rawget(obj, "ctor")
	if not ctor then
		rawset(obj, "ctor", _ctor)
	else
		rawset(obj, "ctor", function(...)
			_ctor(...) ctor(...)
		end )
	end
end
]]

local _inheritance_block = {}

--- Вызвать конструктор объекта, собрать информацию о метаполях.
-- Вариант 2: Объект все свои публичные методы сохраняет во внешней таблице.
local function _do_2(_M, objects, mt, dtors, obj)
	impose(mt, _get_metas (_M))
	impose(getmetatable(obj), mt)
	local _C = rawget(_M, "New")
	if not _C then
		print(_M._NAME, "have no object constructor.")
		return
	end
	mt.__type = _M._NAME
	local self = setmetatable({}, {})
	impose(getmetatable(self), mt)
	combine(self, {_M, obj})
	setfenv (_C, self)
	_C(self, unpack(objects), obj)
	setfenv (_C, {})
	insert(dtors, rawget(self, "dtor"))
	impose(obj, self)
	return self
end

--- Построить объект.
--@tparam table _t Объект
local function _construct(_t, mt, dtors, obj)
	local objects = {}
	local l = #_t
	local mt = mt or {}
	if l > 1 then
		for i = 2, l do -- Собираем наследников рекурсивно
			local _M = _t [i]
			impose(mt, _get_metas(_M))
			local obj = _construct(_classes[_M._NAME], mt, dtors, obj)
			insert(objects, obj or nil)
		end
	end
	local _M = _t [1]
	return _do_2(_M, objects, mt, dtors, obj) -- Для текущего класса. (!)
end

--- Активировать объект (установить сборщик мусора)
--@tparam table obj
--@tparam table mt
local function _activate(obj, mt)
	if _VERSION == "Lua 5.1" then
		local prox = newproxy(true)
		getmetatable(prox).__gc = obj.dtor
		mt.prox = prox
	else
		mt.__gc = obj.dtor
	end
end

--- Деактивировать (уничтожить) объект.
--@tparam table obj
local function _deactivate(obj)
	local mt = getmetatable(obj)
	if mt.prox then
		getmetatable(mt.prox).__gc = nil
	end
	for k in pairs(obj) do
		obj [k] = nil
		--rawset(obj, k, nil)
	end
	setmetatable(obj, nil)
end

local rawset = rawset

--- Установить деконструктор объекту.
-- @tparam table obj
-- @tparam table dtors
local function _dtors(obj, dtors)
	reverse(dtors)
	rawset(obj, "dtor", function()
		for i = 1, #dtors do
			--dtors[i] ()
			local b, msg = pcall(dtors[i])
			if not b then
				print("Error in .dtor: " .. msg)
			end
		end
		_deactivate (obj)
	end	)
end

local pcall = pcall

--- Функция конструкции объекта.
--@tparam string name Название класса.
--@tparam vararg ... Аргументы конструктора.
function _Class (name, ...)
	assert_name(name)
	local _t = _classes [name]
	local dtors = {}
	local pool = setmetatable({}, {}) -- Object pool of public keys (fields, methods)
	local self = _construct(_t, nil, dtors, pool)
	--_inheritance_block = {}
	_dtors(self, dtors)
	_activate(self, getmetatable(self))

	combine(pool, {_t [1]})
	if self.ctor ~= nil then
		self.ctor(...)
		self.ctor = nil
	end
	return self
end

end --// Class Creation Space


do
	local mt = {}
	mt.__index = mt

	--- Создание экземпляра класса.
	--@tparam string name
	--@tparam vararg ... Наследование.
	function mt:__call(name, ...)
		return _Class (name, ...)
	end

--[[GLOBAL]] Class = setmetatable({}, mt)
end
