local parser = {}
local stream = require("libpreproc.stream")

function parser:add_token(match, process)
	table.insert(self.tokens, {
		match = match,
		process = process
	})
end

function parser:generate(...)
	if not self.gen then error("no compiled template!") end
	self.output = {}
	self.gen(...)
	return table.concat(self.output)
end

function parser:compile(code, name)
	local num_matches = 0
	self.stream = stream(code, name)
	self.gencode = {}
	while true do
		local first_match, processor
		for i=1, #self.tokens do
			--print("tok", i)
			local result = self.tokens[i].match(self.stream, self)
			if result then
				first_match = first_match or result
				processor = processor or self.tokens[i].process
				if first_match.start < result.start then
					processor = self.tokens[i].process
					first_match = result
				end
			end
		end
		if not first_match then break end
		if first_match.start ~= 1 then
			self:emit(self.stream:next(first_match.start-1))
		end
		self.stream:skip(first_match.size)
		processor(self.stream, self, first_match)
	end
	local emitting = self.stream:finish()
	if #emitting > 0 then
		self:emit(emitting)
	end
	self.code = table.concat(self.gencode, " ")
	local env = setmetatable({write = function(s)
		table.insert(self.output, s)
	end}, {__index=function(_, i)
		return self.export[i] or self.env[i] or _G[i]
	end, __newindex=function(_, k, v)
		self.export[k] = v
	end})
	self.gen = assert(load(self.code, (name and "="..name), "t", env))
	self.name = name
	return num_matches
end

function parser:write(str)
	table.insert(self.gencode, str)
end

function parser:error(err)
	local y, x = self.stream:get_yx()
	error(string.format("parser error: %s:%d,%d: %s", self.name or "(unknown)", y, x, err))
end

function parser:emit(str)
	self:write(string.format("write(%q)", str))
end

function parser:clone()
	local clone = {}
	clone.export = self.export
	clone.env = self.env
	clone.tokens = self.tokens
	clone.gencode = {}
	return setmetatable(clone, {__index=parser})
end

return parser