local p = {}
-- Необходимые модули и переменные

local getArgs = require('Module:Arguments').getArgs

local err = "―" -- NthDay nil result

-- 00) Блок многократно используемых списков
--[==[ Таблицы с данными для работы модуля ]==]

local pattern = { -- для распознавания дат, переданных одним строчным параметром
	{"(-?%d+%d*)-(%d+)-(%d+)",  	["order"] = {3,2,1} },  -- y-m-d
	{"(%d+)%.(%d+)%.(-?%d+%d*)",	["order"] = {1,2,3} }, 	-- d.m.y
	{"(%d+)%s(%d+)%s(-?%d+%d*)",	["order"] = {1,2,3} }, 	-- d m y
	{"(%d+)%s(%a+)%s(-?%d+%d*)", 	["order"] = {1,2,3} }, 	-- d mmm y
} 

local time_units = {"year","month","day"}
--[[ local time_units = {"second", "minute", "hour", 
    "day_of_month", "day_of_week", "day_of_year", 
    "week", "month", "year", "year_of_century", "century"} ]]--
-- напоминание чтобы сделать расчёт длительностей периодов

local category_msg = ""
local category = {
    ["incomplete_parameters"]=
    "<!--[[Категория:Модуль:Calendar:Страницы с неполными или некорректными параметрами]]-->",
    ["without_verification"]=
    "<!--[[Категория:Модуль:Calendar:Страницы без проверки параметров]]-->",
    ["erroneous_parameters"]=
    "<!--[[Категория:Модуль:Calendar:Страницы с ошибочными параметрами]]-->"
}

-- несколько параметров передаются вместе с кодом ошибки в таблице, один может быть передан простым значением
local errors = {
    ["start"]="<span class=error>Ошибка: ",
    ["ending"]=".</span>",
    ["no_pattern_match"]="строка «%s» не совпадает с заданными паттернами",
    ["no_valid_date"]="дата «%s·%s·%s» не является корректной",
    ["wrong_jd"]="юлианская дата %s вне диапазона",
    ["too_many_arguments"]="ожидается менее %i аргументов",
    ["too_little_arguments"]="ожидается более %i аргументов",
    ["wrong_calculation"]="даты %s и %s не прошли проверку, %s дней разница",
    ["unknown_calendar"]="параметр календаря %s неизвестен",
    ["unknown_error"]="неизвестная ошибка",
    ["tech_error"]="ошибка в функции %s",
--	[""]="",
}

-- для повышения гибкости вывода можно указать отдельные параметры для первой и второй даты
-- для повышения удобства пользователя заданные одним параметром аргументы дублируются
local unik_args = {	"order","lang", "cal", "bc", "sq_brts" }
local unik_args_bool = {false,false,false,true,true,true}
-- mode, i/o lang, calendar before christ, square brackets -- brackets inside?
local dual_args = { "wdm", "wy", "ny", "ym"}
local dual_args_bool = {true,true,true,false}
-- wikify day and month, wikify year, no year, year mark

local status = {category="",error={msg="",params=""}}
local bool2num={[1]=1, [0]=0, ["1"]=1, ["0"]=0, [true]=1, [false]=0, 
	["__index"]=function(self,v) 
		return tostring(v)
	end }
setmetatable(bool2num,bool2num)

local bool_to_number=bool2num -- XXX mark for deletion XXX
local monthlang = {"января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"}
local month_to_num = {["января"]=1,["февраля"]=2,["марта"]=3,["апреля"]=4,["мая"]=5,["июня"]=6,
	["июля"]=7,["августа"]=8,["сентября"]=9,["октября"]=10,["ноября"]=11,["декабря"]=12,["-"]=""}
local monthd = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local calendars = {{"г", "g"}, {"ю", "j"}} 
local comment = { '<span style="border-bottom: 1px dotted; cursor: help" title="по юлианскому календарю">','</span>'}
-- local category = {["params"]="<!--[[Категория:Модуль:calendar:Страницы с некорректными параметрами]]-->"}

