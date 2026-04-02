local M = {}

---FIX: TBH mostly ai generated but works for basic cases, needs more work to handle all edge cases and more complex ADF structures but its a good start...

local function text_node(text, marks)
	return {
		type = "text",
		text = text,
		marks = marks,
	}
end

local function parse_inline(text)
	local nodes = {}
	local i = 1

	while i <= #text do
		local ms, me, mention_label, mention_id = text:find("%[(.-)%]%{mention:([^}]+)%}", i)
		if ms == i then
			local mention_text = mention_label
			if mention_text ~= "" and mention_text:sub(1, 1) ~= "@" then
				mention_text = "@" .. mention_text
			end

			table.insert(nodes, {
				type = "mention",
				attrs = {
					id = mention_id,
					text = mention_text,
					accessLevel = "",
				},
			})
			i = me + 1
		else
		local s, e, label, url = text:find("%[(.-)%]%((.-)%)", i)
		if s == i then
			table.insert(nodes, {
				type = "text",
				text = label,
				marks = {
					{ type = "link", attrs = { href = url } },
				},
			})
			i = e + 1
		elseif text:sub(i, i + 1) == "**" then
			local close = text:find("%*%*", i + 2)
			if close then
				local content = text:sub(i + 2, close - 1)
				table.insert(nodes, text_node(content, { { type = "strong" } }))
				i = close + 2
			else
				table.insert(nodes, text_node(text:sub(i, i)))
				i = i + 1
			end
		elseif text:sub(i, i + 1) == "~~" then
			local close = text:find("~~", i + 2)
			if close then
				local content = text:sub(i + 2, close - 1)
				table.insert(nodes, text_node(content, { { type = "strike" } }))
				i = close + 2
			else
				table.insert(nodes, text_node(text:sub(i, i)))
				i = i + 1
			end
		elseif text:sub(i, i) == "*" then
			local close = text:find("%*", i + 1)
			if close then
				local content = text:sub(i + 1, close - 1)
				table.insert(nodes, text_node(content, { { type = "em" } }))
				i = close + 1
			else
				table.insert(nodes, text_node(text:sub(i, i)))
				i = i + 1
			end
		elseif text:sub(i, i) == "`" then
			local close = text:find("`", i + 1)
			if close then
				local content = text:sub(i + 1, close - 1)
				table.insert(nodes, text_node(content, { { type = "code" } }))
				i = close + 1
			else
				table.insert(nodes, text_node(text:sub(i, i)))
				i = i + 1
			end
		else
			table.insert(nodes, text_node(text:sub(i, i)))
			i = i + 1
		end
		end
	end

	return nodes
end

---@param text string
---@return table
function M.to_adf(text)
	local lines = vim.split(text or "", "\n", { plain = true })
	local doc = {
		type = "doc",
		version = 1,
		content = {},
	}

	local i = 1
	while i <= #lines do
		local line = lines[i]

		if line:match("^```") then
			local lang = line:match("^```(.*)")
			local code_lines = {}
			i = i + 1

			while i <= #lines and not lines[i]:match("^```") do
				table.insert(code_lines, lines[i])
				i = i + 1
			end

			table.insert(doc.content, {
				type = "codeBlock",
				attrs = { language = lang ~= "" and lang or nil },
				content = {
					{ type = "text", text = table.concat(code_lines, "\n") },
				},
			})
		elseif line:match("^#+%s") then
			local hashes, content = line:match("^(#+)%s+(.*)")
			table.insert(doc.content, {
				type = "heading",
				attrs = { level = #hashes },
				content = parse_inline(content),
			})
		elseif line:match("^>%s?") then
			local content = line:gsub("^>%s?", "")
			table.insert(doc.content, {
				type = "blockquote",
				content = {
					{
						type = "paragraph",
						content = parse_inline(content),
					},
				},
			})
		elseif line:match("^%*%s+") then
			local items = {}

			while i <= #lines and lines[i]:match("^%*%s+") do
				local item = lines[i]:gsub("^%*%s+", "")
				table.insert(items, {
					type = "listItem",
					content = {
						{
							type = "paragraph",
							content = parse_inline(item),
						},
					},
				})
				i = i + 1
			end

			i = i - 1

			table.insert(doc.content, {
				type = "bulletList",
				content = items,
			})
		elseif line:match("^%d+%.%s+") then
			local items = {}

			while i <= #lines and lines[i]:match("^%d+%.%s+") do
				local item = lines[i]:gsub("^%d+%.%s+", "")
				table.insert(items, {
					type = "listItem",
					content = {
						{
							type = "paragraph",
							content = parse_inline(item),
						},
					},
				})
				i = i + 1
			end

			i = i - 1

			table.insert(doc.content, {
				type = "orderedList",
				content = items,
			})
		elseif line == "---" then
			table.insert(doc.content, { type = "rule" })
		elseif line == "" then
			-- skip
		else
			table.insert(doc.content, {
				type = "paragraph",
				content = parse_inline(line),
			})
		end

		i = i + 1
	end

	return doc
end

return M
