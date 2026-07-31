local p = {}
-- Необходимые модули и переменные
local getArgs = require('Module:Arguments').getArgs
local yesno = require('Module:Yesno')
local lang = mw.getContentLanguage()
local err = "―" -- NthDay nil result
-- 00) Блок многократно используемых списков
local bool_to_number={ [true]=1, [false]=0 }
local monthlang = {"января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"}
local month_to_num = {["января"]=1,["февраля"]=2,["марта"]=3,["апреля"]=4,["мая"]=5,["июня"]=6,
	["июля"]=7,["августа"]=8,["сентября"]=9,["октября"]=10,["ноября"]=11,["декабря"]=12,["-"]=""}
local monthd = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local params = { {"г", "g"}, {"ю", "j"}}
local comment = { '<span style="border-bottom: 1px dotted; cursor: help" title="по юлианскому календарю">','</span>'}
local category = {
	["incomplete-parameters"]="<!--[[Категория:Модуль:Calendar:Страницы с неполными или некорректными параметрами]]-->",
	["without-verification"]="<!--[[Категория:Модуль:Calendar:Страницы без проверки параметров]]-->",
	["erroneous-parameters"]="<!--[[Категория:Модуль:Calendar:Страницы с ошибочными параметрами]]-->"
}
-- todo проверка на ОС: mw.title.getCurrentTitle():inNamespace(0)

-- 10) Блок общих функций


local function trim(str)
--	if not str then return nil
--	else return str:match'^()%s*$' and '' or str:match'^%s*(.*%S)'
--	end
	return mw.text.trim(str)
end

local function purif(str)
    if str == "" or str == nil then
        return nil
    elseif type(tonumber(str)) == "number" then
        return math.floor(tonumber(str))
    else
        return nil
    end
    -- need .5 -- ,5 number format converter?
end

local function is(str)
	if (not str) or (str == "") then return false
	else return yesno(str,false)
	end
end

local function init(num)
	output = {}
	for i=1,num do
		table.insert(output, {["year"]="", ["month"]="", ["day"]=""})
	end
	return unpack(output)
end

local function isyear(tbl)
	if type(tbl) ~= 'table' then return false
	elseif not tbl["year"] then return false
	elseif type(tbl["year"]) == 'number' then return true
	else return false
	end
end

local function inbord(val, down, up)
	if type(up) ~= "number" or type(down) ~= "number" or type(val) ~= "number" or up < down or val < down or val > up then
		return false
    else
        return true
    end
end

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local inlist = function ( var, list )
    local n = #list
	local inlist = false
	for i=1,n do
		if var == list[i] then inlist = true end
	end
    return inlist
end

-- 20) Блок общих проверочных функций, связанных с датами

local function leap_year(y,jul)
	if (not y) or (type(y) ~= "number")
		then return false
	elseif (y % 4) ~= 0
		then return false
	elseif not jul and (y % 100 == 0 and y % 400 ~= 0)
		then return false
	else return true
	end
end

local function isdate ( chain , jul )
	if not chain then return false
	elseif (not type(chain) == "table")
	or (not inbord(chain.year,-9999,9999))
	or (not inbord(chain.month,1,12))
	or (not inbord(chain.day,1,31))
	or chain.day > monthd[chain.month]
--	or not (type(os.time(chain)) == "number")
--	or chain.year == 0
	then return false
	elseif chain.month == 2 and chain.day == 29 and not leap_year(chain.year, jul)
		then return false
	else return true end
--  more detailed check for 31.02 needed
--  check for other calendars needed
end

local function ispartdate ( chain )
	if not chain then return false
	elseif not (type(chain) == "table") then return false
	elseif (inbord(chain.year,-9999,9999)
	or inbord(chain.month,1,12)
	or inbord(chain.day,1,31)) then return true
	else return false
	end
--	partial date
--  more detailed check for 31.02.0000 needed
--  check for other calendars needed
end

-- need pre init dates, "attempt to index local nil value."
-- from date1 to date2 in one year or beetwen jan-dec, dec-jan
local function partdist(date1,date2)
	local mont, dist = 0, 0
	local d1d, d1m, d2d, d2m = (date1["day"] or ""), (date1["month"] or ""),(date2["day"] or ""), (date2["month"] or "")
	if not (inbord(d1d,1,31) and inbord(d2d,1,31)) then return false end
	-- нужна доп. проверка частичных дат на корректность
	if (inbord(d1m,1,12) or inbord(d2m,1,12))
	and (d1m == "" or d2m == "") then
		mont = purif(date1["month"] or date2["month"])
		d1m, d2m = mont, mont
	end