-- в случае обновления таблицы названий месяцев необходимо также обновлять список кодов языков
local bc_mark = "до н. э."
local lang = {"ru", "en", "de", "fr"}
local month_lang = {
	["ru"] = {"января","февраля","марта","апреля","мая","июня",
		"июля","августа","сентября","октября","ноября","декабря"},
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

-- AST = Atlantic Standard Time -4, Arabia Standard Time +3,
-- BST = British Summer Time +1, Bangladesh Standard Time +6
-- CST = Central Standard Time -6, China Standard Time +8
-- IST = India Standard Time +5:30, Irish Standard Time +1, Israel Standard Time +2
-- MST = Malaysia Standard Time +8, Mountain Time Zone -7, +06:30
-- PST = Pacific Standard Time -8, Pakistan Standard Time +5, Philippine Standard Time +8
-- ECT = Ecuador Time -5, '-04:00'
-- SST = Singapore Standard Time +8, Samoa Standard Time -11
local known_tzs = {
   ACDT='+10:30', ACST='+09:30', ACT ='+08:00', ADT  ='-03:00', AEDT ='+11:00',
   AEST='+10:00', AFT ='+04:30', AKDT='-08:00', AKST ='-09:00', AMST ='+05:00',
   AMT ='+04:00', ART ='-03:00', 
   AST ='-04:00', AWDT='+09:00', AWST='+08:00', AZOST='-01:00', AZT  ='+04:00',
   BDT ='+08:00', BIOT='+06:00', BIT ='-12:00', BOT  ='-04:00', BRT  ='-03:00',
   BST ='+01:00', BTT ='+06:00', CAT ='+02:00', CCT  ='+06:30',
   CDT ='-05:00', CEDT='+02:00', CEST='+02:00', CET  ='+01:00', CHAST='+12:45',
   CIST='-08:00', CKT ='-10:00', CLST='-03:00', CLT  ='-04:00', COST ='-04:00',
   COT ='-05:00', CST ='-06:00', CVT ='-01:00', CXT  ='+07:00',
   CHST='+10:00', DFT ='+01:00', EAST='-06:00', EAT  ='+03:00', 
   ECT ='-05:00', EDT ='-04:00', EEDT='+03:00', EEST ='+03:00', EET  ='+02:00',
   EST ='-05:00', FJT ='+12:00', FKST='-03:00', FKT  ='-04:00', GALT ='-06:00',
   GET ='+04:00', GFT ='-03:00', GILT='+12:00', GIT  ='-09:00', GMT  ='+00:00',
   GST ='-02:00', GYT ='-04:00', HADT='-09:00', HAST ='-10:00', HKT  ='+08:00',
   HMT ='+05:00', HST ='-10:00', IRKT='+08:00', IRST ='+03:30', IST  ='+05:30',
   JST ='+09:00', KRAT='+07:00', KST ='+09:00',
   LHST='+10:30', LINT='+14:00', MAGT='+11:00', MDT  ='-06:00', MIT  ='-09:30',
   MSD ='+04:00', MSK ='+03:00', MST ='+08:00',
   MUT ='+04:00', NDT ='-02:30', NFT ='+11:30', NPT  ='+05:45', NST  ='-03:30',
   NT  ='-03:30', OMST='+06:00', PDT ='-07:00', PETT ='+12:00', PHOT ='+13:00',
   PKT ='+05:00', PST ='-08:00', RET ='+04:00', SAMT ='+04:00',
   SAST='+02:00', SBT ='+11:00', SCT ='+04:00', SLT  ='+05:30',
   SST ='+08:00', TAHT='-10:00', THA ='+07:00', UTC  ='+00:00', UYST ='-02:00',
   UYT ='-03:00', VET ='-04:30', VLAT='+10:00', WAT  ='+01:00', WEDT ='+01:00',
   WEST='+01:00', WET ='+00:00', YAKT='+09:00', YEKT ='+05:00',
   -- US Millitary (for RFC-822)
   Z='+00:00', A='-01:00', M='-12:00', N='+01:00', Y='+12:00',
}

-- VVV needs to be filled automaticly VVV
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

-- 10) Блок общих функций
--[==[ Функции универсального назначения ]==]
-- вспомогательная функция для проверки вхождения числа в диапазон
local function number_in_range(value, bottom, top)
	if type(value) ~= "number" or type(top) ~= "number" or type(bottom) ~= "number" 
		or top < bottom or value < bottom or value > top then return false
    else return true end
end

-- mw.clone копирует с метатаблицами
-- для определения наибольшего индекса в таблице есть table.maxn
local function copy_it(original)
	local c = {}
	if type(original) == "table" then
		for key, value in pairs(original) do
			if value == "" or value == " " then
				value = nil
			end
			c[key] = value
		end
	else return original, 1
	end
	for i = 7, 1, -1 do
		if c[i] then 
			return c, i
		end
	end
	return c, 0
end 

-- функция, определяющая, содержит ли таблица необходимое число аргументов
local function is_complete(table_in,start,finish)
	if type(table_in) ~= "table" or type(start) ~= "number" or type(finish) ~= "number" or start > finish then 
		return nil
	else 
		for i=start,finish do
			if not table_in[i] then 
				return false 
			end
		end
	end
	return true
end

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

local yesno = require('Module:Yesno')
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

-- функция для проверки, содержит ли массив запрашиваемое значение
local is_in_list = function ( var, list )
	for i=1, #list do
		if var == list[i] then
			return true
		end
	end
    return false
end

-- XXX mark for deletion XXX
local inlist = is_in_list --[[ function ( var, list )
    local n = #list
	local inlist = false
	for i=1,n do
		if var == list[i] then inlist = true end
	end
    return inlist
end 
--]]

--[==[ Календарные функции ]==]
-- функция для вычисления последнего дня месяца для юлианского и григорианского календарей
-- 20) Блок общих проверочных функций, связанных с датами

