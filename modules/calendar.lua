local p = {}
-- Необходимые модули и переменные
local getArgs = require('Module:Arguments').getArgs
local yesno = require('Module:Yesno')
local mwlang = mw.getContentLanguage()
local err = "―" -- NthDay nil result
local tCon = table.concat

-- 00) Блок многократно используемых списков
local bool_to_number={ [true]=1, [false]=0 }
local monthlang = {"января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"}
local month_to_num = {["января"]=1,["февраля"]=2,["марта"]=3,["апреля"]=4,["мая"]=5,["июня"]=6,
	["июля"]=7,["августа"]=8,["сентября"]=9,["октября"]=10,["ноября"]=11,["декабря"]=12,["-"]=""}
local monthd = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local params = { {"г", "g"}, {"ю", "j"}}
local comment = { '<span style="border-bottom: 1px dotted; cursor: help" title="по юлианскому календарю">','</span>'}

-- duplicates:
-- AST, BST, CST, ECT, IST, MST, PST, SST, 
local known_tzs = {
   ACDT='+10:30', ACST='+09:30', ACT ='+08:00', ADT  ='-03:00', AEDT ='+11:00',
   AEST='+10:00', AFT ='+04:30', AKDT='-08:00', AKST ='-09:00', AMST ='+05:00',
   AMT ='+04:00', ART ='-03:00', AST ='+03:00', AST  ='+04:00', AST  ='+03:00',
   AST ='-04:00', AWDT='+09:00', AWST='+08:00', AZOST='-01:00', AZT  ='+04:00',
   BDT ='+08:00', BIOT='+06:00', BIT ='-12:00', BOT  ='-04:00', BRT  ='-03:00',
   BST ='+06:00', BST ='+01:00', BTT ='+06:00', CAT  ='+02:00', CCT  ='+06:30',
   CDT ='-05:00', CEDT='+02:00', CEST='+02:00', CET  ='+01:00', CHAST='+12:45',
   CIST='-08:00', CKT ='-10:00', CLST='-03:00', CLT  ='-04:00', COST ='-04:00',
   COT ='-05:00', CST ='-06:00', CST ='+08:00', CVT  ='-01:00', CXT  ='+07:00',
   CHST='+10:00', DFT ='+01:00', EAST='-06:00', EAT  ='+03:00', ECT  ='-04:00',
   ECT ='-05:00', EDT ='-04:00', EEDT='+03:00', EEST ='+03:00', EET  ='+02:00',
   EST ='-05:00', FJT ='+12:00', FKST='-03:00', FKT  ='-04:00', GALT ='-06:00',
   GET ='+04:00', GFT ='-03:00', GILT='+12:00', GIT  ='-09:00', GMT  ='+00:00',
   GST ='-02:00', GYT ='-04:00', HADT='-09:00', HAST ='-10:00', HKT  ='+08:00',
   HMT ='+05:00', HST ='-10:00', IRKT='+08:00', IRST ='+03:30', IST  ='+05:30',
   IST ='+01:00', IST ='+02:00', JST ='+09:00', KRAT ='+07:00', KST  ='+09:00',
   LHST='+10:30', LINT='+14:00', MAGT='+11:00', MDT  ='-06:00', MIT  ='-09:30',
   MSD ='+04:00', MSK ='+03:00', MST ='+08:00', MST  ='-07:00', MST  ='+06:30',
   MUT ='+04:00', NDT ='-02:30', NFT ='+11:30', NPT  ='+05:45', NST  ='-03:30',
   NT  ='-03:30', OMST='+06:00', PDT ='-07:00', PETT ='+12:00', PHOT ='+13:00',
   PKT ='+05:00', PST ='-08:00', PST ='+08:00', RET  ='+04:00', SAMT ='+04:00',
   SAST='+02:00', SBT ='+11:00', SCT ='+04:00', SLT  ='+05:30', SST  ='-11:00',
   SST ='+08:00', TAHT='-10:00', THA ='+07:00', UTC  ='+00:00', UYST ='-02:00',
   UYT ='-03:00', VET ='-04:30', VLAT='+10:00', WAT  ='+01:00', WEDT ='+01:00',
   WEST='+01:00', WET ='+00:00', YAKT='+09:00', YEKT ='+05:00',
   -- US Millitary (for RFC-822)
   Z='+00:00', A='-01:00', M='-12:00', N='+01:00', Y='+12:00',
}