--	mw.log("📏 day: " ..d1d .."->"..d2d.." month: ".. d1m.."->"..d2m )
	if (inbord(d1m,1,12) and d1d <= monthd[d1m])
	and (inbord(d2m,1,12) and d2d <= monthd[d2m])	then 
		if d2m == d1m 
		then dist = d2d - d1d
		else dist = monthd[d1m] - d1d + d2d
		end
		return dist
	else return math.huge
	end
end

local function mwlog(...)

	mw.log(unpack(arg))

end

local function undate(tbl)
	if not tbl then return ""
	else return (tbl.year or "").."-"..(tbl.month or "").."-"..(tbl.day or "")
	end
end

local function dmdist(d1,d2)
	local p1,p2 = math.huge,math.huge
	if not not partdist(d1,d2) then 
		p1=partdist(d1,d2)
	end
	if not not partdist(d2,d1) then 
		p1=partdist(d2,d1)
	end
--	if (not p1) or (not p2) then
--		return  (p1 or "") .. (p2 or "")
--	else
--		mw.log("d1, d2 = " .. undate(d1) .. ", " .. undate(d2))
		return math.min(tonumber(partdist(d1,d2)) or math.huge,tonumber(partdist(d2,d1)) or math.huge)
--	end
end
-- 30) Блок функций для обработки ввода-вывода дат
local numstr2date = function(numstr)
	local lang = mw.getContentLanguage()
	local format = "Y-m-d"
	local iso_date = lang:formatDate(format,numstr)
    local y,m,d = string.match(iso_date, "(%d+)-(%d+)-(%d+)")
	local dateout = {["year"]=purif(y), ["month"]=purif(m), ["day"]=purif(d)}
    return dateout
end

local function year2lang(numyear,yearmark,wiki)
	if not numyear then return "" end
	if not yearmark then yearmark = "" end
	local output = ""
	local bcmark = " до н. э."
	if numyear > 0 then	bcmark = ""
	else numyear = 1 - numyear end
	if wiki then 
--		output = table.concat({'[[', numyear,' год',bcmark,'|', numyear,']]', " ", yearmark, " ", bcmark})
		output = table.concat({'[[', numyear,' год',bcmark,'|', trim(numyear .. " " .. yearmark .. " " .. bcmark), ']]'})
	else
		output = table.concat({numyear, " ", yearmark, bcmark})
	end
	return trim(output)
end
	
local function day2lang(datein,wikidate,wiki,inner_brt)
--	if not isdate(wikidate) then wiki = false end
	if not ispartdate(datein) then return "" end
	local dm_separ, output = ""
	if (not (not datein.day)) and (not (not datein.month)) then dm_separ = " " end
	if (not datein.month) then datein.month = "" end
	if (not datein.day) then datein.day = "" end
	local monlan = monthlang[datein.month] or ""
	if wiki and not inner_brt then
		output = table.concat({"[[", wikidate.day, " ", monthlang[wikidate.month] or "",
			"|", (datein.day or ""), dm_separ, monlan, "]]"})
	elseif wiki then
		output = table.concat({"[[", wikidate.day, " ", monthlang[wikidate.month] or "",
			"|", (datein.day or ""), dm_separ, monlan})
	else
		output = table.concat({datein.day, dm_separ, monlan})
	end
    return trim(output)
end

local function triple_txt2date(d,m,y)
	-- добавить (args[1]:match("(%a+)") or "-") для нестандартной записи
	-- mw.ustring.match((m or ""),"(%a+)")
	local msg = ""
	local year = purif((y or "-"):match("(%d+)"))
	local month = purif(month_to_num[string.lower(mw.ustring.match((m or ""),"(%a+)") or "")])
	local day = purif((d or "-"):match("(%d+)"))
	if not month then 
		msg = category["incomplete-parameters"]
		month = purif(month_to_num[string.lower(mw.ustring.match((d or ""),"(%a+)") or "-")]) 
	end
	if (not day) and ((purif(string.match(m or "","(%d+)") or "") or 32) <= (monthd[month] or 31)) then 
		msg = category["incomplete-parameters"]
		day = purif(m:match("(%d+)") or "") 
	end
	if not year then 
		msg = category["incomplete-parameters"]
		year = purif(string.match(m or "","(%d+)") or "") 
	end
	local dateout = {["year"]=year, ["month"]=month, ["day"]=day, ["msg"]=msg}
	return dateout
