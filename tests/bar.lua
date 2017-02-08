require "base"

local print = print

class ("bar", "base")

_BAR = "bar static"

function _()
	function ctor()
		print(_NAME, "constructor called")
	end
	function dtor()
		print(_NAME, "destr called")
	end
	function bar()
		return "test"
	end
end