require "bar"

local print = print

class ("foo", "bar")

_FOO = "foo static"

function _()
	function ctor()
		print(_NAME, "constructor called")
	end
	function dtor()
		print(_NAME, "destructor called")
	end
	function foo()
		return "barr"
	end
end