local category = {
	["no_parameters"]=
	"<!--[[Категория:Модуль:Calendar:Страницы без параметров]]-->",
	["incomplete_parameters"]=
	"<!--[[Категория:Модуль:Calendar:Страницы с неполными или некорректными параметрами]]-->",
	["without_verification"]=
	"<!--[[Категория:Модуль:Calendar:Страницы без проверки параметров]]-->",
	["erroneous_parameters"]=
	"<!--[[Категория:Модуль:Calendar:Страницы с ошибочными параметрами]]-->"
}

-- несколько параметров передаются вместе с кодом ошибки в таблице, один может быть передан простым значением
local e = {
	["start"]="<span class=error>Ошибка: ",
	["ending"]=".</span>",
	["no_pattern_match"]="строка «%s» не совпадает с заданными паттернами",
	["no_valid_date"]="дата «%s» не является корректной",
	["wrong_jd"]="юлианская дата %s вне диапазона",
	["no_data"]="нет входящих данных",
	["too_many_arguments"]="ожидается менее %i аргументов",
	["too_little_arguments"]="ожидается более %i аргументов",
	["wrong_calculation"]="даты %s и %s не прошли проверку, %s дней разница",
	["unknown_param"]="параметр %s неизвестен",
	["unknown_error"]="неизвестная ошибка",
	["tech_error"]="ошибка в функции %s",

--	[""]="",
	}

local tzs_names = {"ACDT","ACST","ACT","ADT","AEDT","AEST","AFT","AKDT","AKST",
"AMST","AMT","ART","AST","AST","AST","AST","AWDT","AWST","AZOST","AZT","BDT",
"BIOT","BIT","BOT","BRT","BST","BST","BTT","CAT","CCT","CDT","CEDT","CEST",
"CET","CHAST","CIST","CKT","CLST","CLT","COST","COT","CST","CST","CVT","CXT",
"CHST","DFT","EAST","EAT","ECT","ECT","EDT","EEDT","EEST","EET","EST","FJT",
"FKST","FKT","GALT","GET","GFT","GILT","GIT","GMT","GST","GYT","HADT","HAST",
"HKT","HMT","HST","IRKT","IRST","IST","IST","IST","JST","KRAT","KST","LHST",
"LINT","MAGT","MDT","MIT","MSD","MSK","MST","MST","MST","MUT","NDT","NFT",
"NPT","NST","NT","OMST","PDT","PETT","PHOT","PKT","PST","PST","RET","SAMT",
"SAST","SBT","SCT","SLT","SST","SST","TAHT","THA","UTC","UYST","UYT","VET",
"VLAT","WAT","WEDT","WEST","WET","YAKT","YEKT","Z","A","M","N","Y","MSK"}

local pattern = { -- для распознавания дат, переданных одним строчным параметром
	{"(-?%d%d%d%d?)[-%.%s/\\](%d%d)[-%.%s/\\](%d%d)",  	["order"] = {3,2,1} },  -- yyyy mm dd
	{"(%d+)[-%.%s/\\](%d+)[-%.%s/\\](%d%d%d%d?)",	["order"] = {1,2,3} }, 		-- dd mm yyyy
	{"(%d%d)[-%.%s/\\](%d%d%d%d?)", ["order"] = {2,3} }, 	-- mm yyyy
	{"(%d%d%d%d?)[-%.%s/\\](%d%d)", ["order"] = {3,2} }, 	-- yyyy mm
	{"(%d+)%s(%l+)%s(%d%d%d%d?)", 	["order"] = {1,2,3} }, 	-- d mmm y
	{"(%l+)%s(%d+),?%s(%d%d%d%d?)", ["order"] = {2,1,3} }, 	-- mmm d, y
	{"(%l+)%s(%d%d%d%d?)", 	["order"] = {2,3} }, 			-- mmm y
}

local time_units = {"year","month","day"} --не используется
--[[ local time_units = {"second", "minute", "hour",
    "day_of_month", "day_of_week", "day_of_year",
    "week", "month", "year", "year_of_century", "century"} ]]--
-- напоминание чтобы сделать более точные пересчёты - с часами / расчёт длительностей периодов

