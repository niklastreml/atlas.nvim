-- Thanks: https://github.com/julianlam/adf-to-md and https://luarocks.org/modules/quiqueporta/adf2md

local M = {}

local function collect_children(node, convert_node, ctx)
	local parts = {}
	for _, child in ipairs(node.content or {}) do
		table.insert(parts, convert_node(child, ctx))
	end
	return table.concat(parts)
end

local function warn(ctx, type_name)
	if ctx and ctx.warnings then
		ctx.warnings[type_name] = true
	end
end

local mark_handlers = {
	strong = function(text)
		return "**" .. text .. "**"
	end,
	em = function(text)
		return "*" .. text .. "*"
	end,
	code = function(text)
		return "`" .. text .. "`"
	end,
	strike = function(text)
		return "~~" .. text .. "~~"
	end,
	link = function(text, attrs)
		return "[" .. text .. "](" .. (attrs and attrs.href or "") .. ")"
	end,
}

local function apply_marks(text, marks, ctx)
	if not marks then
		return text
	end

	local result = text
	for _, mark in ipairs(marks) do
		local handler = mark_handlers[mark.type]
		if handler then
			result = handler(result, mark.attrs)
		else
			warn(ctx, mark.type)
		end
	end
	return result
end

local node_handlers = {}

node_handlers.doc = function(node, convert_node, ctx)
	local parts = {}
	for _, child in ipairs(node.content or {}) do
		table.insert(parts, convert_node(child, ctx))
	end
	return table.concat(parts, "\n\n")
end

node_handlers.text = function(node, _, ctx)
	return apply_marks(node.text or "", node.marks, ctx)
end

node_handlers.hardBreak = function()
	return "  \n"
end

node_handlers.paragraph = function(node, convert_node, ctx)
	return collect_children(node, convert_node, ctx)
end

node_handlers.mention = function(node)
	local attrs = type(node.attrs) == "table" and node.attrs or {}
	local mention_id = tostring(attrs.id or "")
	local mention_text = tostring(attrs.text or "")

	if mention_text == "" then
		return ""
	end

	if mention_id ~= "" then
		return string.format("[%s]{mention:%s}", mention_text, mention_id)
	end

	return mention_text
end

node_handlers.emoji = function(node)
	return node.attrs and node.attrs.shortName or ""
end

local function render_card(node)
	local url = node.attrs and node.attrs.url or ""
	local label = url:match("/browse/([^/]+)$") or url
	return "[" .. label .. "](" .. url .. ")"
end

node_handlers.inlineCard = render_card
node_handlers.blockCard = render_card
node_handlers.embedCard = render_card

node_handlers.status = function(node)
	local color_map = {
		blue = "",
		green = "",
		yellow = "",
		red = "",
		neutral = "",
	}
	local color = node.attrs and node.attrs.color or "neutral"
	local text = node.attrs and node.attrs.text or ""
	return (color_map[color] or "") .. " " .. text
end

node_handlers.date = function(node)
	local attrs = type(node.attrs) == "table" and node.attrs or {}
	local timestamp = tostring(attrs.timestamp or "")
	if timestamp == "" then
		return ""
	end

	local milliseconds = tonumber(timestamp)
	if milliseconds == nil then
		return "[date](atlas-date:" .. timestamp .. ")"
	end

	local seconds = math.floor(milliseconds / 1000)
	local label = os.date("!%Y-%m-%d", seconds)
	if type(label) ~= "string" or label == "" then
		label = "date"
	end

	return "[" .. label .. "](atlas-date:" .. timestamp .. ")"
end

node_handlers.listItem = function(node, convert_node, ctx)
	return collect_children(node, convert_node, ctx)
end

node_handlers.bulletList = function(node, convert_node, ctx)
	local items = {}
	for _, item in ipairs(node.content or {}) do
		table.insert(items, "* " .. collect_children(item, convert_node, ctx))
	end
	return table.concat(items, "\n")
end

