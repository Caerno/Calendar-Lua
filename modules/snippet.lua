--[[ easy text joining
TODO: 
	remake from step-by-step conversion to text in conversion to text only at the end of operations
	object types, conditions and order
	pattern string formatting (easier for users)
--]]

local snippet = {["__index"] = {["text"] = "", ["a"] = 1.5, ["z"] = 1.5}}
--[["a" + "z" = is there space or not
	 	0	1	2	3
	0	-	-	-	+
	1	-	-	+	+
	2	-	+	+	+
	3	+	+	+	+
]]--

function snippet:dress (var)
  if not self or type(self) ~= "table" then return end -- todo: обработка ошибки
  -- в случае если на входе уже объект нужного класса, возвращаем его же
  if type(var) == "table" and getmetatable(var) == self then
    return var
  end
  var = var or {}
  if type(var) ~= "table" and (type(var) == "string" or type(var) == "number") then
    local text = var
    var = {["text"]=text}
  elseif type(var) ~= "table" then return end -- обработчик ошибок без входящего параметра status и без создания замыканий сюда бы
  setmetatable(var,self)
  return var
end

function snippet.__eq (pre, aft)
    return pre.text == aft.value and pre.a == aft.a and pre.z == aft.z
end

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

function snippet.__tostring (table)
  if type(table) == "table" then
    return table.text
  end
end

return snippet
