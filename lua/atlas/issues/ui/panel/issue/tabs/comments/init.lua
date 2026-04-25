---@class IssuesCommentsTab : IssuesPanelTabModule
local M = {}

local utils = require("atlas.ui.shared.utils")
local icons = require("atlas.ui.shared.icons")
local highlights = require("atlas.ui.shared.highlights")
local spinner = require("atlas.ui.components.spinner")
local threads = require("atlas.ui.components.threadsv2")
local footer = require("atlas.ui.components.footer")
local state = require("atlas.issues.ui.panel.issue.tabs.comments.state")

local PADDING_X = 1

---@type { cancel: fun() }[]
local in_flight = {}

local function cancel_all()
	for _, handle in ipairs(in_flight) do
		handle.cancel()
	end
	in_flight = {}
end

---@param handle { cancel: fun() }|nil
local function track(handle)
	if handle then
		table.insert(in_flight, handle)
	end
end

---@return IssuesProvider|nil
local function get_provider()
	return require("atlas.issues.state").provider
end

---@param comments IssueComment[]
---@return IssueComment[]
local function root_comments(comments)
	local id_set = {}
	for _, c in ipairs(comments) do
		id_set[tostring(c.id)] = true
	end

	local roots = {}
	for _, c in ipairs(comments) do
		if c.parent_id == nil or not id_set[tostring(c.parent_id)] then
			table.insert(roots, c)
		end
	end
	return roots
end

---@param comment IssueComment
---@return AtlasThreadV2Item
local function to_thread_item(comment)
	local author = comment.author and comment.author.display_name or "Unknown"
	local body = tostring(comment.body or "")

	---@type AtlasThreadV2Item
	local item = {
		icon = icons.general("user"),
		author = author,
		right_text = utils.relative_time_text(comment.created),
		content = body ~= "" and body or nil,
		meta = { comment = comment },
		line_map = { kind = "comment", comment = comment },
	}

	if comment.children and #comment.children > 0 then
		item.children = {}
		for _, child in ipairs(comment.children) do
			table.insert(item.children, to_thread_item(child))
		end
	end

	return item
end

---@param issue Issue
---@param refresh fun()
---@param opts { force_refresh: boolean|nil }|nil
function M.on_select(issue, refresh, opts)
	opts = opts or {}
	local provider = get_provider()
	if not provider or not provider.fetch_comments then
		return
	end

	local force_refresh = opts.force_refresh == true
	if not force_refresh and state.comments ~= nil then
		return
	end

	cancel_all()
	state.is_loading = true
	state.issue = issue

	local issue_key = tostring(issue.key or "")
	footer.notify("loading", string.format("Loading comments for %s...", issue_key))

	track(provider.fetch_comments(issue_key, { force_load = force_refresh }, function(comments, err)
		state.is_loading = false

		if err then
			state.comments = {}
			footer.notify("error", string.format("Failed to load comments for %s", issue_key))
		else
			state.comments = comments or {}
			footer.notify("success", string.format("Comments loaded for %s (%d)", issue_key, #state.comments), 1200)
		end

		refresh()
	end))
end

---@param issue Issue
---@param width integer
---@return string[], table[], table<integer, table>|nil
function M.render(issue, width)
	local lines = {}
	local spans = {}

	local count_text = state.comments and tostring(#state.comments) or "..."
	utils.push(lines, spans, string.format("Comments (%s)", count_text), "AtlasColumnHeader", PADDING_X)

	if state.is_loading then
		utils.push(lines, spans, spinner.with_text("Loading comments..."), "AtlasTextMuted", PADDING_X)
		return lines, spans, {}
	end

	if not state.comments or #state.comments == 0 then
		utils.push(lines, spans, "No comments.", "AtlasTextMuted", PADDING_X)
		return lines, spans, {}
	end

	local roots = root_comments(state.comments)
	local thread_items = {}
	for _, comment in ipairs(roots) do
		table.insert(thread_items, to_thread_item(comment))
	end

	local t_lines, t_spans, t_line_map = threads.render(thread_items, width, {
		padding_x = PADDING_X,
		mode = "tree",
		author_hl = function(_, author)
			return highlights.dynamic_for(author)
		end,
	})

	utils.append_block(lines, spans, { lines = t_lines, highlights = t_spans })

	-- Offset thread line_map
	local line_map = {}
	for lnum, entry in pairs(t_line_map or {}) do
		line_map[#lines - #t_lines + lnum] = entry
	end

	return lines, spans, line_map
end

---@param _lnum integer
---@param entry table
---@return boolean
function M.is_selectable_line(_lnum, entry)
	return entry.kind == "comment"
end

---@param issue Issue
---@param entry table
---@return boolean|nil
function M.on_enter(issue, entry)
	if entry.kind == "comment" and entry.comment then
		local url = entry.comment.url
		if url and url ~= "" then
			vim.ui.open(url)
			return true
		end
	end
end

function M.activate() end

function M.deactivate()
	cancel_all()
end

return M