-- VVV В функцию необходима поправка для формата дат с разрывом в ноле VVV
local function month_end_day (month,year,is_julian)
	local mo_end_day = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31} -- если не задан год, дата 29 февраля считается допустимой
	if not month or type(month) ~= "number" or month < 1 or month > 12 then return nil
	elseif month ~= 2 or not year then return mo_end_day[month] 
	elseif month == 2 and (year % 4) == 0 and not ((not is_julian) and (year % 100 == 0 and year % 400 ~= 0)) then return 29
	elseif month == 2 then return 28
	else return nil -- в случае не целого значения входящих параметров или при иных непредусмотренных событиях
	end
end

-- ХХХ функция к удалению ХХХ
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

-- функция, проверяющая, корректная ли дата содержится в таблице
-- считает что -300 это трёхсотый год д.н.э.
local function is_date ( date, is_julian )
	if not date or type(date) ~= "table" then return false
	elseif	not number_in_range(date.month,1,12) or
			not number_in_range(date.day,1,month_end_day(date.month,date.year,is_julian)) or
			not number_in_range(date.year,-9999,9999) then
				return false
	elseif date.year ~= 0 then return true
	end
end	

-- ХХХ к удалению - позволяет нулевой год ХХХ
function isdate ( chain , jul ) -- можно использовать для проверки таблиц с полями day, month, year
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

-- функция для проверки, содержит ли таблица частичные сведения о дате
local is_date_part = ispartdate--[[ ( date )
	if not date then return false
	elseif not (type(date) == "table") then return false
	elseif (number_in_range(date.year,-9999,9999)
	or number_in_range(date.month,1,12)
	or number_in_range(date.day,1,31)) then return true
	else return false
	end
end 
--]]

-- для дат, порядок которых неизвестен, пробует сначала прямой (dmy), затем обратный (ymd) порядок
local function guess_date( triplet, is_julian ) -- только для дат после 31 года, пока не используется
	local date = {["day"]=triplet[1],["month"]=triplet[2],["year"]=triplet[3]}
	if is_date(date,is_julian) then return date end
	local date = {["day"]=triplet[3],["month"]=triplet[2],["year"]=triplet[1]}
	if is_date(date,is_julian) then return date end
end

local function partdist(status,date1,date2)
	local mont, dist = 0, 0
	local d1d, d1m, d2d, d2m = date1["day"], date1["month"], date2["day"], date2["month"]
	local d1de, d2de = month_end_day(d1m), month_end_day(d2m)
	if not (number_in_range(d1m,1,12) and number_in_range(d2m,1,12)) then 
		return status, math.huge
	elseif not (number_in_range(d1d,1,d1de) and number_in_range(d2d,1,d2de)) then 
		return status, math.huge
	else
		return status, (d1m == d2m and math.abs(d1d-d2d)) or ((d1d > d2d and (d1de - d1d + d2d)) or (d2de - d2d + d1d))
	end
end

-- from date1 to date2 in one year (beetwen jan-dec, dec-jan needed)
-- XXX          DELETE          XXX
local function partdist_old(date1,date2)
	local st, dist = partdist({},date1,date2)
	return dist
end
--[==[
local function partdist_old(date1,date2)
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
--]==]

local function unwarp(tbl)
	if not tbl then return ""
	elseif type(tbl) ~= "table" then return tbl
	elseif (tbl.day or tbl.month or tbl.year) then 
		return (tbl.year or "¤").."•"..(tbl.month or "¤").."•"..(tbl.day or "¤")
	else return (tbl[3] or "¤").."-"..(tbl[2] or "¤").."-"..(tbl[1] or "¤")
	end
end

local function guess_jd(status, first_date, second_date)
--	if not is_date(first_date) or is_date(second_date) then
--		return status
--	end
	local first_j_jd = jul2jd(first_date)
	local first_g_jd = gri2jd(first_date)
	local second_j_jd = jul2jd(second_date) 
	local second_g_jd = gri2jd(second_date)
--	mw.log(first_j_jd,first_g_jd,second_j_jd,second_g_jd)
	if not first_j_jd or not first_g_jd or not second_j_jd or not second_g_jd then
		local status, difference = partdist(status,first_date,second_date)
		status.category = "erroneous_parameters"
		status.error.msg = "wrong_calculation"
		status.error.params = {unwarp(first_date),unwarp(second_date),difference}
	elseif first_j_jd == second_g_jd then
		first_date.jd, first_date.calendar = first_j_jd, "julian"
		second_date.jd, second_date.calendar = second_g_jd, "gregorian"
	elseif first_g_jd == second_j_jd then
		first_date.jd, first_date.calendar = first_g_jd, "gregorian"
		second_date.jd, second_date.calendar = second_j_jd, "julian"
	else
		local difference = math.min(math.abs(first_j_jd-second_g_jd),math.abs(first_g_jd-second_j_jd))
		status.category = "erroneous_parameters"
		status.error.msg = "wrong_calculation"
		status.error.params = {unwarp(first_date),unwarp(second_date),difference}
	end
	return status, first_date, second_date
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
    		if is_in_list(mw.ustring.lower(str),month_lang[lang[i]]) then
				return reverse_month_lang[lang[i]][mw.ustring.lower(str)]
			end
    	end
    end
end

