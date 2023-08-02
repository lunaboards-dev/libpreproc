local lpp = {}
local parser = require("libpreproc.parser")

function lpp.instance()
	return setmetatable({
		gencode = {},
		env = {},
		export = {},
		tokens = {}
	}, {
		__index=parser
	})
end

function lpp.pattern(match, raw)
	if type(match) == "table" and match.__type == lpp.pattern then
		return match
	end
	return {
		__type=lpp.pattern,
		pattern = match,
		raw = raw,
		find = function(self, str, start)
			return str:find(self.pattern, self.raw, start)
		end,
		match = function(self, str, start)
			return str:match(self.pattern, self.raw, start)
		end
	}
end

function lpp.prefix(prefix, match)
	prefix = lpp.pattern(prefix, true)
	return function(str, inst, offset)
		offset = offset or 0
		print("pfx", prefix:find(str))
		local positions = table.pack(prefix:find(str))
		if not positions[1] then return end
		local st, en = table.remove(positions, 1), table.remove(positions, 1)
		local result = match(str, inst, en+1, en+1)
		print(result)
		if not result or result.start ~= en+1 then return end
		for i=1, #result.matches do
			table.insert(positions, result.matches[i])
		end
		return {
			start = st,
			size = (en-st+1)+result.size,
			inner_start = result.inner_start,
			inner_size = result.inner_size,
			matches = positions
		}
	end
end

function lpp.linestart(match)
	return function(str, inst, offset)
		local result = match(str, inst, offset)
		if not result then return end
		local dat = str:peek(result.start)
		if dat:sub(#dat, #dat) == "\n" then
			return result
		end
	end
end

function lpp.filestart(match)
	return function(str, inst, offset)
		if offset+str:tell() > 1 then return nil end
		local result = match(str, inst, offset)
		if result.start == 1 then
			return result
		end
	end
end

function lpp.match(pat)
	pat = lpp.pattern(pat, true)
	return function(str, inst, offset)
		offset = offset or 0
		local matches = table.pack(pat:find(str, offset))
		if not matches[1] then return end
		local st, en = table.remove(matches, 1), table.remove(matches, 1)
		return {
			start = st,
			size = en-st+1,
			inner_start=st,
			inner_size=en-st+1,
			matches = matches
		}
	end
end

function lpp.block(open, close)
	open = lpp.pattern(open, true)
	close = lpp.pattern(close, true)
	return function(str, inst, offset, maxstart)
		offset = offset or 0
		local st1, en1 = open:find(str, offset)
		if not st1 or (maxstart and st1 > maxstart) then return end
		local st2, en2 = close:find(str, en1+1)
		if not st2 then
			str:skip(st1)
			inst:error("unclosed block")
		end
		local inner = str:peek(st2-1):sub(en1+1)
		return {
			start = st1,
			size = en2-st1+1,
			inner_start = en1+1,
			inner_size = #inner,
			matches = {inner}
		}
	end
end

function lpp.inner_prefix(prefix, match)
	prefix = lpp.pattern(prefix, true)
	return function(str, inst, offset)
		local result = match(str, inst, offset)
		if not result then return end
		local inner = table.remove(result.matches)
		local matches = table.pack(inner:find(prefix.pattern, 1, prefix.raw))
		if not matches[1] then return end
		local st, en = table.remove(matches, 1), table.remove(matches, 1)
		if en == 0 then
			table.insert(result.matches, 1, "")
			table.insert(result.matches, inner)
			return result
		end
		if st ~= 1 then return end
		result.inner_start = result.inner_start+en
		result.inner_size = result.inner_size-en
		local new_inner = inner:sub(en+1)
		for i=1, #result.matches do
			table.insert(matches, result.matches[i])
		end
		table.insert(matches, new_inner)
		return {
			start = result.start,
			size = result.size,
			inner_start = result.inner_start,
			inner_size = result.inner_size,
			matches = matches
		}
	end
end

function lpp.inner_postfix(postfix, match)
	postfix = lpp.pattern(postfix, true)
	return function(str, inst, offset)
		local result = match(str, inst, offset)
		if not result then return end
		local inner = table.remove(result.matches)
		local matches = table.pack(inner:find(postfix.pattern, 1, postfix.raw))
		if not matches[1] then return end
		local st, en = table.remove(matches, 1), table.remove(matches, 1)
		if en == 0 then
			table.insert(result.matches, 1, "")
			table.insert(result.matches, inner)
			return result
		end
		if en ~= #inner then return end
		local size = en-st+1
		--result.inner_start = result.inner_start+en
		result.inner_size = result.inner_size-size
		local new_inner = inner:sub(en+1)
		for i=1, #result.matches do
			table.insert(matches, result.matches[i])
		end
		table.insert(matches, new_inner)
		return {
			start = result.start,
			size = result.size,
			inner_start = result.inner_start,
			inner_size = result.inner_size,
			matches = matches
		}
	end
end

return lpp