local p = {}
local getArgs = require('Module:Arguments').getArgs
local yesno = require('Module:Yesno')
local snippet = require('Module:Песочница/Carn/Text')
local function is(str)
	if (not str) or (str == "") then return false
	else return yesno(str,false) end
end

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
local calendars = {{"г", "g"}, {"ю", "j"}}
local unik_args = {	"order","lang", "cal", "bc", "sq_brts" }
local unik_args_bool = {false,false,false,true,true,true}
-- before christ, calendar, brackets inside, square brackets
local dual_args = { "wdm", "wy", "ny", "ym"}
local dual_args_bool = {true,true,true,false}
-- wikify day and month, wikify year, no year, year mark

local status = {category="",error={msg="",params=""}}
local bool2num={[1]=1, [0]=0, ["1"]=1, ["0"]=0, [true]=1, [false]=0, 
	["__index"]=function(self,v) 
		return tostring(v)
	end }
setmetatable(bool2num,bool2num)

-- local options = {"cal","bc","wiki_date","wiki_year","sq_brts","no_year","brackets_inside"}

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

-- функция для проверки, содержит ли массив запрашиваемое значение
local is_in_list = function ( var, list )
	for i=1, #list do
		if var == list[i] then
			return true
		end
	end
    return false
end

--XXX--
--[==[ Календарные функции ]==]
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

-- функция, проверяющая, корректная ли дата содержится в таблице
local function is_date ( date, is_julian )
	if not date or type(date) ~= "table" then return false
	elseif	not number_in_range(date.month,1,12) or
			not number_in_range(date.day,1,month_end_day(date.month,date.year,is_julian)) or
			not number_in_range(date.year,-9999,9999) then
				return false
	elseif date.year ~= 0 then return true
	end
end		

-- функция для проверки, содержит ли таблица частичные сведения о дате
local function is_date_part ( date )
	if not date then return false
	elseif not (type(date) == "table") then return false
	elseif (number_in_range(date.year,-9999,9999)
	or number_in_range(date.month,1,12)
	or number_in_range(date.day,1,31)) then return true
	else return false
	end
end

-- для дат, порядок которых неизвестен, пробует сначала прямой (dmy), затем обратный (ymd) порядок
local function guess_date( triplet, is_julian ) -- только для дат после 31 года, пока не используется
	local date = {["day"]=triplet[1],["month"]=triplet[2],["year"]=triplet[3]}
	if is_date(date,is_julian) then return date end
	local date = {["day"]=triplet[3],["month"]=triplet[2],["year"]=triplet[1]}
	if is_date(date,is_julian) then return date end
end

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

-- функции для отображения дат в отладочных сообщениях
local function o(str,arg)
	return (arg and (arg .. ": ") or "") .. (str and (bool2num[str] .. " — ") or "")
end

local function unwarp(tbl)
	if not tbl then return ""
	elseif type(tbl) ~= "table" then return tbl
	elseif (tbl.day or tbl.month or tbl.year) then 
		return (tbl.year or "¤").."•"..(tbl.month or "¤").."•"..(tbl.day or "¤")
	else return (tbl[3] or "¤").."-"..(tbl[2] or "¤").."-"..(tbl[1] or "¤")
	end
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
	local empty = snippet:dress{["text"]= "", a=0, z=0}
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