-- функция для распознавания дат, заданных тремя значениями подряд, с исправлением ошибок
local function decode_triple(d,m,y)
	local year = numerize((y or ""):match("(%d+)"))
	local month = numerize(mw.ustring.match((m or ""),"(%a+)"))
	local day = numerize((d or ""):match("(%d+)"))
	if not month then month = numerize(mw.ustring.match((d or ""),"(%a+)"))	end
	if not day then day = numerize((m or ""):match("(%d+)")) end
	if not year then year = numerize((m or ""):match("(%d+)")) end
	local dateout = {["year"]=year, ["month"]=month, ["day"]=day}
	return dateout
end

local function dmdist(d1,d2)
	local p1,p2 = math.huge,math.huge
	if not not partdist_old(d1,d2) then 
		p1=partdist_old(d1,d2)
	end
	if not not partdist_old(d2,d1) then 
		p1=partdist_old(d2,d1)
	end
--	if (not p1) or (not p2) then
--		return  (p1 or "") .. (p2 or "")
--	else
--		mw.log("d1, d2 = " .. undate(d1) .. ", " .. undate(d2))
		return math.min(tonumber(partdist_old(d1,d2)) or math.huge,tonumber(partdist(d2,d1)) or math.huge)
--	end
end

-- 30) Блок функций для обработки ввода-вывода дат

local function undate(tbl)
	if not tbl then return ""
	else return (tbl.year or "").."-"..(tbl.month or "").."-"..(tbl.day or "")
	end
end

-- функция распознавания даты, переданной одной строкой
local function parse_date(date_string)
	if type(date_string) ~= "string" or date_string == "" then return nil end
	local out_date_str = {nil,nil,nil}
	local error_data = {}
	for i=1, #pattern do
		local result_1, result_2, result_3 = mw.ustring.match(date_string,pattern[i][1])
		if (result_1 or "") > "" then 
			out_date_str[pattern[i].order[1]], 
    		out_date_str[pattern[i].order[2]], 
    		out_date_str[pattern[i].order[3]] = 
    			result_1, result_2, result_3
    		break
		end
	end
	if (not out_date_str[1]) or (not out_date_str[2]) or (not out_date_str[3]) then
		error_data.msg = "no_pattern_match"
		error_data.params = date_string
	end
	local date = {
		["day"]  =numerize(out_date_str[1]), 
		["month"]=numerize(out_date_str[2]), 
		["year"] =numerize(out_date_str[3])}
	return date, error_data
end

----[[ УСТАРЕЛО ]]----
local numstr2date = function(numstr)
	local lang = mw.getContentLanguage()
	local format = "Y-m-d"
	local iso_date = lang:formatDate(format,numstr)
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
--		local lang = mw.getContentLanguage()
--		implement lang:formatDate(format,datein,true) here
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
	local month = purif(month_to_num[string.lower(mw.ustring.match((m or ""),"(%a+)"))])
	local day = purif((d or "-"):match("(%d+)"))
	if not month then 
		msg = category["params"]
		month = purif(month_to_num[string.lower(mw.ustring.match((d or ""),"(%a+)") or "-")]) 
	end
	if (not day) and ((purif(string.match(m or "","(%d+)") or "") or 32) <= (monthd[month] or 31)) then 
		msg = category["params"]
		day = purif(m:match("(%d+)") or "") 
	end
	if not year then 
		msg = category["params"]
		year = purif(string.match(m or "","(%d+)") or "") 
	end
	local dateout = {["year"]=year, ["month"]=month, ["day"]=day, ["msg"]=msg}
	return dateout
end

local function glue(d1,m1,y1,d2,m2,y2)
	if (not d1) and (not m1) and (not y1) and (not d2) and (not m2) and (not y2) then
		return category["params"] end
	local gd,gm,gy,jd,jm,jy = 
		(d1 or ""),
		(m1 or ""),
		(y1 or ""),
		(d2 or ""),
		(m2 or ""),
		(y2 or "")
	--mw.log(table.concat({gd,gm,gy,jd,jm,jy}))
	local gm_sep = {" [["," год|","]]"}
	if (not gy) or (gy == "") then gm_sep = {"","",""} end
	return table.concat({comment[1],trim(trim(jd .. " " .. jm) .. " " .. jy ),
		comment[2]," ([[",trim(gd .. " " .. gm),"]]",gm_sep[1],(gy:match("(%d+)") or ""),
		gm_sep[2],gy,gm_sep[3],")",category["params"]})
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
-- конвертация григорианской даты в jd [[Julian day]]
function gri2jd( datein )
	if not is_date(datein) then 
--		if type(status.error) ~= "table" then
--			status.error = {}
--		end
--		status.error.msg = "no_valid_date"
--		status.error.params = datein
		return --status 
	end
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
--    	status.error.msg = "wrong_jd"
--    	status.error.params = jd
        return --status
    end
	return jd
end

-- конвертация jd в дату по юлианскому календарю
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
    local dateout = {["jd"]=jd, ["year"]=year_out, ["month"]=month_out, ["day"]=day_out,["calendar"]="julian"}
    return dateout
end

-- конвертация даты по юлианскому календарю в jd
function jul2jd( datein )
	if not is_date(datein,true) then 
