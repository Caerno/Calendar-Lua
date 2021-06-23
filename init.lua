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

print("f" > "Dd")
print("Ff" < "d")