local lang = {"ru_G", "ru_N", "en", "de", "fr"}
local month_lang = {
	["ru_G"] = {"января","февраля","марта","апреля","мая","июня",
		"июля","августа","сентября","октября","ноября","декабря"},
	["ru_N"] = {"январь","февраль","март","апрель","май","июнь",
		"июль","август","сентябрь","октябрь","ноябрь","декабрь"},
	["en"] = {"january", "february", "march", "april", "may", "june",
		"july", "august", "september", "october", "november", "december"},
	["de"] = {"januar", "februar", "märz", "april", "mai", "juni",
		"juli", "august", "september", "oktober", "november", "dezember"},
	["fr"] = {"janvier", "février", "mars", "avril", "mai", "juin",
		"juillet", "août", "septembre", "octobre", "novembre", "décembre"}
	}

-- заполняется автоматически
local reverse_month_lang = {}

-- вспомогательная функция для обращения таблиц (смена ключей со значениями)
local reverse_table = function (strait_table)
	local reversed_table = {}
	for k,v in pairs(strait_table) do
		reversed_table[v] = k
	end
	return reversed_table
end

-- запуск цикла по заполнению обратных таблиц, необходимых для распознавания дат
local filling_months = function (lang, month_lang)
	for i=1, #lang do
		reverse_month_lang[lang[i]] = reverse_table(month_lang[lang[i]])
	end
end

-- 10) Блок общих функций
local function trim(str)
	if not str then return nil
	else return str:match'^()%s*$' and '' or str:match'^%s*(.*%S)'
	end
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
	local output = {}
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

local function shallowcopy(orig)
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
local function unwarp(tbl)
	if not tbl then return ""
	elseif type(tbl) ~= "table" then return tbl
	elseif (tbl.day or tbl.month or tbl.year) then
		return (tbl.year or "?").."-"..(tbl.month or "?").."-"..(tbl.day or "?")
	else return (tbl[3] or "?").."-"..(tbl[2] or "?").."-"..(tbl[1] or "?")
	end
end

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

-- функция для вычисления последнего дня месяца для юлианского и григорианского календарей
local function month_end_day (month,year,is_julian)
	local month_end_day = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31} -- если не задан год, дата 29 февраля считается допустимой
	if not month or type(month) ~= "number" or month < 1 or month > 12 then return nil
	elseif month ~= 2 or not year then return month_end_day[month] 
	elseif month == 2 and (year % 4) == 0 and not ((not is_julian) and (year % 100 == 0 and year % 400 ~= 0)) then return 29
	elseif month == 2 then return 28
	else return nil -- в случае не целого значения входящих параметров или при иных непредусмотренных событиях
	end
end

local function isdate ( chain , jul ) -- можно использовать для проверки таблиц с полями day, month, year
	if not chain then return false
	elseif (not type(chain) == "table")
	or (not inbord(chain.year,-9999,9999))
	or (not inbord(chain.month,1,12))
	or (not inbord(chain.day,1,31))
	or chain.day > monthd[chain.month]
--	or chain.year == 0
	then return false
	elseif chain.month == 2 and chain.day == 29 and not leap_year(chain.year,jul)
		then return false
	else return true end
--  check for other calendars needed?
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

-- from date1 to date2 in one year (beetwen jan-dec, dec-jan needed)
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

local function undate(tbl)
	if not tbl then return ""
	else return (tbl.year or "").."-"..(tbl.month or "").."-"..(tbl.day or "")
	end
end

-- функция для нормализации значений дат и перевода месяцев в числа
local function numerize(str)
    if type(str) == "number" then
        return math.floor(str)
	elseif str == "" or str == nil or type(str) ~= "string" then
		return nil
    elseif type(tonumber(str)) == "number" then
        return math.floor(tonumber(str))
    else
    	for i=1, #lang do
    		if inlist(mw.ustring.lower(str),month_lang[lang[i]]) then
				return reverse_month_lang[lang[i]][mw.ustring.lower(str)]
			end
    	end
    end
end

-- функция распознавания даты, переданной одной строкой
local function parse_date(date_string)
	if type(date_string) ~= "string" or date_string == "" then return nil end
	local out_date_str = {"","",""}
	local error_data = {}
	for i=1, #pattern do
		local result_1, result_2, result_3 = mw.ustring.match(mw.ustring.lower(date_string),pattern[i][1])
		if (result_1 or "") > "" then
			out_date_str[pattern[i].order[1]] = result_1
    		out_date_str[pattern[i].order[2]] = result_2
    		if (pattern[i].order[3]) then out_date_str[pattern[i].order[3]] = result_3 end
    	--	mw.log("Паттерн " .. i .. ", строка: " .. date_string)
    		break
		end
	end
	local date = {
		["day"]  =numerize(out_date_str[1]),
		["month"]=numerize(out_date_str[2]),
		["year"] =numerize(out_date_str[3])}
	return date --, error_data
