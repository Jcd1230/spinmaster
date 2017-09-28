local args = { ... }

local function execute(cmd, keep)
	if not keep then
		cmd = cmd:gsub("\n"," ")
	end
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

local skew_ratios = {
	 250/1024, 238/1024, -- 0,0
	 819/1024, 370/1024, -- 1,0
	   2/1024, 683/1024, -- 0,1
	1021/1024, 855/1024  -- 1,1 
}
local basescale = 128
local original = {
	0,0,
	basescale,0,
	0,basescale,
	basescale, basescale
}
local transform = ""
for i = 0,3 do
	transform = transform ..
	 math.floor(original[1+i*2])..","..math.floor(original[1+i*2+1]).." "
	 ..math.floor(basescale*skew_ratios[1+i*2])..","..math.floor(basescale*skew_ratios[1+i*2+1]) .. " "
end
print(transform)

local basename = args[1]
--execute("mkdir __tmp")
--execute("convert "..basename..".png -virtual-pixel transparent -gravity center -background transparent -extent 64x64 -radial-blur 20 __tmp/radial_blurred.png")

execute("convert "..args[1].." -resize 64x64 -fuzz 5% -fill none -draw 'matte 0,0 floodfill' fidget.png")

for i = 1,10 do
	execute([[convert fidget.png 
 -virtual-pixel transparent 
 -gravity center 
 -background transparent 
 -extent 128x128 
 -radial-blur 40
 -distort SRT 1,]]..((i-1)*36)..[[ 
 -distort Perspective ']]..transform..[[' 
 -extent 128x128 -distort SRT '64,64 1.5 0 36,68'
 __tmp/a]]..i..".png")
	execute("convert -compose over ../hand2.png __tmp/a"..i..".png -composite __tmp/b"..i..".png")
	execute("convert -compose over __tmp/b"..i..".png  ../hand_top.png -composite __tmp/c"..i..".png")
	execute("convert __tmp/c"..i..".png -background white -alpha remove __tmp/d"..i..".png")
	print("frame ",i)
end
execute("convert -delay 3 -dispose Background __tmp/d*.png -fuzz 5% -transparent white __tmp/final.gif")

-- Input filename
-- 4 sets of u,v -> x,y (pixel coordinates)
-- Output filename
local skew_command = "convert %s -virtual-pixel transparent -distort Perspective '%d,%d,%d,%d %d,%d,%d,%d %d,%d,%d,%d %d,%d,%d,%d' %s"

