local M = {}

--- FIX: Its not perfect and just AI generated TBH
---@param adf any
---@return string
function M.to_markdown(adf)
	if type(adf) ~= "table" then
		return ""
	end

	local out = {}

	local function push(text)
		if type(text) == "string" and text ~= "" then
			table.insert(out, text)
		end
	end

	local function walk_inlines(nodes)
		local parts = {}
		for _, node in ipairs(nodes or {}) do
			if type(node) == "table" then
				if node.type == "text" then
					table.insert(parts, tostring(node.text or ""))
				elseif node.type == "mention" then
					local attrs = node.attrs or {}
					local mention_text = attrs.text or attrs.displayName or attrs.id or ""
					table.insert(parts, string.format("`%s`", tostring(mention_text)))
				elseif node.type == "hardBreak" then
					table.insert(parts, "\\n")
				elseif type(node.content) == "table" then
					table.insert(parts, walk_inlines(node.content))
				end
			end
		end
		return table.concat(parts)
	end

	local function walk_blocks(nodes, depth)
		depth = depth or 0
		for _, node in ipairs(nodes or {}) do
			if type(node) ~= "table" then
				goto continue
			end

			local t = node.type
			if t == "heading" then
				local level = tonumber((node.attrs or {}).level) or 1
				if level < 1 then
					level = 1
				end
				if level > 6 then
					level = 6
				end
				push(string.rep("#", level) .. " " .. walk_inlines(node.content or {}))
				push("\n\n")
			elseif t == "paragraph" then
				push(walk_inlines(node.content or {}))
				push("\n\n")
			elseif t == "bulletList" then
				for _, li in ipairs(node.content or {}) do
					local text = walk_inlines((li.content and li.content[1] and li.content[1].content) or {})
					push(string.rep("  ", depth) .. "- " .. text)
					push("\n")
				end
				push("\n")
			elseif t == "orderedList" then
				local n = 1
				for _, li in ipairs(node.content or {}) do
					local text = walk_inlines((li.content and li.content[1] and li.content[1].content) or {})
					push(string.rep("  ", depth) .. tostring(n) .. ". " .. text)
					push("\n")
					n = n + 1
				end
				push("\n")
			elseif t == "codeBlock" then
				local lang = tostring((node.attrs or {}).language or "")
				push("```" .. lang .. "\n")
				push(walk_inlines(node.content or {}))
				push("\n```\n\n")
			elseif t == "blockquote" then
				local text = M.to_markdown({ type = "doc", version = 1, content = node.content or {} })
				for line in (text .. "\n"):gmatch("(.-)\n") do
					if line ~= "" then
						push("> " .. line)
						push("\n")
					end
				end
				push("\n")
			elseif t == "rule" then
				push("---\n\n")
			elseif type(node.content) == "table" then
				walk_blocks(node.content, depth + 1)
			end

			::continue::
		end
	end

	walk_blocks(adf.content or {}, 0)
	local md = table.concat(out)
	md = md:gsub("\n\n\n+", "\n\n"):gsub("^%s+", ""):gsub("%s+$", "")
	return md
end

return M
