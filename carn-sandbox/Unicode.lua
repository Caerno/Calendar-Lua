local p = {}

-- =p.init(mw.getCurrentFrame():newChild{title="smth",args={["n"]=2048}})
local spam = function (n)
	for i = 32, n do
		mw.log(mw.ustring.char(i))
	end
end

p.init = function (f)
	local n = f.args.n or 512
	spam(n)
end

return p