--		if type(status.error) ~= "table" then
--			status.error = {}
--		end
--		status.error.msg = "no_valid_date"
--		status.error.params = datein
		return --status 
	end
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
--    	status.error.msg = "wrong_jd"
--    	status.error.params = jd
        return --status
    end
	return jd
end

-- конвертация jd в григорианскую дату
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
    local dateout = {["jd"]=jd, ["year"]=year_out, ["month"]=month_out, ["day"]=day_out, ["calendar"]="gregorian"}
    return dateout
end

-- для записи типа -100 год = 100 год до н.э. (с разрывом в нуле)
function astroyear(status, num, bc)
	local year
	if not num or type(num) ~= "number" then 
		status.error.msg = "tech_error"
		status.error.params = "astroyear"
	elseif num < 1 then 
		year = 1 + num 
	end 
	-- todo: запрет нулевого года?
	if not bc then return status, num
	else year = 1 - num
	end
	return status, year
end

-- старая версия, несовместимая с форматом ВикиДаты днэ
-- 4713 до н. э. = −4712 г.
function astroyear_old(num, bc)
	if not num then return error()
	elseif type(num) ~= "number" then return error()
	end
	if num < 1 then return num end
	if not bc then return num
	else return 1 - num
	end
end

-- XXX function need to be deleted XXX
local function recalc_old(datein,calend)
	if inlist(calend,calendars[1]) then 
		return jd2jul(gri2jd(datein)), datein
   	elseif inlist(calend,calendars[2]) then
		return datein, jd2gri(jul2jd(datein))
   	else error("Параметр " .. (calend or "") .. " не опознан, разрешённые: " .. table.concat(calendars[1]," ") .. " и " .. table.concat(calendars[2]," "))
   	end
end

function recalc(status,date,cal)
	if is_in_list(cal,calendars[1]) then 
		date.jd, date.calendar = gri2jd(date), "gregorian"
		status.processed, status.second_date, status.dates = true, true, 2
		return status, date, jd2jul(date.jd) 
	elseif is_in_list(cal,calendars[2]) then
		date.jd, date.calendar = jul2jd(date), "julian"
		status.processed, status.second_date, status.dates = true, true, 2
		return status, date, jd2gri(date.jd)
	else 
		status.error.msg = "unknown_calendar"
		status.error.params = cal
		return status
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
	local hmarg, timedec = 0
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
-- 60) Отладочные функции

-- функции для отображения дат в отладочных сообщениях
local function o(str,arg)
	return (arg and (arg .. ": ") or "") .. (str and (bool2num[str] .. " — ") or "")
end

local function error_output(status)
	if (status.error.msg or "") > "" then 
		if type(status.error.params) == "table" and not status.error.params[1] then
			return errors.start .. string.format(errors[status.error.msg], 
				status.error.params.day or "", status.error.params.month or "", 
				status.error.params.year or "") .. errors.ending
		elseif type(status.error.params) == "table" and status.error.params[1] then
			return errors.start .. string.format(errors[status.error.msg], 
				unwarp(status.error.params[1] or ""), unwarp(status.error.params[2] or ""), 
				unwarp(status.error.params[3] or "")) .. errors.ending
		else
			return errors.start .. string.format(errors[status.error.msg],status.error.params or "") .. errors.ending 
		end
	end
end

-- 80) Основные функции обработки
local function processing(status,input,max_arg)
	local first_date_string, second_date_string, category = "", "", ""
	local first_date, second_date = {}, {}
	if max_arg <= 3 then
		first_date_string = table.concat({input[1] or "", input[2] or "", input[3] or ""}, " ")
		first_date, status.error = parse_date(first_date_string)
		if (status.error.msg or "") > "" then return status end
		if is_date(first_date,true) then
			status.dates, status.processed, status.first_date = 1, true, true
			return status, first_date
		else 
			status.dates = 0
			status.error.msg = "no_valid_date"
			status.error.params = first_date
			return status
		end
	elseif max_arg > 3 and max_arg <= 6 then
		if is_complete(input,1,6) then
			first_date_string = table.concat({input[1], input[2], input[3]}, " ")
			second_date_string = table.concat({input[4], input[5], input[6]}, " ")
			first_date, second_date = parse_date(first_date_string), parse_date(second_date_string)
		else 
			first_date = decode_triple(input[1], input[2], input[3])
			second_date = decode_triple(input[4], input[5], input[6])
		end
		if is_date(first_date,true) then status.first_date = true 
		elseif is_date_part(first_date) then status.first_date = 1 end
		if is_date(second_date,true) then status.second_date = true 
		elseif is_date_part(second_date) then status.second_date = 1 end
		if status.first_date == true and status.second_date == true then 
			status.dates, status.processed = 2, true
		else 
			status.dates = bool2num[status.first_date] + bool2num[status.second_date]
			status.category = "incomplete_parameters" 
		end
		return status, first_date, second_date
	elseif max_arg> 6 then
		status.error.msg = "too_many_arguments"
		status.error.params = max_arg
		return status
	end
end