end

local function glue(d1,m1,y1,d2,m2,y2, wd, wm, wy, sq_brts, yearmark,inmsg,bracketsinside)
	if (not d1) and (not m1) and (not y1) and (not d2) and (not m2) and (not y2) then
		return category["incomplete-parameters"] end
	local msg = (inmsg or "")
	mwlog("d1=",d1,"m1=",m1,"y1=",y1,"d2=",d2,"m2=",m2,"y2=",y2, "wd=",wd, "wm=",wm, "wy=",wy,"sq_brts=",sq_brts, "yearmark=",yearmark)
	local gd,gm,gy,jd,jm,jy = 
		(d1 or ""),
		(m1 or ""),
		(y1 or ""),
		(d2 or ""),
		(m2 or ""),
		(y2 or "")
	local left = "("
	local right = ")"
	if sq_brts then 
		left = "&#091;"
		right = "&#093;"
	end
	local sep1, sep2, sep3 = {"","",""}, {"",""," "}, "|"
	if wd or wm then sep2 = {"[[","]]"," "}
	else bracketsinside = false end
	if wy then 	sep1 = {"[["," год|","]]"} end
	if (not gy) or (gy == "") then 
		sep1 = {"","",""}
		sep2[3] = ""
	end
	local ngy = ((gy or ""):match("(%d+)") or "")
	if not wy then ngy = "" end
	if bracketsinside and (((gd == "") or (not gd)) or ((gm == "") or (not gm))) then sep3 = "" end
--	mwlog("sep1=",unpack(sep1),"sep2=",unpack(sep2))
	if not bracketsinside then return table.concat({comment[1],trim(trim(jd .. " " .. jm) .. " " .. jy ),
		comment[2],	" ",left,		sep2[1],	trim(gd .. " " .. gm),
		sep2[2],	sep2[3],	sep1[1],	ngy,
		sep1[2],	(gy or ""),	sep1[3],	right,	msg})
	else return table.concat({comment[1],trim(trim(jd .. " " .. jm) .. " " .. jy ),
		comment[2],	" ",left,		sep2[1],	trim(gd .. " " .. gm), "|", trim(gd .. right .. " " .. gm),
		sep2[2],	sep2[3],	sep1[1],	ngy,
		sep1[2],	(gy or ""),	sep1[3],	msg})
	end
end

local function double_couple(jdate, gdate, wd, wm, wy, sq_brts, yearmark, mtext)
	local msg = "" or mtext
	msg = (jdate.msg or "") .. (gdate.msg or "")
	local cd = {}
	local jd = shallowcopy(jdate)
	local gd = shallowcopy(gdate)
	local left = "("
	local right = ")"
	if sq_brts then 
		left = "&#091;"
		right = "&#093;"
	end
	if (not isdate(jdate,true)) or (not isdate(gdate)) then return error("Some wrong date") end
	if jd.year == gd.year then
		cd.year = gd.year
		gd.year, jd.year = nil
	end
	if jd.month == gd.month then
		cd.month = gd.month
		gd.month, jd.month = nil
	end	
	if (not not cd.month) and wm then 
		return table.concat({comment[1] .. trim(day2lang(jd,jdate,false) .. " " .. year2lang(jd.year,yearmark,false)) .. comment[2], 
		trim(left .. day2lang(gd,gdate,wd,wm) .. " " .. year2lang(gd.year,yearmark,wy)) .. right, 
		day2lang(cd,gdate,false) .. "]]", trim(year2lang(cd.year,yearmark,wy)..msg)}, " ")
	end 
	return table.concat({comment[1] .. trim(day2lang(jd,jdate,false) .. " " .. year2lang(jd.year,yearmark,false)) .. comment[2], 
		trim(left .. day2lang(gd,gdate,wd) .. " " .. year2lang(gd.year,yearmark,wy)) .. right, 
		trim(day2lang(cd,gdate,false)), trim(year2lang(cd.year,yearmark,wy)..msg)}, " ")
end

-- 40) Блок функций для перевода дат с использованием [[Юлианская дата]]

function gri2jd( datein )
	if not isdate(datein) then return error("Wrong date") end
    local year = datein.year
    local month = datein.month
    local day = datein.day
    -- jd calculation
    local a = math.floor((14 - month)/12)
    local y = year + 4800 - a
    local m = month + 12*a - 3
    local offset = math.floor(y/4) - math.floor(y/100) + math.floor(y/400) - 32045
    local jd = day + math.floor((153*m + 2)/5) + 365*y + offset
    -- jd validation
    local low, high = -1931076.5, 5373557.49999
    if not (low <= jd and jd <= high) then
        return error("Wrong date")
    end
	return jd
