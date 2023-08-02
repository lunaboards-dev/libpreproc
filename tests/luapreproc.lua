-- dry run luapreproc for including files together
local lpp = require("libpreproc")

local directive_prefix = lpp.pattern("--#", true)
local dblquotes = lpp.block('"', '"')
local include = (lpp.prefix(directive_prefix, lpp.prefix("include ", dblquotes)))

local parser = lpp.instance()

parser.env.directives = {}

local function readfile(file)
	local f = assert(io.open(file, "r"))
	local dat = f:read("*a")
	f:close()
	return dat
end

function parser.env.directives.include(inst, path)
	local newinst = inst:clone()
	local d = readfile(path)
	newinst:compile(d)
	local code = newinst:generate()
	return code
end

parser:add_token(include, function(stream, instance, result)
	instance:write(string.format("write(directives.include(_INSTANCE, %q))", result.matches[1]))
end)

local file = arg[1]

table.remove(arg, 1)
parser:compile(readfile(file))
print(parser.code)
print(parser:generate(table.unpack(arg)))