local args = { ... }

local basename = args[1]

local opts = {
	rotate_offset_x = 0,
	rotate_offset_y = 0,
	scale = 1.5,
	radial_blur = 30,
	final_center_x = -28/128,
	final_center_y = 10/128,
	output_size = 128,
}


for i,v in ipairs(args) do
	if i ~= 1 then
		local key,val = v:match("(.*)=(.*)")
		if key and val then
			if (opts[key] ~= nil) then
				opts[key] = tonumber(val)
			else
				print("Unrecognized option:",key)
				print("Valid options are:")
				for k,v in pairs(opts) do
					io.write(k.." ")
				end
				print()
				return
			end
		end
	end
end

local output_size = opts.output_size
local halfsize = output_size/2

local function execute(cmd, keep)
	local cmd = cmd
	if not keep then
		cmd = cmd:gsub("\n"," ")
		cmd = cmd:gsub("%s%s*", " ")
	end
	print("EXECUTE: "..cmd)
	if (cmd:find(">")) then
		assert("Shouldn't pass a command with > (io redirect) to execute")
		return
	end
	local filename = os.tmpname()
	local success, exit_type, signal = os.execute(cmd .. " > "..filename)
	local f = io.open(filename)
	local stdout = f:read("*a")
	f:close()
	os.remove(filename)
	return stdout, success, exit_type, signal
end

local skew_pts = {
	{ x =  226/1024, y = 121/1024 }, -- 0,0
	{ x =  854/1024, y = 253/1024 }, -- 1,0
	{ x =    0/1024, y = 740/1024 }, -- 0,1
	{ x = 1024/1024, y = 859/1024 }  -- 1,1 
	--[[
	{ x =  250/1024, y = 238/1024 }, -- 0,0
	{ x =  819/1024, y = 370/1024 }, -- 1,0
	{ x =    2/1024, y = 683/1024 }, -- 0,1
	{ x = 1021/1024, y = 855/1024 }  -- 1,1 
	]] -- More horizontal version
}

local original_pts = {
	{ x = 0, y = 0 },
	{ x = 1, y = 0 },
	{ x = 0, y = 1 },
	{ x = 1, y = 1 }
}
local function pixelize(pts, size)
	for i,pt in pairs(pts) do
		for coord,val in pairs(pt) do
			pt[coord] = math.floor(val*size)
		end
	end
end
pixelize(skew_pts,     output_size)
pixelize(original_pts, output_size)

local center_x = 0
local center_y = 0
for i,v in ipairs(skew_pts) do
	center_x = center_x + v.x
	center_y = center_y + v.y
end
center_x = center_x / 4
center_y = center_y / 4

local transform = ""
for i,pt in ipairs(original_pts) do
	local skew = skew_pts[i]
	transform = transform .. pt.x .. "," ..pt.y .. " " .. skew.x .. "," .. skew.y .. " "
end
print(transform)

execute("mkdir -p __tmp")
local resized_to = math.floor(output_size/2).."x"..math.floor(output_size/2)
execute("convert "..basename.." -resize "..resized_to.." -fuzz 5% -fill none -draw 'matte 0,0 floodfill' __tmp/fidget.png")

for i = 1,10 do
	local command = [[convert 
	-compose over 
	\(
		-compose over 
		background.png 
		\( __tmp/fidget.png 
			-virtual-pixel transparent 
			-gravity center 
			-background transparent 
			-extent #BASESIZE#x#BASESIZE# 
			-radial-blur #RAD_BLUR#
			-distort SRT '#SCALE# 0'
			-distort SRT '#TRANS_X#,#TRANS_Y# 0'
			-distort SRT 1,#ROTATION# 
			-distort Perspective '#TRANSFORM#' 
			-extent #BASESIZE#x#BASESIZE# 
			-distort SRT '0,0 1 0 #NEW_COM_X#,#NEW_COM_Y#' 
		\) 
		-composite 
	\) 
	foreground.png 
	-composite 
	-background white -alpha remove
	__tmp/a#I#.png
	]]
	local options = {
		I = i,
		ROTATION = (i-1)*36,
		TRANSFORM = transform,
		BASESIZE  = output_size,
		RAD_BLUR  = opts.radial_blur,
		NEW_COM_X = opts.final_center_x  * output_size,
		NEW_COM_Y = opts.final_center_y  * output_size,
		TRANS_X   = opts.rotate_offset_x * output_size,
		TRANS_Y   = opts.rotate_offset_y * output_size,
		HX = center_x/2,
		HY = center_x/2,
		SCALE = opts.scale
	}
	command = command:gsub("#([A-Z_]*)#", function(subject) 
		if not options[subject] then error("No option '"..subject.."'") end
	 	return options[subject] 
	end)
	execute(command)
	print("frame ",i)
end
execute("convert -delay 3 -dispose Background __tmp/a*.png -fuzz 5% -transparent white __tmp/final.gif")
