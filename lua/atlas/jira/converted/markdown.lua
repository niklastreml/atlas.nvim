local M = {}

---FIX: TBH mostly ai generated but works for basic cases, needs more work to handle all edge cases and more complex ADF structures but its a good start...

local function text_node(text, marks)
	return {
		type = "text",
		text = text,
		marks = marks,
	}
end

local function append_text(nodes, text, marks)
	if text == nil or text == "" then
		return
	end

	local last = nodes[#nodes]
	if marks == nil and last ~= nil and last.type == "text" and last.marks == nil then
		last.text = (last.text or "") .. text
		return
	end

	table.insert(nodes, text_node(text, marks))
end

local status_emoji_to_color = {
	[""] = "blue",
	[""] = "green",
	[""] = "yellow",
	[""] = "red",
	[""] = "neutral",
}

---@param text string
---@param i integer
---@return string, integer
local function utf8_char_at(text, i)
	local b1 = text:byte(i)
	if b1 == nil then
		return "", 1
	end

	if b1 < 0x80 then
		return text:sub(i, i), 1
	end

	if b1 >= 0xC2 and b1 <= 0xDF then
		return text:sub(i, i + 1), 2
	end

	if b1 >= 0xE0 and b1 <= 0xEF then
		return text:sub(i, i + 2), 3
	end

	if b1 >= 0xF0 and b1 <= 0xF4 then
		return text:sub(i, i + 3), 4
	end

	return text:sub(i, i), 1
end

local function parse_inline(text)
	local nodes = {}
	local i = 1
	local status_icon, icon_size = utf8_char_at(text, 1)
	local status_color = status_emoji_to_color[status_icon]
	if status_color ~= nil then
		local rest = text:sub(icon_size + 1)
		local leading_ws, status_text, trailing_ws = rest:match("^(%s+)([^%s].-)(%s*)$")
		if leading_ws ~= nil and status_text ~= nil then
		table.insert(nodes, {
			type = "status",
			attrs = {
				text = status_text,
				color = status_color,
				style = "",
			},
		})
		if trailing_ws ~= nil and trailing_ws ~= "" then
			append_text(nodes, trailing_ws)
		end
		return nodes
		end
	end

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
			local date_timestamp = url:match("^atlas%-date:(.+)$")
			if date_timestamp ~= nil and date_timestamp ~= "" then
				table.insert(nodes, {
					type = "date",
					attrs = {
						timestamp = date_timestamp,
					},
				})
			else
				table.insert(nodes, {
					type = "text",
					text = label,
					marks = {
						{ type = "link", attrs = { href = url } },
					},
				})
			end
			i = e + 1
		elseif text:sub(i, i + 1) == "**" then
			local close = text:find("%*%*", i + 2)
			if close then
				local content = text:sub(i + 2, close - 1)
				append_text(nodes, content, { { type = "strong" } })
				i = close + 2
			else
				local ch, size = utf8_char_at(text, i)
				append_text(nodes, ch)
				i = i + size
			end
		elseif text:sub(i, i + 1) == "~~" then
			local close = text:find("~~", i + 2)
			if close then
				local content = text:sub(i + 2, close - 1)
				append_text(nodes, content, { { type = "strike" } })
				i = close + 2
			else
				local ch, size = utf8_char_at(text, i)
				append_text(nodes, ch)
				i = i + size
			end
		elseif text:sub(i, i) == "*" then
			local close = text:find("%*", i + 1)
			if close then
				local content = text:sub(i + 1, close - 1)
				append_text(nodes, content, { { type = "em" } })
				i = close + 1
			else
				local ch, size = utf8_char_at(text, i)
				append_text(nodes, ch)
				i = i + size
			end
		elseif text:sub(i, i) == "`" then
			local close = text:find("`", i + 1)
			if close then
				local content = text:sub(i + 1, close - 1)
				append_text(nodes, content, { { type = "code" } })
				i = close + 1
			else
				local ch, size = utf8_char_at(text, i)
				append_text(nodes, ch)
				i = i + size
			end
		else
			local ch, size = utf8_char_at(text, i)
			append_text(nodes, ch)
			i = i + size
		end
		end
	end

	return nodes
end

---@param s string
---@return string
local function trim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

---@param line string
---@return string[]
local function parse_table_cells(line)
	local row = trim(line)
	if row:sub(1, 1) == "|" then
		row = row:sub(2)
	end
	if row:sub(-1) == "|" then
		row = row:sub(1, -2)
	end

	local cells = vim.split(row, "|", { plain = true })
	for i, cell in ipairs(cells) do
		cells[i] = trim(cell)
	end
	return cells
end

---@param line string
---@return boolean
local function is_table_row(line)
	local row = trim(line)
	if row == "" then
		return false
	end
	return row:find("|", 1, true) ~= nil
end

---@param line string
---@return boolean
local function is_table_separator(line)
	local cells = parse_table_cells(line)
	if #cells == 0 then
		return false
	end

	for _, cell in ipairs(cells) do
		if not trim(cell):match("^:?-+:?$") then
			return false
		end
	end

	return true
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

			local node = {
				type = "codeBlock",
				content = {
					{ type = "text", text = table.concat(code_lines, "\n") },
				},
			}
			if lang ~= nil and lang ~= "" then
				node.attrs = { language = lang }
			end

			table.insert(doc.content, node)
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
		elseif i + 1 <= #lines and is_table_row(line) and is_table_separator(lines[i + 1]) then
			local headers = parse_table_cells(line)
			local table_node = {
				type = "table",
				content = {},
			}

			local header_row = {
				type = "tableRow",
				content = {},
			}
			for _, cell in ipairs(headers) do
				table.insert(header_row.content, {
					type = "tableHeader",
					content = {
						{
							type = "paragraph",
							content = parse_inline(cell),
						},
					},
				})
			end
			table.insert(table_node.content, header_row)

			i = i + 2
			while i <= #lines and is_table_row(lines[i]) do
				local cells = parse_table_cells(lines[i])
				local body_row = {
					type = "tableRow",
					content = {},
				}
				for _, cell in ipairs(cells) do
					table.insert(body_row.content, {
						type = "tableCell",
						content = {
							{
								type = "paragraph",
								content = parse_inline(cell),
							},
						},
					})
				end
				table.insert(table_node.content, body_row)
				i = i + 1
			end

			i = i - 1
			table.insert(doc.content, table_node)
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