local function mix_data(status,first_date,second_date)
	status.processed = 1
	for i, k in pairs(time_units) do
		if not first_date[k] and second_date[k] then 
			first_date[k] = second_date[k]
		elseif not second_date[k] and first_date[k] then
			second_date[k] = first_date[k]
		end
	end
	return status, first_date, second_date
end

-- в соответствии с таблицами принимаемых аргументов обрабатывает ввод
function read_args(status, input)
	if not status or type(status) ~= "table" then
		status = {}
		status.error = {}
		status.error.msg = "tech_error"
		status.error.params = "read_args"
	elseif not input or type(input) ~= "table" then
		status.error.msg = "tech_error"
		status.error.params = "read_args"
	else
		for i,v in pairs(unik_args) do
			if unik_args_bool[i] then
				input[v] = is(input[v])
			end
		end
		for i,v in pairs(dual_args) do
			if dual_args_bool[i] then
				local both = is(input[v])
				if both then
					input[v..1], input[v..2] = true, true
				else
					input[v..1], input[v..2] = is(input[v..1]), is(input[v..2])
				end
			else
				if input[v] and input[v]>"" then
					input[v..1], input[v..2] = input[v], input[v]
				end
			end
		end
	end
	if input.ny1 then input.ym1, input.wy1 = nil, false end
	if input.ny2 then input.ym2, input.wy2 = nil, false end
	return status, input
end

-- 90) Задание специфических строк-объектов

-- Раздел "snippet": объекты, которые содержат текст и условия, которые используются при их соединении
-- Определение прототипа объекта
local snippet = {["__index"] = {["text"] = "", ["a"] = 1.5, ["z"] = 1.5}}

-- Метод для создания новых объектов, может принимать как таблицу с условиями, так и строку
function snippet:dress (var)
  if not self or type(self) ~= "table" then return end -- ошибка не обрабатывается
  -- в случае если на входе уже объект нужного класса, возвращаем его же
  if type(var) == "table" and getmetatable(var) == self then
    return var
  end
  -- если на вход не подано параметров, создаём пустую таблицу
  var = var or {}
  -- если на вход подан текст или число, обрабатываем их
  if type(var) ~= "table" and (type(var) == "string" or type(var) == "number") then
    local text = var
    var = {["text"]=text}
  elseif type(var) ~= "table" then return end -- обработчик ошибок без входящего параметра status и без создания замыканий сюда бы
  setmetatable(var,self)
  return var
end

-- Функция сравнения объектов
function snippet.__eq (pre, aft)
    return pre.text == aft.value and pre.a == aft.a and pre.z == aft.z
end

-- Функция сложения объектов, на выходе даёт объект того же типа
local empty = snippet:dress{["text"]= "", a=0, z=0}

function snippet.__add (pre,aft)
  pre=snippet:dress(pre)
  aft=snippet:dress(aft)
  if pre == empty or pre.text == "" then return aft end
  if aft == empty or aft.text == "" then return pre end
  local sill = pre.z + aft.a
  local output = {
      ["text"] = pre.text .. ((sill > 2) and " " or "") .. aft.text, 
      ["a"] = pre.a, 
      ["z"] = aft.z
    }
  return snippet:dress(output)
end
--[[в зависимости от значений "a" и "z" между объектами ставится или не ставится пробел:
	 	0	1	2	3
	0	-	-	-	+
	1	-	-	+	+
	2	-	+	+	+
	3	+	+	+	+
]]--
-- Функция для отображения объекта в виде текста
function snippet.__tostring (table)
  if type(table) == "table" then
    return table.text
  end
end

-- 95) Блок функций ввода-вывода
-- Перед функциями расположен код, который позволяет проверять
-- работу модуля непосредственно в 
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

function p.ToIso( frame ) -- возможно неиспользуемая
    local args = getArgs(frame, { frameOnly = true })
    local datein = args[1]
    -- парсинг входящей даты по шаблону
    local pattern = "(%d+)%.(%d+)%.(%d+)"
    local dayin, monthin, yearin = datein:match(pattern)
    local year = tonumber(yearin)
    local month = tonumber(monthin)
    local day = tonumber(dayin)
    -- проверка параметров
    if not (type(year) == 'number') then 
        return error("Wrong year")
    end
    if not (1 <= month and month <= 12) then 
        return error("Wrong month")
    end
    if not (1 <= day and day <= 31) then 
        return error("Wrong day")
    end
    local timedate = os.time{year=year, month=month, day=day}
    local date = os.date("%Y-%m-%d", timedate)
    return date
end

function p.ToDate( frame ) -- возможно неиспользуемая
    local args = getArgs(frame, { frameOnly = true })
    local lang = mw.getContentLanguage()
    local datein = args[1]
    local format = "j xg Y"
    if not string.match(datein, "%p") then return datein
    elseif not args[2] then
    else format = args[2]
    end
    return lang:formatDate(format,datein,true)
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
    jdate, gdate = recalc_old(datein,cal)
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

	jdate, gdate = recalc_old(datein,cal)

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