end

function jd2jul( jd )
	if type(jd) ~= "number" then return error("Wrong jd") end
    -- calendar date calculation
    local c = jd + 32082
    local d = math.floor((4*c + 3)/1461)
    local e = c - math.floor(1461*d/4)
    local m = math.floor((5*e + 2)/153)
    local year_out = d - 4800 + math.floor(m/10)
    local month_out = m + 3 - 12*math.floor(m/10)
    local day_out = e - math.floor((153*m + 2)/5) + 1
    -- output
    local dateout = {["year"]=year_out, ["month"]=month_out, ["day"]=day_out}
    return dateout
end

function jul2jd( datein )
	if not isdate(datein,true) then return error("Wrong date") end
    local year = datein.year
    local month = datein.month
    local day = datein.day
    -- jd calculation
    local a = math.floor((14 - month)/12)
    local y = year + 4800 - a
    local m = month + 12*a - 3
    local offset = math.floor(y/4) - 32083
    local jd = day + math.floor((153*m + 2)/5) + 365*y + offset
    -- jd validation
    local low, high = -1930999.5, 5373484.49999
    if not (low <= jd and jd <= high) then
        return error("Wrong date")
    end
	return jd
end

function jd2gri( jd )
    -- calendar date calculation
    local a = jd + 32044
    local b = math.floor((4*a + 3) / 146097)
    local c = a - math.floor(146097*b/4)
    local d = math.floor((4*c+3)/1461)
    local e = c - math.floor(1461*d/4)
    local m = math.floor((5*e+2)/153)
    local day_out =  e - math.floor((153*m+2)/5)+1
    local month_out = m + 3 - 12*math.floor(m/10)
    local year_out = 100*b + d - 4800 + math.floor(m/10)
    -- output
    local dateout = {["year"]=year_out, ["month"]=month_out, ["day"]=day_out}
    return dateout
end

function astroyear(num, bc)
	if not num then return error()
	elseif type(num) ~= "number" then return error()
	end
	if num < 1 then return num end
	if not bc then return num
	else return 1 - num
	end
end

function recalc(datein,calend)
	if inlist(calend,params[1]) then 
		return jd2jul(gri2jd(datein)), datein
   	elseif inlist(calend,params[2]) then
		return datein, jd2gri(jul2jd(datein))
   	else error("Second argument must be 'g' or 'j'")
   	end
end

-- 60) Блок функций ввода-вывода

--  =p.OldDate(mw.getCurrentFrame():newChild{title="smth",args={"31.02.2020","ю",["bc"]="0",["wd"]="1",["wy"]="0",["sq_brts"]="0"}})
-- =p.OldDate(mw.getCurrentFrame():newChild{title="smth",args={"20.02.2020","ю",["bc"]="1",["wd"]="1",["wy"]="1",["sq_brts"]="1",["yearmark"]="г."}})
-- function p.formatWikiImpl( t1, t2, infocardClass, categoryNamePrefix, brts )
function p.OldDate( frame )
    local args = getArgs(frame, { frameOnly = true })
    if not args[1] then return err end
--  mw.log(lang:formatDate("c",args[1])) #time прекрасно кушает 31.02
    local gdate, jdate = {}
    local strin = args[1] 
    local cal = args[2]:lower() or "г"
    local bc = is(args["bc"])
    local wd = is(args["wd"])
    local wm = is(args["wm"])
    local wy = is(args["wy"])
    if not wd then wm = false end
    local sq_brts = is(args["sq_brts"])
    local yearmark = "года"
    if yesno(args["yearmark"]) then
    elseif yesno(args["yearmark"]) == false then yearmark = ""
    else yearmark = trim(args["yearmark"]) or "года" end
--  local infocard = is(args["infocard"])
--  local catName = args["catName"] or false
    local datein = numstr2date(strin)
    datein.year = astroyear(datein.year, bc)
    jdate, gdate = recalc(datein,cal)
	return double_couple(jdate, gdate, wd, wm, wy, sq_brts, yearmark)
end