end
----[[ УСТАРЕЛО ]]----
local numstr2date = function(numstr)
	local format = "Y-m-d"
	local iso_date = mwlang:formatDate(format,numstr)
    local y,m,d = string.match(iso_date, "(%d+)-(%d+)-(%d+)")
	local dateout = {["year"]=purif(y), ["month"]=purif(m), ["day"]=purif(d)}
    return dateout
end
--local numstr2date = function(numstr)
--	local nums = {}
--    local dateout = {}
--    for num in string.gmatch(numstr,"(%d+)") do
--        table.insert(nums,purif(num))
--    end
--    if #nums ~= 3 then error("В поле даты вместо трёх чисел с разделителями указано " .. #nums)
--    elseif not inbord(nums[2],1,12) then error("Месяц с номером " .. nums[2] .. " не найден")
--    elseif not inbord(nums[3],1,31) then
--        dateout = {["year"]=nums[3], ["month"]=nums[2], ["day"]=nums[1]}
--    elseif not inbord(nums[1],1,31) then
--        dateout = {["year"]=nums[1], ["month"]=nums[2], ["day"]=nums[3]}
--    elseif inbord(nums[1],1,31) then
--        dateout = {["year"]=nums[3], ["month"]=nums[2], ["day"]=nums[1]}
--    else
--		local mwlang = mw.getContentLanguage()
--		implement mwlang:formatDate(format,datein,true) here
--        return error("Не распознано " .. numstr .. " как дата")
--    end
--    return dateout
--end

local function year2lang(numyear,yearmark,wiki)
	if not numyear then return "" end
	if not yearmark then yearmark = "" end
	local output = ""
	local bcmark = " до н. э."
	if numyear > 0 then	bcmark = ""
	else numyear = 1 - numyear end
	if wiki then 
--		output = tCon({'[[', numyear,' год',bcmark,'|', numyear,']]', " ", yearmark, " ", bcmark})
		output = tCon({'[[', numyear,' год',bcmark,'|', trim(numyear .. " " .. yearmark .. " " .. bcmark), ']]'})
	else
		output = tCon({numyear, " ", yearmark, bcmark})
	end
	return trim(output)
end
	
local function day2lang(datein,wikidate,wiki,inner_brt)
--	if not isdate(wikidate) then wiki = false end
	if not ispartdate(datein) then return "" end
	local dm_separ, output = "", nil
	if (not (not datein.day)) and (not (not datein.month)) then dm_separ = " " end
	if (not datein.month) then datein.month = "" end
	if (not datein.day) then datein.day = "" end
	local monlan = monthlang[datein.month] or ""
	if wiki and not inner_brt then
		output = tCon({"[[", wikidate.day, " ", monthlang[wikidate.month] or "",
			"|", (datein.day or ""), dm_separ, monlan, "]]"})
	elseif wiki then
		output = tCon({"[[", wikidate.day, " ", monthlang[wikidate.month] or "",
			"|", (datein.day or ""), dm_separ, monlan})
	else
		output = tCon({datein.day, dm_separ, monlan})
	end
    return trim(output)
end

local function triple_txt2date(d,m,y)
	-- добавить (args[1]:match("(%a+)") or "-") для нестандартной записи
	-- mw.ustring.match((m or ""),"(%a+)")
	local msg = ""
	local year = purif((y or "-"):match("(%d+)"))
	local month = purif(month_to_num[string.lower(mw.ustring.match((m or ""),"(%a+)"))])
	local day = purif((d or "-"):match("(%d+)"))
	if not month then 
		msg = category.incomplete_parameters
		month = purif(month_to_num[string.lower(mw.ustring.match((d or ""),"(%a+)") or "-")]) 
	end
	if (not day) and ((purif(string.match(m or "","(%d+)") or "") or 32) <= (monthd[month] or 31)) then 
		msg = category.incomplete_parameters
		day = purif(m:match("(%d+)") or "") 
	end
	if not year then 
		msg = category.incomplete_parameters
		year = purif(string.match(m or "","(%d+)") or "") 
	end
	local dateout = {["year"]=year, ["month"]=month, ["day"]=day, ["msg"]=msg}
	return dateout
end