-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={}})
-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={"3","июня",nil,"21","мая"}})
-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={"28 августа","","1916 года","15"}})
-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={"3","июня","1900","21","мая"}})
-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={"6","июня","1889 год","25","мая"}}) 
-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={"28","ноября","1917","15"}})
-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={"28 августа","nil","1916 года","15"}}) 
-- =p.NewerDate(mw.getCurrentFrame():newChild{title="smth",args={"4","января","1915","22","декабря","1914 года"}}) 
-- {{OldStyleDate|день (НС)|месяц (НС)|год (НС)|день (СС)|месяц (СС)|год (СС)}}

function p.NewerDate( frame )
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
			j1date, g1date = recalc_old(ingdate,"g")
			ingdate["full"] = true
		end
		if isdate(injdate) then
			j2date, g2date = recalc_old(injdate,"j")
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
		mw.log("📏 " .. (tostring(partdist_old(ingdate,injdate)) or "").. " — " .. (tostring(partdist_old(injdate,ingdate)) or ""))
		return glue(args[1],args[2],args[3],args[4],args[5],args[6]) 
		-- частичный или полный вывод, категория
	else 
		mw.log("ingdate ".. (undate(ingdate) or ""))
		mw.log("injdate ".. (undate(injdate) or ""))
		mw.log("j1date " .. (undate(j1date ) or ""))
		mw.log("j2date " .. (undate(j2date ) or ""))
		mw.log("g1date " .. (undate(g1date ) or ""))
		mw.log("g2date " .. (undate(g2date ) or ""))
		return err .. category["params"]
	end
end

--[[
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"15","августа"," ","2"," "," ",["cal"]="g",["wdm2"]=1,["wy2"]=1}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"15","августа",nil,"2",["cal"]="g",["wdm2"]=1,["wy2"]=1}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"32.1.2020",["cal"]="j"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"23.12.1855",["cal"]="j",["wy2"]=1,["wdm2"]=1}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"+2017-10-09T00:00:00Z",["cal"]="g",["wy"]=1,["wdm"]=1,["ny2"]=1,["sq_brts"]=1,["ym1"]="г."}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"+2017-10-09T00:00:00Z",["cal"]="g",["sq_brts"]=true}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"+2017-10-09T00:00:00Z",["cal"]="g",["bc"]=1,["wy"]=1,["br_in"]=1,["wdm2"]=1,["ny1"]=1,}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"+2017-10-09T00:00:00Z",["cal"]="j"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"30","апреля",nil,"17"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"30","апреля","2020","17"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"31","апреля","2020"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"23 juin 2020"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"23 октября 2020"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"23.10.2020",cal="г"}})
=p.Test(mw.getCurrentFrame():newChild{title="smth",args={"2020-10-23",cal="ю"}})
]]--
function p.Test( frame )
	-- инициализация, заполнение обратных таблиц, копирование параметров
	filling_months(lang, month_lang)
	local args = getArgs(frame, { removeBlanks = false, frameOnly = true })
	local input, max_arg = copy_it(args)

