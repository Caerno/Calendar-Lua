-- Юнит-тесты [[Module:Calendar]]

local Calendar = require('Module:Calendar')
local p = require('Module:UnitTests')

function p:test_CalDate()
	self:preprocess_equals_many('{{#invoke:Calendar|CalDate|', '}}', {
		{'2026-07-27|григорианский', '27 июля 2026'},
		{'2026-07-27|юлианский', '14.07.2026'},
		{'2026-07-27|исламский', '11 Сафар 1448'},
		{'2026-07-27|иранский', '5 Мордад 1405'},
		{'2026-07-27|еврейский', '13 Ав 5786'},
		{'2026-07-27|тайский', '27 июля 2569'},
		{'2026-07-27|миньго', '27 июля 115'},
		{'2026-07-27|нэнго', '27 июля (令和8)'},
		{'2026-07-27|коптский', '20.11.1742'},
		{'2000-01-01|григорианский', '1 января 2000'},
		{'2000-01-01|юлианский', '19.12.1999'},
		{'2000-01-01|исламский', '24 Рамадан 1420'},
		{'2000-01-01|иранский', '11 Дей 1378'},
		{'2000-01-01|еврейский', '23 Тевет 5760'},
		{'2000-01-01|тайский', '1 января 2543'},
		{'2000-01-01|миньго', '1 января 89'},
		{'2000-01-01|нэнго', '1 января (平成12)'},
		{'2000-01-01|коптский', '22.04.1716'},
		{'2000-02-29|юлианский', '16.02.2000'},
		{'2100-03-14|юлианский', '29.02.2100'},
		{'1582-10-15|юлианский', '5.10.1582'},
		{'2024-02-29|еврейский', '20 Адар I 5784'},
		{'-0044-03-15|юлианский', '17.03.-44'},
	})
end

function p:test_NthDay()
	self:preprocess_equals_many('{{#invoke:Calendar|NthDay|', '}}', {
		{'1|0|10|2020|%Y-%m-%d', '2020-10-04'},
		{'2|3|5|2019|%Y-%m-%d', '2019-05-08'},
		{'-1|5|2|2024|%Y-%m-%d', '2024-02-23'},
		{'-2|6|12|2001|%Y-%m-%d', '2001-12-22'},
		{'5|0|2|2026|%Y-%m-%d', '―'},
		{'5|0|3|2026|%Y-%m-%d', '2026-03-29'},
	})
end

function p:test_ToIso()
	self:preprocess_equals_many('{{#invoke:Calendar|ToIso|', '}}', {
		{'1.2.1602', '1602-02-01'},
		{'2021.12.12', '2021-12-12'},
		{'12 декабря 2020', '2020-12-12'},
		{'5 января 1002', '1002-01-05'},
		{'29.02.2000', '2000-02-29'},
		{'29.02.1900', 'Wrong day: 1900-2-29'},
		{'31.04.2020', 'Wrong day: 2020-4-31'},
	})
end

function p:test_BoxDate()
	self:preprocess_equals_many('{{#invoke:Calendar|BoxDate|', '}}', {
		{'06.1280|F Y года', 'июнь 1280 года'},
		{'1820-07', 'июль 1820'},
		{'08.08.1828', '8 августа 1828'},
		{'2020-12|xg Y', 'декабря 2020'},
		{'13 января 2020', '13 января 2020'},
		{'février 1281', 'февраль 1281'},
	})
end

function p:test_unitime()
	self:preprocess_equals_many('{{#invoke:Calendar|unitime|', '}}', {
		{'MSK', '[[UTC+3:00]]'},
		{'МСК', '[[UTC+3:00]]'},
		{'мск', '[[UTC+3:00]]'},
		{'UTC +3', '[[UTC+3:00]]'},
		{' +2 ', '[[UTC+2:00]]'},
		{'EST', '[[UTC&minus;5:00]]'},
		{'+12:45|1', '[[UTC+12:45]], [[летнее время|летом]] [[UTC+13:45]]'},
		{'-3:30|да', '[[UTC&minus;3:30]], [[летнее время|летом]] [[UTC&minus;2:30]]'},
	})
end

-- деградация с категориями проверяется прямыми вызовами, чтобы категории
-- не цеплялись к странице тестов
function p:test_degradation()
	local frame = mw.getCurrentFrame()
	local out = Calendar.unitime(frame:newChild{title = 't', args = {'МСК+4'}})
	self:equals('unitime("МСК+4"): возврат как есть + категория',
		out:find('^МСК%+4%[%[Категория:Википедия:Статьи с ошибочной работой') ~= nil, true)
	out = Calendar.BoxDate(frame:newChild{title = 't', args = {'13 января'}})
	self:equals('BoxDate("13 января"): span-ошибка + категория',
		out:find('^<span class=error>') ~= nil and out:find('%[%[Категория:') ~= nil, true)
	out = Calendar.NthDay(frame:newChild{title = 't', args = {'9', '0', '10', '2020'}})
	self:equals('NthDay(9): span-ошибка + категория',
		out:find('^<span class=error>') ~= nil and out:find('%[%[Категория:') ~= nil, true)
end

function p:test_bxDate()
	self:equals('bxDate("06.1280", "F Y года")', (Calendar.bxDate('06.1280', 'F Y года')), 'июнь 1280 года')
	self:equals('bxDate(nil): текст ошибки', select(3, Calendar.bxDate(nil)).errorText, 'нет входящих данных')
	self:equals('bxDate("13 января"): текст ошибки', select(3, Calendar.bxDate('13 января')).errorText,
		'строка «13 января» не является верной датой, пожалуйста, укажите дату в формате ГГГГ-ММ-ДД')
end

-- {{#invoke:Calendar/testcases|run}} и |run_tests
local unittester_run = p.run
function p.run(a, b)
	return unittester_run(p, b or a)
end

return p