node_handlers.orderedList = function(node, convert_node, ctx)
	local items = {}
	for i, item in ipairs(node.content or {}) do
		table.insert(items, i .. ". " .. collect_children(item, convert_node, ctx))
	end
	return table.concat(items, "\n")
end

node_handlers.taskList = function(node, convert_node, ctx)
	local items = {}
	for _, item in ipairs(node.content or {}) do
		local checkbox = "[ ]"
		if item.attrs and item.attrs.state == "DONE" then
			checkbox = "[x]"
		end
		table.insert(items, "- " .. checkbox .. " " .. collect_children(item, convert_node, ctx))
	end
	return table.concat(items, "\n")
end

node_handlers.taskItem = function(node, convert_node, ctx)
	return collect_children(node, convert_node, ctx)
end

node_handlers.blockquote = function(node, convert_node, ctx)
	local content = collect_children(node, convert_node, ctx)
	local lines = {}
	for line in content:gmatch("[^\n]+") do
		table.insert(lines, "> " .. line)
	end
	return table.concat(lines, "\n")
end

node_handlers.panel = function(node, convert_node, ctx)
	local map = {
		info = "NOTE",
		note = "NOTE",
		warning = "WARNING",
		error = "CAUTION",
		success = "TIP",
	}
	local panel_type = node.attrs and node.attrs.panelType or "info"
	local content = collect_children(node, convert_node, ctx)

	local lines = {}
	for line in content:gmatch("[^\n]+") do
		table.insert(lines, "> " .. line)
	end

	return "> [!" .. (map[panel_type] or "NOTE") .. "]\n" .. table.concat(lines, "\n")
end

node_handlers.heading = function(node, convert_node, ctx)
	local level = node.attrs and node.attrs.level or 1
	return string.rep("#", level) .. " " .. collect_children(node, convert_node, ctx)
end

node_handlers.codeBlock = function(node)
	local lang = node.attrs and node.attrs.language or ""
	local content = {}
	for _, child in ipairs(node.content or {}) do
		if child.type == "text" then
			table.insert(content, child.text)
		end
	end
	return "```" .. lang .. "\n" .. table.concat(content) .. "\n```"
end

node_handlers.media = function(node)
	local url = node.attrs and node.attrs.url or ""
	return "![](" .. url .. ")"
end

node_handlers.mediaSingle = function(node, convert_node, ctx)
	return collect_children(node, convert_node, ctx)
end

node_handlers.rule = function()
	return "---"
end

node_handlers.tableCell = function(node, convert_node, ctx)
	return collect_children(node, convert_node, ctx)
end

node_handlers.tableHeader = function(node, convert_node, ctx)
	return collect_children(node, convert_node, ctx)
end

node_handlers.tableRow = function(node, convert_node, ctx)
	local cells = {}
	for _, cell in ipairs(node.content or {}) do
		table.insert(cells, convert_node(cell, ctx))
	end
	return "| " .. table.concat(cells, " | ") .. " |"
end

node_handlers.table = function(node, convert_node, ctx)
	local rows = {}
	for i, row in ipairs(node.content or {}) do
		table.insert(rows, convert_node(row, ctx))
		if i == 1 then
			local cols = #(row.content or {})
			local sep = {}
			for _ = 1, cols do
				table.insert(sep, "---")
			end
			table.insert(rows, "| " .. table.concat(sep, " | ") .. " |")
		end
	end
	return table.concat(rows, "\n")
end

local function convert_node(node, ctx)
	local handler = node_handlers[node.type]
	if handler then
		return handler(node, convert_node, ctx)
	end

	warn(ctx, node.type)
	return ""
end

local function adf2md(document)
	local ctx = { warnings = {} }

	if type(document) ~= "table" then
		return "", ctx.warnings
	end

	if document.type ~= "doc" then
		local parts = {}
		for _, node in ipairs(document or {}) do
			table.insert(parts, convert_node(node, ctx))
		end
		return table.concat(parts, "\n\n"), ctx.warnings
	end

	return convert_node(document, ctx), ctx.warnings
end

---@param adf any
---@return string
function M.to_markdown(adf)
	local markdown = adf2md(adf)
	return markdown
end

return M
