package.path = package.path .. ";?;?.lua;.\\lualib\\?.lua;./lualib/?.lua;.\\modules\\?.lua;./modules/?.lua"
local mw = require("mw")

yesno = require('yesno')
calendar = require("calendar")
getArgs = function  (input)
    -- null operation - parameters are discarded
    return input
end
local init_test = require("init_test")

init_test.run()