local function glue(d1,m1,y1,d2,m2,y2)
	if (not d1) and (not m1) and (not y1) and (not d2) and (not m2) and (not y2) then
		return category.incomplete_parameters end
	local gd,gm,gy,jd,jm,jy = 
		(d1 or ""),
		(m1 or ""),
		(y1 or ""),
		(d2 or ""),
		(m2 or ""),
		(y2 or "")
	--mw.log(tCon({gd,gm,gy,jd,jm,jy}))
	local gm_sep = {" [["," год|","]]"}
	if (not gy) or (gy == "") then gm_sep = {"","",""} end
	return tCon({comment[1],trim(trim(jd .. " " .. jm) .. " " .. jy ),
		comment[2]," ([[",trim(gd .. " " .. gm),"]]",gm_sep[1],(gy:match("(%d+)") or ""),
		gm_sep[2],gy,gm_sep[3],")",category.incomplete_parameters})
end

-- добавить отображение без года
local function double_couple(jdate, gdate, wd, wm, wy, sq_brts, yearmark)
	local msg = ""
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
	if (not isdate(jdate,true)) then return error((jdate.day or "") .. "." .. (jdate.month or "") .."." .. (jdate.year or "") .. " неподходящая дата")
	elseif (not isdate(gdate)) then return error((gdate.day or "") .. "." .. (gdate.month or "") .."." .. (gdate.year or "") .. " неподходящая дата") end
	if jd.year == gd.year then
		cd.year = gd.year
		gd.year, jd.year = nil, nil
	end
	if jd.month == gd.month then
		cd.month = gd.month
		gd.month, jd.month = nil, nil
	end	
	if (not not cd.month) and wm then 
		return tCon({comment[1] .. trim(day2lang(jd,jdate,false) .. " " .. year2lang(jd.year,yearmark,false)) .. comment[2], 
		trim(left .. day2lang(gd,gdate,wd,wm) .. " " .. year2lang(gd.year,yearmark,wy)) .. right, 
		day2lang(cd,gdate,false) .. "]]", trim(year2lang(cd.year,yearmark,wy)..msg)}, " ")
	end 
	return tCon({comment[1] .. trim(day2lang(jd,jdate,false) .. " " .. year2lang(jd.year,yearmark,false)) .. comment[2], 
		trim(left .. day2lang(gd,gdate,wd) .. " " .. year2lang(gd.year,yearmark,wy)) .. right, 
		trim(day2lang(cd,gdate,false)), trim(year2lang(cd.year,yearmark,wy)..msg)}, " ")
end

-- 40) Блок функций для перевода дат с использованием [[Юлианская дата]]

local function gri2jd( datein )
	if not isdate(datein) then return error((datein.day or "") .. "." .. (datein.month or "") .."." .. (datein.year or "") .. " неподходящая дата") end
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
        return error((datein.day or "") .. "." .. (datein.month or "") .. "." .. (datein.year or "") .. " выходит за пределы разрешённого диапазона")
    end
	return jd
end

local function jd2jul( jd )
	if type(jd) ~= "number" then return error("Промежуточная переменная " .. (jd or "") .. " не является числом") end
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

local function jul2jd( datein )
	if not isdate(datein,true) then return error((datein.day or "") .. "." .. (datein.month or "") ..".".. (datein.year or "") .. " неподходящая дата") end
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
        return error((datein.day or "") .. "." .. (datein.month or "") .."." .. (datein.year or "") .. " выходит за пределы разрешённого диапазона")
    end
	return jd
end

local function jd2gri( jd )
	if type(jd) ~= "number" then return error("Промежуточная переменная " .. (jd or "") .. " не является числом") end
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

local function astroyear(num, bc)
	if not num then return error()
	elseif type(num) ~= "number" then return error()
	end
	if num < 1 then return num end
	if not bc then return num
	else return 1 - num
	end
end

local function recalc(datein,calend)
	if inlist(calend,params[1]) then 
		return jd2jul(gri2jd(datein)), datein
   	elseif inlist(calend,params[2]) then
		return datein, jd2gri(jul2jd(datein))
   	else error("Параметр " .. (calend or "") .. " не опознан, разрешённые: " .. tCon(params[1]," ") .. " и " .. tCon(params[2]," "))
   	end
end

-- 50) Функции для обработки UTC

local function utc(str,margin)
	local d = 1
	local dchar = "+"
	local beginning = "[[UTC"
	local ending = "]]"
	local cat = ""
	local nums = {}
	local hmarg, timedec = 0, 0
	local mmarg = "00"
	local output = ""