-- =p.NewDate(mw.getCurrentFrame():newChild{title="Salt",args={"2020-02-20"}})
-- =p.NewDate(mw.getCurrentFrame():newChild{title="smth",args={"20.02.2020","ю",["bc"]="1",["wd"]="1",["wy"]="1",["sq_brts"]="1",["yearmark"]="г."}})
-- =p.NewDate(mw.getCurrentFrame():newChild{title="smth",args={"20.02.2020",["bc"]="0",["wd"]="1",["wy"]="1",["sq_brts"]="0",["yearmark"]=""}})
function p.NewDate( frame )
    local args = getArgs(frame, { frameOnly = true })
    if not args[1] then return err end
	local strin = args[1] 
    local year, month, day
    if     not not strin:match( "(-?%d%d%d%d)-(%d%d)-(%d%d)" ) then
    	year, month, day = strin:match( "(-?%d%d%d%d)-(%d%d)-(%d%d)" )
    elseif not not strin:match( "(-?%d+)-(%d+)-(%d+)" ) then
    	year, month, day = strin:match( "(-?%d+)-(%d+)-(%d+)" )
    elseif not not strin:match( "(%d%d)%.(%d%d)%.(-?%d%d%d%d)" ) then
    	day, month, year = strin:match( "(%d%d)%.(%d%d)%.(-?%d%d%d%d)" )
    elseif not not strin:match( "(%d+)%.(%d+)%.(-?%d+)" ) then
    	day, month, year = strin:match( "(%d+)%.(%d+)%.(-?%d+)" )
	end
	if not year then return error(args[1] .. " не подходит под форматы yyyy-mm-dd или dd.mm.yyyy")
	end
	
	local cal = "г"
	if (not args[2]) or (args[2] == "") then cal = "г"
	else cal = args[2]:lower() end
	
	local bc,wd,wm,wy,sq_brts = 
		is(args["bc"]),
		is(args["wd"]),
		is(args["wd"]) and is(args["wm"]),
		is(args["wy"]),
		is(args["sq_brts"])
	
	year = astroyear(purif(year),bc)
	local datein = {["year"]=purif(year), ["month"]=purif(month), ["day"]=purif(day)}

	jdate, gdate = recalc(datein,cal)

    local yearmark = "года"
    local ym = args["yearmark"] or ""
    if yesno(ym) then
    elseif yesno(ym) == false then yearmark = "" 
    else
    	if not not ym:match("(%d+)") then 
    		error("Цифры в обозначении года: " .. ym)
    	else yearmark = trim(ym) or "года" end
    end
--    mwlog(jdate, gdate, wd, wm, wy, sq_brts, yearmark)
	return double_couple(jdate, gdate, wd, wm, wy, sq_brts, yearmark)
end

-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"23","октября","1858","4","ноября","1858"}})
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={}})
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"3","июня",nil,"21","мая",["wd"]=1,["wm"]=1,["wy"]=1,["bracketsinside"]=1}})
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"3","июня",nil,"21","мая"}})
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"28 августа","","1916 года","15"}})
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"3","июня","1900","21","мая"}})
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"6","июня","1889 год","25","мая"}}) 
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"28","ноября","1917","15"}})
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"28 августа","nil","1916 года","15"}}) 
-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={"4","января","1915","22","декабря","1914 года"}}) 
-- {{OldStyleDate|день (НС)|месяц (НС)|год (НС)|день (СС)|месяц (СС)|год (СС)}}

function p.Test( frame )
	local args = getArgs(frame, { frameOnly = true })
	-- необходима проверка и замена nil на " "
--[[mw.log((args[1] or "") .. " " .. 
		(args[2] or "") .. " " .. 
		(args[3] or "") .. " " .. 
		(args[4] or "") .. " " .. 
		(args[5] or "") .. " " .. 
		(args[6] or "")) ]]--
	local ingdate = triple_txt2date(args[1],args[2],args[3])
	local injdate = triple_txt2date(args[4],args[5],args[6])
	local j1date, g1date, j2date, g2date = init(4)
		mw.log("ingdate-".. (undate(ingdate) or ""))
		mw.log("injdate-".. (undate(injdate) or ""))
	local bc,wd,wm,wy,sq_brts,ny,bracketsinside = 
		is(args["bc"]),
		is(args["wd"]),
		is(args["wd"]) and is(args["wm"]),
		is(args["wy"]),
		is(args["sq_brts"]),
		is(args["ny"]),
		is(args["bracketsinside"])
	-- подавление формата для локальных тестов
    -- local wd, wm, wy = true, true, true
    
    local yearmark = "года" 
    local ym = args["yearmark"] or ((mw.ustring.match((args[3] or ""),"(%a+)") or mw.ustring.match((args[6] or ""),"(%a+)")) or "")
    -- mw.log("ym " .. ym)
    if yesno(ym) then
    elseif yesno(ym) == false then yearmark = "" 
    else
    	if not not ym:match("(%d+)") then 
    		error("Цифры в обозначении года: " .. ym)
    	else yearmark = trim(ym) or "года" end
    end
    if isdate(ingdate) or isdate(injdate) then
		if isdate(ingdate) then
			j1date, g1date = recalc(ingdate,"g")
			ingdate["full"] = true
		end
		if isdate(injdate) then
			j2date, g2date = recalc(injdate,"j")
			injdate["full"] = true
		end
		if ispartdate(ingdate) and ispartdate(injdate) then
