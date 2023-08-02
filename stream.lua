local function str_to_stream(str, file)
	local s = {
		str = str,
		pos = 1,
		file = file or "(unknown)"
	}
	function s:next(c)
		c = c or 1
		--dprint(c)
		local d = self.str:sub(self.pos, self.pos+c-1)
		self.pos = self.pos + c
		return d
	end

	function s:peek(c)
		c = c or 1
		if (c < 0) then
			return self.str:sub(self.pos+c, self.pos-1)
		end
		return self.str:sub(self.pos, self.pos+c-1)
	end

	function s:rewind(c)
		c = c or 1
		self.pos = self.pos - c
		return self.pos
	end

	function s:skip(c)
		c = c or 1
		self.pos = self.pos + c
		return self.pos
	end

	function s:set(c)
		--dprint(c)
		self.pos = c or self.pos
		return self.pos
	end

	function s:tell()
		return self.pos
	end

	function s:size()
		return #self.str
	end

	function s:finish()
		return self.str:sub(self.pos)
	end

	function s:find(pat, raw, start)
		start = start or 0
		local matches = table.pack(self.str:find(pat, self.pos+start-1, raw))
		local st, en = table.remove(matches, 1), table.remove(matches, 1)
		matches.n = matches.n - 2
		if not st then return nil, "not found" end
		return st-self.pos+1, en-self.pos+1, table.unpack(matches)
	end

	function s:next_instance(pat, raw)
		local st, en = self.str:find(pat, self.pos, raw)
		if not st then return nil, "not found" end
		self.pos = en+1
		return self.str:sub(st, en)
	end

	function s:get_yx() -- it *is* yx
		local pos = 0
		local line = 1
		while pos < self.pos do
			local newpos = self.str:find("\n", pos+1)
			if not newpos then return line+1, 0 end
			if newpos > self.pos then
				return line, self.pos-pos
			end
			line = line + 1
			pos = newpos
		end
		return line, 1
	end

	return s
end

return str_to_stream