-- checking type of input
	if not margin then margin = 0
	elseif type(tonumber(margin)) ~= 'number' then
		output = "Can't shift by " .. margin
		error(output)
	end
	if type(str) ~= 'string' then
		error("Нет входящей строки")
	elseif str:byte(1) == 43 then
	elseif inbord(str:byte(1),48,57) then cat = "[[Категория:Википедия:Ошибка в часовом поясе НП]]"
	elseif str:byte(1) == 45 or string.sub(str,1,3) == "−" or string.sub(str,1,1)=="-" then d = -1
	else
		error(string.char(str:byte(1)) .. " недопустимый первый символ")
	end
-- parsing input
	for num in string.gmatch(str,"(%d+)") do
        table.insert(nums,purif(num))
    end
	if #nums > 2 then error("Ожидается всего 2 числа, а не " .. #nums)
	elseif #nums == 0 then error("Необходимо что-то ввести")
	elseif #nums == 1 then
		if inbord(nums[1],0,14) then timedec = d*nums[1] + margin
		else error("Только часы от -14 до 14") end
	elseif #nums == 2 then
		if not inbord(nums[1],0,14) then error("Только часы от -14 до 14")
		elseif not inbord(nums[2],0,59) then error("Минуты только от 0 до 59")
		else
			timedec = d*(nums[1] + nums[2]/60) + margin
		end
	end
	if tonumber(timedec) == purif(timedec) then hmarg = timedec
	else
		local h, m = math.modf(math.abs(timedec))
		hmarg = h
		mmarg = math.floor(m*60)
	end
	if timedec == 0 then
		dchar = "±"
	elseif timedec > 0 then
	elseif timedec < 0 then
		dchar = "&minus;"
	end
-- output
	output = beginning .. dchar .. math.abs(hmarg) .. ":" .. string.format("%02d",mmarg) .. ending .. cat
	return output
end

-- 60) Блок функций ввода-вывода

function p.NthDay( frame )
    local args = getArgs(frame, { frameOnly = true })
    local num, wday, mont, yea, format = 
    	purif(args[1]), purif(args[2]), purif(args[3]), purif(args[4]), args[5]
	if not format then format = "%d.%m.%y" end
    if not inbord(num,-5,5) then 
    	return error("The number must be between -5 and 5")
    elseif num == 0 then 
    	return error("The number must not be zero") end
    if not inbord(wday,0,6) then 
    	return error("The day of the week must be between 0 and 6") end
    if not inbord(mont,1,12) then 
    	return error("The month must be between 1 and 12") end
    if not inbord(yea,0,9999) then 
    	return error("Wrong year number") end
    if inbord(num,1,5) then
        local m_start = os.time{year=yea, month=mont, day=1, hour=0}
        local m_wds = tonumber(os.date("%w", m_start)) 
        local start_shift = (
            (num - bool_to_number[wday >= m_wds]) * 7 
            - (m_wds - wday)
            ) * 24 * 60 * 60
        local tim = m_start + start_shift
        if tonumber(os.date("%m", tim)) == mont then
            return (os.date(format, tim))
        else
            return (err)
        end
    elseif inbord(num,-5,-1) then
        local m_end = os.time{year = yea, month = mont + 1, day = 1, hour = 0} - 24 * 60 * 60
        local m_wde = tonumber(os.date("%w", m_end))
        local end_shift = ((math.abs(num + 1) + bool_to_number[wday > m_wde]) * 7 
            + (m_wde - wday)) * 24 * 60 * 60
        local tim = m_end - end_shift
        if tonumber(os.date("%m", tim)) == mont then
            return (os.date(format, tim))
        else
            return (err)
        end
    end
end

-- =p.ToIso(mw.getCurrentFrame():newChild{title="smth",args={"12 декабря 2020"}})
-- =p.ToIso(mw.getCurrentFrame():newChild{title="smth",args={"1.2.1602"}})
-- =p.ToIso(mw.getCurrentFrame():newChild{title="smth",args={"12.12.2021"}})
-- =p.ToIso(mw.getCurrentFrame():newChild{title="smth",args={"2021.12.12"}})
function p.ToIso( frame ) 
    local args = getArgs(frame, { frameOnly = true })
    local datein = args[1]
    -- инициализация, заполнение обратных таблиц, копирование параметров
	filling_months(lang, month_lang)
    -- парсинг входящей даты по шаблону
    local date = parse_date(datein)
    if not (type(date.year) == 'number') then 
        return ("Wrong year: " .. unwarp(date))
    end
    if not (1 <= date.month and date.month <= 12) then 
        return ("Wrong month: " .. unwarp(date))
    end
    if not date.day or not (1 <= date.day and date.day <= month_end_day(date.month,date.year)) then 
        return ("Wrong day: " .. unwarp(date))
    end
    local timedate = os.time{year=date.year, month=date.month, day=date.day}
    local date = os.date("%Y-%m-%d", timedate)
    return date
