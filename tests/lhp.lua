local lpp = require("libpreproc")

local parser = lpp.instance()

local blk = lpp.block("<?", "?>")
local eq = lpp.pattern("(=?)")
local php = lpp.pattern("(php%s)")
local lua = lpp.pattern("lua(=?)%s")
local args = lpp.pattern("args ", true)
local whitespace = lpp.pattern("%s*")
local php_match = lpp.inner_prefix(php, blk)
local args_badmatch = lpp.prefix(whitespace, lpp.inner_prefix(args, blk))
local args_match = lpp.filestart(args_badmatch)
local long_match = lpp.inner_prefix(lua, blk)
local short_match = lpp.inner_prefix(eq, blk)

local function code_emit(stream, instance, result)
	if result.matches[1] == "=" then
		instance:write(string.format("write(%s)", result.matches[2]))
		return
	end
	instance:write(result.matches[2])
end

-- ignore <?php ... ?>
parser:add_token(php_match, function(stream, instance, result)
	instance:emit("<?"..result.matches[1]..result.matches[2].."?>")
end)

parser:add_token(args_match, function(stream, instance, result)
	instance:write("local "..result.matches[1].."=...")
end)

parser:add_token(args_badmatch, function()
	parser:error("args must come at start of file")
end)

parser:add_token(long_match, code_emit)
parser:add_token(short_match, code_emit)

local file = arg[1]
local f = assert(io.open(file, "r"))
local dat = f:read("*a")
f:close()
table.remove(arg, 1)
parser:compile(dat)
print(parser.code)
print(parser:generate(table.unpack(arg)))