package.path = package.path .. ";?;?.lua;.\\lualib\\?.lua;./lualib/?.lua;.\\modules\\?.lua;./modules/?.lua"
local mw = require("mw")
local bit32 = require("bit32"); mw.bit32 = bit32
local bit = require("luabit/bit"); mw.bit = bit
local hex = require("luabit/hex"); mw.hex = hex
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

local p = {}

-- in VSC actboy168.lua-debug io.write will appear in "DEBUG CONSOLE"
local output = function(...)
    print(mw.allToString("\n",...))
end

local function mw_logObject (t)
    mw.logObject( t )
    output(mw.getLogBuffer())
    mw.clearLogBuffer()
end

-- run some tests (without verification of results
-- need tables with input and output values for this)
local run = function ()
    -- output(mw_logObject(mw))
    output("mw")
    output("\nbit functions testing:")
    local a_int1, a_int2, a_bit = 18, 3, 1
    output( "bit: bnot" .. a_int1 .. " =",bit.bnot(18),
            "bit32: ",mw.bit32.bnot(a_int1))
    output( "bit: " .. a_int1 .. " band " .. a_int2 .. " =",bit.band(18,1),
            "bit32: ",mw.bit32.band(a_int1, a_int2))
    output( "bit: " .. a_int1 .. " bor  " .. a_int2 .. " =",bit.bor(18,1),
            "bit32: ",mw.bit32.bor(a_int1, a_int2))
    output( "bit: " .. a_int1 .. " bxor " .. a_int2 .. " =",bit.bxor(18,1),
            "bit32: ",mw.bit32.bxor(a_int1, a_int2))
    output( "bit: " .. a_int1 .. " bxor2 " .. a_int2 .. " =",bit.bxor2(18,1))
    output( "bit: " .. a_int1 .. " brshift " .. a_bit .. " =",bit.brshift(18,1),
            "bit32: ",mw.bit32.rshift(a_int1, a_bit))
    output( "bit: " .. a_int1 .. " bl_rshift " .. a_bit .. " =",bit.blogic_rshift(18,1), 
            "bit32: ",mw.bit32.arshift(a_int1, a_bit))
    output( "bit: " .. a_int1 .. " blshift " .. a_bit .. " =",bit.blshift(18,1),
            "bit32: ",mw.bit32.lshift(a_int1, a_bit))
    local bit1 = bit.tobits(a_int1)
    output("bit: tobits " .. a_int1 .. " =",unpack(bit1))
    output("bit: tonumb --//-- =",bit.tonumb(bit1))
    local n, v, field, width = 16, 1, 2, 3
    local x, disp = 16, 1
    output("bit32: lrotate" .. x .. ", " .. disp .. "=",mw.bit32.lrotate( x, disp ))
    output("bit32: rrotate" .. x .. ", " .. disp .. "=",mw.bit32.rrotate( x, disp ))
    output("bit32: extract" .. n .. "," .. field .. "," .. width .. "=",mw.bit32.extract( n, field, width ))
    output("bit32: replace" .. n .. "," .. v .. "," .. field .. "," .. width .. "=",mw.bit32.replace( n, v, field, width))
    output("\nmodules testing:")
    output("yesno module: 0, 1 =",yesno(0),yesno(1))

end

run()

local func1 = function(...)
    return(...)
end

local a,b,c = "abc", "CBA", "1_%"
print(a:byte(1), a:byte(2), a:byte(3))
print(b:byte(1), b:byte(2), b:byte(3))
print(c:byte(1), c:byte(2), c:byte(3))

local x
local y
local z

print()
print()
print()
print()
print()
print()
print(a,b,c)