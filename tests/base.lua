require "classes"

local print = print
local type = type
local tostring = tostring
local getmetatable = getmetatable

class ("base")

_VERSION 		= "base1.0"
_AUTHOR 		= "Black Masta (seller.nightmares@gmail.com)"
_DESCRIPTION 	= [[Base Class to inheritance]]

function _(object)
	-- Конструктор
	function ctor()
		print(_NAME, "constructor called")
	end
	-- Деструктор
	function dtor()
		print(_NAME, "destructor called")
	end

	function address()
		return tostring(object):match("[0-9A-F]+")
	end
end

function __tostring (self)
	local mt = getmetatable (self)
	local accum = mt.__tostring
	mt.__tostring = nil
	local str = ("%s: %s"):format(self._NAME, self.address())
	mt.__tostring = accum
	return str
end

function __call()
	print("some object called.")
end