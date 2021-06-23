package.path = package.path .. ";?;?.lua;.\\lualib\\?.lua;./lualib/?.lua;.\\modules\\?.lua;./modules/?.lua"
local mw = require("mw")
local datesWD = require("datesWD")
-- yesno = require('yesno')
-- calendar = require("calendar")
--[==[ getArgs = function  (input)
    -- null operation - parameters are discarded
    return input
end
--]==]
-- local init_test = require("init_test")
-- init_test.run()

local cases = {
    {"6 January 1705"}, 
    {"January 6, 1705"},
    {"23.10.2020"}, 
    -- 14: 10 (23) октября 2020 г
    {"2020-10-23"}, 
    -- 15: 23 октября (5 ноября) 2020 ю
    {"1705-01-06"},
--    {"2 February","1905","20 January"},
--    {"February 2","1905","January 20"}
}

--[[ local runWD = function()
    for i, v in pairs(cases) do
        local output = (i .. ": " .. cases[i] .. "): ")
        output = output .. datesWD.test(v) .. "\n"
        io.write(output)
    end
end
--]]
-- runWD()

--[[
print(datesWD.test(args={""}))
print(datesWD.test(3}))
print(datesWD.test(false}))
print(datesWD.test(true}))
print(datesWD.test("1705-01-06"))
print(datesWD.test("February 2","1905","January 20"))
--]]

local func1 = function(...)
    return(...)
end

local a,b,c = "abc", "CBA", "1_%"
print(a:byte(1), a:byte(2), a:byte(3))
print(b:byte(1), b:byte(2), b:byte(3))
print(c:byte(1), c:byte(2), c:byte(3))

local x = c:byte(3) >> 1
local y
local z

print()
print()
print()
print()
print()
print()
print(a,b,c)