--[[		mw.log("📏 " .. dmdist(ingdate,injdate))
			mw.log("📏 " .. dmdist(j1date,g1date))
			mw.log("📏 " .. dmdist(j2date,g2date))
			mw.log("📏 " .. dmdist(ingdate,g1date))
			mw.log("📏 " .. dmdist(injdate,j2date))  ]]--
		end
	end
	
	if ny then 
		if isyear(j1date) then
		else j1date["year"] = "" end
		if isyear(j2date) == nil then
		else j2date["year"] = "" end
		if isyear(g1date) == nil then
		else g1date["year"] = "" end
		if isyear(g2date) == nil then
		else g2date["year"] = "" end
	end

	if (isdate(j1date) and isdate(g1date) and isdate(j2date) and isdate(g2date)) then
		if ((j1date.year == j2date.year)
		and (j1date.month == j2date.month)
		and (j1date.day == j2date.day)) then
			return double_couple(j1date, g1date, wd, wm, wy, sq_brts, yearmark)
		else 
		--	mw.log("📏 " .. (tostring(dmdist(ingdate,injdate)) or ""))
		--	mwlog(args[1],args[2],args[3],args[4],args[5],args[6])
			return glue(args[1],args[2],args[3],args[4],args[5],args[6], wd, wm, wy, sq_brts, yearmark,category["erroneous-parameters"],bracketsinside)  
			-- категория (предположительная разница в днях) и частичный вывод
		end
	elseif isdate(j1date) and isdate(g1date) then
		return double_couple(j1date, g1date, wd, wm, wy, sq_brts, yearmark) -- категория плюс частичная проверка
	elseif isdate(j2date) and isdate(g2date) then
		return double_couple(j2date, g2date, wd, wm, wy, sq_brts, yearmark) -- категория плюс частичная проверка
	elseif (ispartdate(ingdate) and ispartdate(injdate)) then
--[[	mw.log("ingdate ".. (undate(ingdate) or ""))
		mw.log("injdate ".. (undate(injdate) or ""))
		mw.log("j1date " .. (undate(j1date ) or ""))
		mw.log("j2date " .. (undate(j2date ) or ""))
		mw.log("g1date " .. (undate(g1date ) or ""))
		mw.log("g2date " .. (undate(g2date ) or ""))
		mw.log("📏 " .. (tostring(partdist(ingdate,injdate)) or "").. " — " .. (tostring(partdist(injdate,ingdate)) or "")) ]]--
		return glue(args[1],args[2],args[3],args[4],args[5],args[6], wd, wm, wy, sq_brts, yearmark, category["without-verification"],bracketsinside) 
		-- частичный или полный вывод, категория
	else 
--[[	mw.log("ingdate ".. (undate(ingdate) or ""))
		mw.log("injdate ".. (undate(injdate) or ""))
		mw.log("j1date " .. (undate(j1date ) or ""))
		mw.log("j2date " .. (undate(j2date ) or ""))
		mw.log("g1date " .. (undate(g1date ) or ""))
		mw.log("g2date " .. (undate(g2date ) or "")) ]]--
		return err .. category["incomplete-parameters"]
	end
end

local function wikify(link)
	return table.concat{"[[",link,"]]"}
end

local function bullet_list(elem)
	return table.concat{"* ",elem,"\n"}
end
-- =p.read_script(mw.getCurrentFrame():newChild{title="smth",args={"Участник:Carn/common.js"}}) 
function p.read_script(frame)
	local ch_args = frame.args
    local scr_page = mw.title.new(ch_args[1])
    local raw_text = scr_page:getContent()
    local pattern = "importScript%('([^']+)'%)"
    local result = {}
    
    for line in raw_text:gmatch("[^\n]+") do
        local step_result = string.match( line, pattern )
    	if step_result then
            table.insert(result, bullet_list(wikify(step_result)))
    	end
	end

	return table.concat(result)
end

return p
