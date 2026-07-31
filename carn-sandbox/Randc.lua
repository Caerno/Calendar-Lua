local p={}

local bit32 = require( 'bit32' )

local getArgs = require('Module:Arguments').getArgs
local colors = {'AliceBlue', 'AntiqueWhite', 'Aqua', 'Aqua', 'Aquamarine', 'Azure', 'Beige', 'Bisque', 'Black', 'Black', 'BlanchedAlmond', 
	'Blue', 'Blue', 'BlueViolet', 'Brown', 'BurlyWood', 'CadetBlue', 'Chartreuse', 'Chocolate', 'Coral', 'CornflowerBlue', 'Cornsilk', 
	'Crimson', 'Cyan', 'DarkBlue', 'DarkCyan', 'DarkGoldenRod', 'DarkGray', 'DarkGreen', 'DarkGrey', 'DarkKhaki', 'DarkMagenta', 
	'DarkOliveGreen', 'DarkOrange', 'DarkOrchid', 'DarkRed', 'DarkSalmon', 'DarkSeaGreen', 'DarkSlateBlue', 'DarkSlateGray', 'DarkSlateGrey', 
	'DarkTurquoise', 'DarkViolet', 'DeepPink', 'DeepSkyBlue', 'DimGray', 'DimGrey', 'DodgerBlue', 'FireBrick', 'FloralWhite', 'ForestGreen', 
	'Fuchsia', 'Fuchsia', 'Gainsboro', 'GhostWhite', 'Gold', 'Goldenrod', 'Gray', 'Green', 'Green', 'GreenYellow', 'Grey', 'Honeydew', 
	'HotPink', 'IndianRed', 'Indigo', 'Ivory', 'Khaki', 'Lavender', 'LavenderBlush', 'LawnGreen', 'LemonChiffon', 'LightBlue', 'LightCoral', 
	'LightCyan', 'LightGoldenrodYellow', 'LightGray', 'LightGreen', 'LightGrey', 'LightPink', 'LightSalmon', 'LightSalmon', 'LightSeaGreen', 
	'LightSkyBlue', 'LightSlateGray', 'LightSlateGrey', 'LightSteelBlue', 'LightYellow', 'Lime', 'Lime', 'LimeGreen', 'Linen', 'Magenta', 
	'Maroon', 'MediumAquamarine', 'MediumBlue', 'MediumOrchid', 'MediumPurple', 'MediumSeaGreen', 'MediumSlateBlue', 'MediumSpringGreen', 
	'MediumTurquoise', 'MediumVioletRed', 'MidnightBlue', 'MintCream', 'MistyRose', 'Moccasin', 'NavajoWhite', 'Navy', 'OldLace', 'Olive', 
	'OliveDrab', 'Orange', 'OrangeRed', 'Orchid', 'PaleGoldenrod', 'PaleGreen', 'PaleTurquoise', 'PaleVioletRed', 'PapayaWhip', 'PeachPuff', 
	'Peru', 'Pink', 'Plum', 'PowderBlue', 'Purple', 'Purple', 'Red', 'Red', 'RosyBrown', 'RoyalBlue', 'SaddleBrown', 'Salmon', 'SandyBrown', 
	'SeaGreen', 'Seashell', 'Sienna', 'Silver', 'Silver', 'SkyBlue', 'SlateBlue', 'SlateGray', 'SlateGrey', 'Snow', 'SpringGreen', 'SteelBlue', 
	'Tan', 'Teal', 'Thistle', 'Tomato', 'Turquoise', 'Violet', 'Wheat', 'White', 'WhiteSmoke', 'Yellow', 'Yellow', 'YellowGreen'}

local letters = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'}

function p.ColorName( )
	math.randomseed(mw.site.stats.edits + mw.site.stats.pages + os.time() + math.floor(os.clock() * 1000000000))
	return colors[math.random(#colors)]
end

function p.ColorHEX( )
	math.randomseed( os.time()*2)
	return table.concat{"#",
		letters[math.random(16)],
		letters[math.random(16)],
		letters[math.random(16)],
		letters[math.random(16)],
		letters[math.random(16)],
		letters[math.random(16)]}
end

local function burrow (n)
	return 
		(bit32.extract( n, 0, 1 ) == 0 and 1 or -1) + 
		(bit32.extract( #tostring(n), 0, 1 ) == 0 and -2 or 2) + 
		(n > 1 and burrow (n - 1) or 0)
end

function p.earth2 (n)
	return burrow (n)
end

function p.earth (n)
	local k = 1 + math.floor(math.log10(n))
	return 2*(-1)^(k+1)*(n - 2*math.floor(10^k/11)) - n%2
end

return p
