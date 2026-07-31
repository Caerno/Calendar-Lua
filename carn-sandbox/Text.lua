--[[ Данный модуль реализует текстовые функции для соединения строк под условиями
TODO: 
	введение параметра предпочтительного порядка
	введение типов объектов и условий
	в данный момент сложение двух простых текст-объектов даёт простой текст-объект
		необходимо переделать функцию сложения текст-объектов таким образом, 
		чтобы она приводила к созданию сложного текст-объекта, 
		который хранит условия поглощённых текст-объектов
		и преобразовывается в текст по методу __tostring
--]]
-- Создание таблицы, к которой будут привязываться функции и определение прототипа объекта со значениями по умолчанию
local snippet = {["__index"] = {["text"] = "", ["a"] = 1.5, ["z"] = 1.5}}
--[[в зависимости от значений "a" и "z" между объектами ставится или не ставится пробел:
	 	0	1	2	3
	0	-	-	-	+
	1	-	-	+	+
	2	-	+	+	+
	3	+	+	+	+
]]--

-- Метод для создания новых объектов, может принимать как таблицу с условиями, так и строку
-- Первый параметр - сама "self"
function snippet:dress (var)
  if not self or type(self) ~= "table" then return end -- todo: обработка ошибки
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

-- Функция для отображения объекта в виде текста
function snippet.__tostring (table)
  if type(table) == "table" then
    return table.text
  end
end

return snippet
