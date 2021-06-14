local p = {}
local bool_to_number={ [true]=1, [false]=0 }
local getArgs = require('Module:Arguments').getArgs
local err = "-"

-- utility functions
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

local function inbord(val, down, up) -- is val in border from down to up?
	return not (type(up) ~= "number" or type(down) ~= "number" or type(val) ~= "number" or up < down or val < down or val > up)
end

local inlist = function ( var, list )
    local n = #list
	local inlist = false
	for i=1,n do
		if var == list[i] then inlist = true end
	end
    return inlist
end

-- calendar functions
local function unwarp(date) 
	if not date then 
		return ""
	elseif type(date) ~= "table" then 
		return date
	end
	return (date.year or "?").."-"..(date.month or "?").."-"..(date.day or "?")
end

local mnlang = {"en", "de", "fr"} --"ru_G", "ru_N", 

--	["ru_G"] = {"января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"},
--	["ru_N"] = {"январь","февраль","март","апрель","май","июнь","июль","август","сентябрь","октябрь","ноябрь","декабрь"},
local month_lang = { 
	["en"] = {"january", "february", "march", "april", "may", "june","july", "august", "september", "october", "november", "december"},
	["de"] = {"januar", "februar", "märz", "april", "mai", "juni","juli", "august", "september", "oktober", "november", "dezember"},
	["fr"] = {"janvier", "février", "mars", "avril", "mai", "juin","juillet", "août", "septembre", "octobre", "novembre", "décembre"}
	}
local monthd = {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31} -- old table of days in mounth

--	{"(%d%d)[-%.%s/\\](%d%d%d%d?)", ["order"] = {2,3} }, 	-- mm yyyy
--	{"(%d%d%d%d?)[-%.%s/\\](%d%d)", ["order"] = {3,2} }, 	-- yyyy mm
local pattern = { 
	{"(-?%d%d%d%d?)[-%.%s/\\](%d%d)[-%.%s/\\](%d%d)",  	["order"] = {3,2,1} },  -- yyyy mm dd
	{"(%d+)[-%.%s/\\](%d+)[-%.%s/\\](%d%d%d%d?)",	["order"] = {1,2,3} }, 		-- dd mm yyyy
	{"(%d+)%s(%l+)%s(%d%d%d%d?)", 	["order"] = {1,2,3} }, 	-- d mmm y
	{"(%l+)%s(%d+),?%s(%d%d%d%d?)", ["order"] = {2,1,3} }, 	-- mmm d, y
	{"(%l+)%s(%d%d%d%d?)", 	["order"] = {2,3} }, 			-- mmm y
	{"(%d%d%d%d?)%s(%l+)", 	["order"] = {3,2} }, 			-- y mmm
}

-- Will be filled automatically from above table
local reverse_month_lang = {} 

local reverse_table = function (strait_table)
	local reversed_table = {}
	for k,v in pairs(strait_table) do
		reversed_table[v] = k
	end
	return reversed_table
end

local filling_months = function (mnlang, month_lang)
	for i=1, #mnlang do
		reverse_month_lang[mnlang[i]] = reverse_table(month_lang[mnlang[i]])
	end
end

filling_months(mnlang, month_lang)

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

-- функция для нормализации значений дат и перевода месяцев в числа
local function numerize(str)
    if type(str) == "number" then
        return math.floor(str)
	elseif str == "" or str == nil or type(str) ~= "string" then
		return nil
    elseif type(tonumber(str)) == "number" then
        return math.floor(tonumber(str))
    else
    	for i=1, #mnlang do
    		if inlist(mw.ustring.lower(str),month_lang[mnlang[i]]) then
				return reverse_month_lang[mnlang[i]][mw.ustring.lower(str)]
			end
    	end
    end
end

local function parse_date(status, date_string)
	status = status or {}
	if type(date_string) ~= "string" or date_string == "" then return nil end
	local out_date_str = {"","",""}
	for i=1, #pattern do
		local result_1, result_2, result_3 = mw.ustring.match(mw.ustring.lower(date_string),pattern[i][1])
		if (result_1 or "") > "" then
			status.pattern = i
			out_date_str[pattern[i].order[1]] = result_1
    		out_date_str[pattern[i].order[2]] = result_2
    		if (pattern[i].order[3]) then out_date_str[pattern[i].order[3]] = result_3 end
    		break
		end
	end
	local date = {
		["day"]  =numerize(out_date_str[1]),
		["month"]=numerize(out_date_str[2]),
		["year"] =numerize(out_date_str[3])}
	return status, date
end

-- OLD FUNCTION
local function numstr2date(datein)
	local nums = {}
    local dateout = {}
    for num in string.gmatch(datein,"(%d+)") do
        table.insert(nums,purif(num))
    end
    if #nums ~= 3 then error("Wrong format: 3 numbers expected")
    elseif not inbord(nums[2],1,12) then error("Wrong month")
    elseif not inbord(nums[3],1,31) then
        dateout = {["year"]=nums[3], ["month"]=nums[2], ["day"]=nums[1]}
    elseif not inbord(nums[1],1,31) then
        dateout = {["year"]=nums[1], ["month"]=nums[2], ["day"]=nums[3]}
    else
--		local lang = mw.getContentLanguage()
--		implement lang:formatDate(format,datein,true) here
        return error("Unable to recognize date")
    end
    return dateout
end

local function date2str(datein)
	if not isdate(datein) then return error("Wrong date") end
	local dateout = os.date("%Y-%m-%d", os.time(datein))
    return dateout
end

local function gri2jd( datein )
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

local function jd2jul( jd )
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

local function jul2jd( datein )
	if not isdate(datein) then return error("Wrong date") end
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

local function jd2gri( jd )
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

-- =p.NthDay(mw.getCurrentFrame():newChild{title="1",args={"1","1","1","2020","%Y-%m-%d"}}) 

function p.NthDay( frame )
    local args = getArgs(frame, { frameOnly = true })
    local num, wday, mont, yea, format = 
    	purif(args[1]), purif(args[2]), purif(args[3]), purif(args[4]), args[5]
    if not format then format = "%Y-%m-%d" end
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

local function exam(smth,name)
	name = name and mw.log(name) or ""
	if type(smth) == 'table' then
		mw.logObject(smth)
		return smth
	else
		mw.log(smth)
		return smth
	end
end
-- =p.test(mw.getCurrentFrame():newChild{title="1",args={"1.1.2020"}}) 
-- =p.test(mw.getCurrentFrame():newChild{title="1",args={"2020-01-01"}}) 
function p.test(frame)
	local args = getArgs(frame, { frameOnly = true })
	local ns_sh_date, ns_year, os_sh_date = args[1],args[2],args[3]
	local ns_date_string = (ns_sh_date or "") .. (ns_year and (" " .. ns_year) or "")
	local status, ns_date = parse_date(nil,ns_date_string)
	return unwarp(ns_date) .. " = " .. unwarp(jd2jul(gri2jd(ns_date)))
end

return p