end

-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"12 декабря 2020"}})
-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"1.2.1602"}})
-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"декабрь 2020"}})
-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"12-2020"}})
-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"12.12.2021"}})
-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"2021.12.12"}})
-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"2021.11"}})
-- =p.BoxDate(mw.getCurrentFrame():newChild{title="smth",args={"11.2021"}})
function p.BoxDate( frame ) 
    local args = getArgs(frame, { frameOnly = true })
    local datein = args[1]
    return (p.bxDate( datein ))
end

function p.bxDate( txtDateIn , strFormat, params ) -- к отладке
	local txtDateOut, date, status = "", {}, {brk = false, errorCat = "", errorText = ""}
	strFormat = strFormat or "j xg Y"
	-- заглушка - таблица параметров на будущее
	params = params or {}
	if not txtDateIn then 
		status.errorText = tCon(e.start,e.no_data,e.ending)
		status.errorCat = category.no_parameters
		status.brk = true
	else
		-- заполнение служебных таблиц
		filling_months(lang, month_lang)
	end
	if not status.brk then
		-- парсинг входящей даты по шаблону
		date = parse_date(txtDateIn)
	    -- заменить сообщения об ошибках на списочные
	    if not (type(date.year) == 'number') then 
	    	status.errorText = tCon{e.start,string.format(e.no_pattern_match,txtDateIn),"; ",string.format(e.no_valid_date,unwarp(date)),e.ending}
	    	status.errorCat = category.incomplete_parameters
	    	status.brk = true
	    end
	    if not inbord(date.month,1,12) then 
	    	status.errorText = tCon{e.start,string.format(e.no_pattern_match,txtDateIn),"; ",string.format(e.no_valid_date,unwarp(date)),e.ending}
	    	status.errorCat = category.incomplete_parameters
	    	status.brk = true
	    end
	    if not date.day then
	    	strFormat = trim(string.gsub(string.gsub(strFormat,"xg","F"),"[dDjlNwzW]",""))
	    elseif not inbord(date.day,1,month_end_day(date.month,date.year)) then 
	        status.errorText = tCon{e.start,string.format(e.no_pattern_match,txtDateIn),"; ",string.format(e.no_valid_date,unwarp(date)),e.ending}
	        status.errorCat = category.incomplete_parameters
	    	status.brk = true
	    end
	end
	if not status.brk then
		txtDateOut = mwlang:formatDate(strFormat,tCon({date.year,date.month,date.day},"-"),true)
	end
    return txtDateOut, date, status
end

function p.ToDate( frame ) -- возможно неиспользуемая
    local args = getArgs(frame, { frameOnly = true })
    local mwlang = mw.getContentLanguage()
    local datein = args[1]
    local format = "j xg Y"
    if not string.match(datein, "%p") then return datein
    elseif not args[2] then
    else format = args[2]
    end
    return mwlang:formatDate(format,datein,true)
end

-- =p.unitime(mw.getCurrentFrame():newChild{title="smth",args={"−1:30","1"}})

function p.unitime( frame )
    local args = getArgs(frame, { frameOnly = true })
    local DST = 0
    if not args[2] then 
    else DST = 1 end
    local utcin = ""
    local input = args[1]
    if not input then return "" end
    if inlist(input:upper(),tzs_names) then 
    	utcin = known_tzs[input:upper()] 
    elseif (string.sub(input:upper(),1,3) == 'UTC') and (string.len(input) < 10) then
    	utcin = string.sub(input,4)
    else 
    	if string.sub(input,1,1) == '[' 
        or string.sub(input,1,1) == '{' 
        or string.sub(input,1,1):upper() == 'U' 
        or string.sub(input,1,1):upper() == 'M' then
    	    return input 
--      elseif not string.find(string.upper(string.sub(input,1,1)),"[\65-\90]") or
--      not string.find(string.upper(string.sub(input,1,1)),"[\192-\223]") then
--    	return input
    	else utcin = input end 
    end
