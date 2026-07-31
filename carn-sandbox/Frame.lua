local p={}
local getArgs = require('Module:Arguments').getArgs

-- =p.TitleExist(mw.getCurrentFrame():newChild{title="Поваренная соль",args={"Альфа Центавра"}})
function p.ContentExist( frame )
	local args = getArgs(frame, { frameOnly = true })
	local name = args[1]
--	if not mw.title.new(name)
	local page = mw.title.new(name)
	if not page:getContent() 
	then return name
	else return "[[" .. name .. "]]"
	end
	return false
end

function p.TitleExist( frame )
	local args = getArgs(frame, { frameOnly = true })
	local name = args[1]
--	if not mw.title.new(name) -- это просто проверка, допустимо ли такое название для статьи
	local page = mw.title.new(name)
	if not page.exists
	then return name
	else return "[[" .. name .. "]]"
	end
	return false
end

-- =p.g_log()
function p.g_log()
--	for i, v in pairs() do
--		mw.log(i .. ":")
		mw.logObject(_G)
--	end
end

--  =p.template_subst(mw.getCurrentFrame():newChild{title="Калининград",args={['t_name']="Шаблон:НП",['русское название']="Калининград"}})
function p.template_subst(frame)
	local cargs = frame.args
	local pargs = frame:getParent().args
	local args = cargs["t_name"] and cargs or (pargs["t_name"] and pargs or {})
	local t_name = args['t_name'] 
	if not t_name then return end
	args['t_name'] = nil
	return frame:expandTemplate{ title = t_name, args = args }
end

--[=[ 

[07.10.2046 14:58:45 | Изменены 14:57:03] Фильтр правок: Эта мысль мне тоже приходила в голову, но озвучивать её я не стал.
[07.10.2046 16:05:07] Рейму Хакурей: [7 октября 2046 г. 16:03] Автоматическая подпись: 

<<< Приветствую! У меня есть информация конфиденциального характера, которую я могу разгласить только с предварительной гарантией, что со мной это связано никогда не будет
Вот что мне пришло, информацию нужно запросить, конечно.
[07.10.2046 19:54:44] D-mashine: а потом нам что, стирать письмо из рассылки? надо обдумать этот момент
[07.10.2046 19:55:02 | Изменены 19:53:21] D-mashine: я бы вообще не доверял этой участнице, что мы о ней знаем
[07.10.2046 20:45:23] Рейму Хакурей: [7 октября 2046 г. 19:55] D-mashine: 

<<< я бы вообще не доверял этой участнице, что мы о ней знаем
да
[07.10.2046 20:55:15] Ockhamite: Предложение: провести опрос, доверяет ли сообщество участнице
[07.10.2046 20:56:32] Рейму Хакурей: +
[07.10.2046 21:03:47] Фильтр правок: Почитал то что нам написали заявители. Может быть отложим эту заявку на полгодика?

--]=]
function p.skypelog(frame)
	local args = getArgs(frame)
	local raw = {}
	for a, txt in pairs(args) do
		if type(tonumber(a)) == "number" then
			table.insert(raw,txt)
			table.insert(raw,"|")
		else
			table.insert(raw,a)
			table.insert(raw,"=")
			table.insert(raw,txt)
			table.insert(raw,"|")
		end
	end
	local raw_text = table.concat(raw)
	local result = {}
	-- ^\[(\d\d\.\d\d\.\d{4}\s\d{1,2}:\d\d:\d\d)\]\s([^\:\*]*):([\s\S]*?)(?:(?=\[[^\]]*\]))
	-- ^\[(\d\d\.\d\d\.\d{4}\s\d{1,2}:\d\d:\d\d(?:\s\|\sИзменены\s\d{1,2}:\d\d:\d\d)?)\]\s([^\:\*]*):([\s\S]*?)(?:(?=\[(\d\d\.\d\d\.\d{4}\s\d{1,2}:\d\d:\d\d(?:\s\|\sИзменены\s\d{1,2}:\d\d:\d\d)?)\]))
	-- %sИзменены%s%d?%d:%d%d%:%d%d%]%s([^:]+):(.*)
	for line in raw_text:gmatch("[^\n]+") do
   		if string.find( line, "%[" ) then
   			mw.log(string.find( line, "Изменены" ))
   			if string.find( line, "Изменены" ) then
   				local date, change, nick, text = line:match("%[(%d?%d%.%d%d%.%d%d%d%d%s%d?%d:%d%d%:%d%d)%s")
    			table.insert(result,(date or "") .. "-" .. (change or "") .. "-" .. (nick or "") .. "-" .. (text or ""))
	    	else
	    		local date, nick, text = line:match("%[(%d?%d%.%d%d%.%d%d%d%d%s%d?%d:%d%d%:%d%d)%]%s([^:]+):(.*)")
    			table.insert(result,(date or "") .. "-" .. (change or "") .. "-" .. (nick or "") .. "-" .. (text or ""))
	    	end
    	else
    		table.insert(result,"<>" .. line)
    	--	local candidate_text = string.match( line, patt_candid)
    	--	local pos0, pos1 = string.find(candidate_text,patt_candid_end)
    	--	local candidate = string.sub(candidate_text, position, pos0 - 1)
    	--	if candidate ~= "" and candidatrue[candidate] ~= true then 
    	--		candidatrue[candidate] = true
    	--		table.insert(candidates, candidate)
    	--	end
    	end
	end
	return table.concat(result,"\n\r\n")
end

-- =p.is_in_cat(mw.getCurrentFrame():newChild{title="Арбитраж:Участник Bilderling",args={"Арбитраж:Участник Bilderling", "Арбитраж:Незакрытые заявки"}})
-- =p.is_in_cat(mw.getCurrentFrame():newChild{title="Арбитраж:Разблокировка участника Бабкинъ Михаилъ",args={"Арбитраж:Разблокировка участника Бабкинъ Михаилъ", "Арбитраж:Заявки, по которым принято решение"}})
-- =p.is_in_cat(mw.getCurrentFrame():newChild{title="Арбитраж:Разблокировка участника Бабкинъ Михаилъ",args={"Арбитраж:Разблокировка участника Бабкинъ Михаилъ", "Арбитраж:Незакрытые заявки"}})
function p.is_in_cat( frame )
	local args = getArgs(frame, { frameOnly = true })
	local name = args[1]
	local cat = args[2]
--	if not mw.title.new(name)
	local page = mw.title.new(name)
	local text = page:getContent() 
	if not text
	then return nil
	else return string.find(text, cat)
	end
	return false
end

return p
-- Обсуждение модуля:Песочница/Carn/Frame