--	mw.log("(" .. #input .. ", " .. max_arg .. ")", unpack(input))
	-- перевод строковых параметров в числовые
	input.cal = input.cal or "j"
	local status, first_date, second_date = {processed=false,first_date=false,second_date=false,category="",error={msg="",params=""}}
	status, first_date, second_date =	processing(status,input,max_arg)
	-- перевод параметров оформления в булевые
	status, input = read_args(status, input)
	
	-- применение параметра до нашей эры или сдвиг отрицательных дат, чтобы не было разрыва в нулевом году
	if first_date then status, first_date.year = astroyear(status, first_date.year, input.bc) end
	if second_date then status, second_date.year = astroyear(status, second_date.year, input.bc) end
	
	-- проверка и дополнение дат
	if (status.dates or 0) > 1 and status.processed ~= true then
		status, first_date, second_date = mix_data(status,first_date,second_date)
		status, first_date, second_date = guess_jd(status,first_date,second_date)
	elseif status.dates == 1 then
		status, first_date, second_date = recalc(status,first_date,input.cal)
	elseif max_arg < 3 then
		if status.error.msg then
		else
			status.error.msg = "too_little_arguments"
			status.error.params = max_arg
		end
	else
		status.error.msg = "unknown_error"
		status.error.params = ""
	end
	
	--[[ ошибка если даты сформированы не полностью
	if first_date and not first_date.year and second_date and not second_date.year then 
		error("Даты " .. unwarp(first_date)  .. " и " .. unwarp(second_date)  .. " не содержат год. " .. 
			(error_output(status) or "") .. " — " .. 
			(o(status.processed,"processed") or "") ..
			(o(status.first_date,"first_date") or "") ..
			(o(status.second_date,"second_date") or "") ..
			(o(status.category,"category") or ""))
	end
	--]]
	-- ошибка в случае если даты не сформированы
	if not first_date or not second_date then return error_output(status) end
	if     first_date.calendar  == "julian" and second_date.calendar == "gregorian" then
	elseif second_date.calendar == "julian" and first_date.calendar  == "gregorian" then
		local swap_date = first_date
		first_date = second_date
		second_date = swap_date
	else
		status.error.msg = "unknown_error"
		status.error.params = ""
	end
	
	input.wy1 = first_date.year and input.wy1 or nil
	input.wy2 = second_date.year and input.wy2 or nil
	
--	mw.logObject(input)
--	mw.logObject(status)
--	mw.logObject(first_date)
--	mw.logObject(second_date)

	-- ниже задаются условия поведения кусков текста - в зависимости от каких параметров они принимают какие значения
	-- если нужно более сложное поведение чем "bool and true_result or false_result", то их можно заменить на анонимные функции
	input.lang = input.lang or "ru"
	local space = snippet:dress{["text"]= " ", a=0, z=0}
	local left = snippet:dress{["text"] = args.sq_brts and "&#091;" or "(", ["a"] = 3, ["z"] = 0}
	local right = snippet:dress{["text"] = args.sq_brts and "&#093;" or ")", ["a"] = 0, ["z"] = 3}
	local bc_mark1 = (first_date.year and first_date.year < 1) and snippet:dress{["text"]= "до н. э." } or empty
	local bc_mark2 = (second_date.year and second_date.year < 1) and snippet:dress{["text"]=  "до н. э." } or empty
	first_date.year = (first_date.year and first_date.year < 1) and -first_date.year or first_date.year
	second_date.year = (second_date.year and second_date.year < 1) and -second_date.year or second_date.year
	local jdd, jdm, jdy  = 
		snippet:dress{["text"]=first_date.day}, 
		snippet:dress{["text"]=month_lang[input.lang][first_date.month]}, 
		snippet:dress{["text"]=(input.ny1 or not first_date.year) and "" or first_date.year .. ((input.ym1 and " " or "") .. (input.ym1 or "")),
			a = input.ny1 and 0 or nil, z= input.ny1 and 0 or nil}
	local gdd, gdm, gdy = 
		snippet:dress{["text"]=second_date.day}, 
		snippet:dress{["text"]=month_lang[input.lang][second_date.month]}, 
		snippet:dress{["text"]=(input.ny2 or not second_date.year) and "" or second_date.year .. ((input.ym2 and " " or "") .. (input.ym2 or "")),
			a = input.ny2 and 0 or nil, z= input.ny2 and 0 or nil}
		
	local wdm1_, wdm2_, wy1_, wy2_ =
		snippet:dress{["text"]= input.wdm1 and table.concat{
			"[[", jdd.text," ",jdm.text ,"|"} or "", a=input.wdm1 and 2 or 0, z=0},
		snippet:dress{["text"]= input.wdm2 and table.concat{
			"[[", gdd.text," ",gdm.text ,"|"} or "", a=input.wdm2 and 2 or 0, z=0},
		snippet:dress{["text"]= (input.wy1 and first_date.year) and ("[[" .. first_date.year .. " год" .. 
			(bc_mark1.text > "" and (" " .. bc_mark1.text) or "") .. "|") or "", a=input.wy1 and 2 or 0, z=0},
		snippet:dress{["text"]= (input.wy2 and second_date.year) and ("[[" .. second_date.year .. " год" .. 
			(bc_mark2.text > "" and (" " .. bc_mark2.text) or "") .. "|") or "", a=input.wy2 and 2 or 0, z=0}
	local wdm_1, wdm_2, wy_1, wy_2 =
		snippet:dress{["text"]= input.wdm1 and "]]" or "", a=0, z=input.wdm1 and 2 or 0},
		snippet:dress{["text"]= input.wdm2 and "]]" or "", a=0, z=input.wdm2 and 2 or 0},		
		snippet:dress{["text"]= input.wy1 and "]]" or "", a=0, z=input.wy1 and 2 or 0},
		snippet:dress{["text"]= input.wy2 and "]]" or "", a=0, z=input.wy2 and 2 or 0}	
	local cdm, cdy = empty, empty
	
	input.order = input.order or "zip"
	
	if input.order == "zip" then
		if first_date.month == second_date.month then
			cdm = mw.clone(jdm)
			jdm, gdm = empty, empty
		end
		if first_date.year == second_date.year then
			cdy = mw.clone(jdy)
			jdy, gdy = empty, empty
			cdy = wy2_ + cdy + bc_mark2 + wy_2
			wy1_, wy_1 = empty, empty
			wy2_, wy_2 = empty, empty
			bc_mark1, bc_mark2 = empty, empty
		end
	end

	local j_day_month = wdm1_ + jdd + jdm + wdm_1
	local j_year = wy1_ + jdy + bc_mark1 + wy_1
	local g_day_month = wdm2_ + gdd + gdm + wdm_2
	local g_year = wy2_ + gdy + bc_mark2 + wy_2

	if input.order == "full" then
		return mw.text.trim(tostring(j_day_month + j_year + left + g_day_month + g_year + right))
	elseif input.order == "zip" then
		return mw.text.trim(tostring(j_day_month + j_year + left + g_day_month + g_year + right  + cdm + cdy))
	else
		return
	end
	
	if status.error then 
		return error_output(status) 
	end

--	todo - part date dist check, year mark from double triplets, julian span comment, br_in?, check if format table is full, add short formats d.m.y - 1/01
end 

return p
