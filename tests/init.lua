package.path = package.path .. ";../src/?.lua"

require "base"
require "foo"
require "bar"

local dump = require "pl.pretty" .dump

local function dump_obj(obj)
	local mt = getmetatable(obj)
	if mt ~= nil then
		print(">>meta")
		dump(getmetatable(obj))
	else
		print(">>no_meta!")
	end
	print("\n->obj")
	dump(obj)
end

local _bar = Class("foo")
dump_obj(_bar)
_bar()
print(_bar, type(_bar))
_bar.dtor()

dump(Class.GetClasses())