local p={}
local test = {
	{title="Этилен",args={"Q151313"}},
	{title="Аланин",args={"Q218642"}},
	{title="Царская водка",args={"Q174670"}},
	{title="Глицин",args={"Q620730"}},
	{title="Нитрид титана",args={"Q415638"}},
	{title="Хлорид натрия",args={"Q2314"}},
}

function dalton(t)
	if type(t) == "table" then
		local mainsnak = t.mainsnak
		local datavalue,datatype,snaktype = mainsnak.datavalue, mainsnak.datatype, mainsnak.snaktype
  			if not(snaktype == "value" and datatype == "quantity") then
  				error("no quantity/value")
  			end
		return datavalue.value.amount
	end
end
--  =p.read(mw.getCurrentFrame():newChild{title="Аланин",args={"Q218642"}})
--  =p.read(mw.getCurrentFrame():newChild{title="Царская водка",args={"Q174670"}})
-- 
function p.read(frame)
	local args = frame.args
	local q = args[1]
	local entity = mw.wikibase.getEntity(q)
--	mw.logObject( entity )
	local P2067 = entity.claims.P2067
	mw.log(dalton(P2067[1]))
	return
end

return p