--  elseif string.sub(input,1,3) ~= "−" then utcin = input
--  or not (not input:find("[А-я]")) при наличии в строке юникода не работает
    local output = ""
    if DST == 0 then output = utc(utcin)
    else output = utc(utcin) .. ", [[летнее время|летом]] " .. utc(utcin,DST)
    end
    return output
end


-- УСТАРЕЛО
-- =p.OldDate(mw.getCurrentFrame():newChild{title="smth",args={"20.02.2020","ю",["bc"]="1",["wd"]="1",["wy"]="1",["sq_brts"]="1",["yearmark"]="г."}})
function p.OldDate( frame )
    local args = getArgs(frame, { frameOnly = true })
    if not args[1] then return err end
    local gdate, jdate = {}, {}
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
    if     not not strin:match( "(-?%d%d%d%d%d)-(%d%d)-(%d%d)" ) then
    	year, month, day = strin:match( "(-?%d%d%d%d%d)-(%d%d)-(%d%d)" )
    elseif not not strin:match( "(-?%d+)-(%d+)-(%d+)" ) then
    	year, month, day = strin:match( "(-?%d+)-(%d+)-(%d+)" )
    elseif not not strin:match( "(%d%d)%.(%d%d)%.(-?%d%d%d%d%d)" ) then
    	day, month, year = strin:match( "(%d%d)%.(%d%d)%.(-?%d%d%d%d%d)" )
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

	local jdate, gdate = recalc(datein,cal)

    local yearmark = "года"
    local ym = args["yearmark"] or ""
    if yesno(ym) then
    elseif yesno(ym) == false then yearmark = "" 
    else
    	if not not ym:match("(%d+)") then 
    		error("Цифры в обозначении года: " .. ym)
    	else yearmark = trim(ym) or "года" end
    end

	return double_couple(jdate, gdate, wd, wm, wy, sq_brts, yearmark)
end

-- =p.Test(mw.getCurrentFrame():newChild{title="smth",args={}})
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
	local bc,wd,wm,wy,sq_brts,ny = 
		is(args["bc"]),
		is(args["wd"]),
		is(args["wd"]) and is(args["wm"]),
		is(args["wy"]),
		is(args["sq_brts"]),
		is(args["ny"])
	-- подавление формата для локальных тестов
    local wd, wm, wy = true, true, true
    
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
			mw.log("📏 " .. dmdist(ingdate,injdate))
			mw.log("📏 " .. dmdist(j1date,g1date))
			mw.log("📏 " .. dmdist(j2date,g2date))
			mw.log("📏 " .. dmdist(ingdate,g1date))
			mw.log("📏 " .. dmdist(injdate,j2date))
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
			mw.log("📏 " .. (tostring(dmdist(ingdate,injdate)) or ""))
			return glue(args[1],args[2],args[3],args[4],args[5],args[6])  
			-- категория (предположительная разница в днях) и частичный вывод
		end
	elseif isdate(j1date) and isdate(g1date) then
		return double_couple(j1date, g1date, wd, wm, wy, sq_brts, yearmark) -- категория плюс частичная проверка
	elseif isdate(j2date) and isdate(g2date) then
		return double_couple(j2date, g2date, wd, wm, wy, sq_brts, yearmark) -- категория плюс частичная проверка
	elseif (ispartdate(ingdate) and ispartdate(injdate)) then
		mw.log("ingdate ".. (undate(ingdate) or ""))
		mw.log("injdate ".. (undate(injdate) or ""))
		mw.log("j1date " .. (undate(j1date ) or ""))
		mw.log("j2date " .. (undate(j2date ) or ""))
		mw.log("g1date " .. (undate(g1date ) or ""))
		mw.log("g2date " .. (undate(g2date ) or ""))
		mw.log("📏 " .. (tostring(partdist(ingdate,injdate)) or "").. " — " .. (tostring(partdist(injdate,ingdate)) or ""))
		return glue(args[1],args[2],args[3],args[4],args[5],args[6]) 
		-- частичный или полный вывод, категория
	else 
		mw.log("ingdate ".. (undate(ingdate) or ""))
		mw.log("injdate ".. (undate(injdate) or ""))
		mw.log("j1date " .. (undate(j1date ) or ""))
		mw.log("j2date " .. (undate(j2date ) or ""))
		mw.log("g1date " .. (undate(g1date ) or ""))
		mw.log("g2date " .. (undate(g2date ) or ""))
		return err .. category.incomplete_parameters
	end
end

return p