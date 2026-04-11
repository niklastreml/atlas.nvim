local M = {}
local state = require("atlas.jira.panel.tabs.overview.state")
local panel_state = require("atlas.jira.panel.state")
local issues = require("atlas.jira.api.issues")
local adf = require("atlas.jira.converted.adf")
local config = require("atlas.config")
local footer = require("atlas.ui.components.footer")

local active_handle = nil

---@return integer|nil
local function detail_win()
	local layout = require("atlas.ui.layout")
	local win = layout.win_id("detail")
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	return win
end

local function cancel_active_handle()
	if active_handle ~= nil and active_handle.cancel then
		pcall(active_handle.cancel)
	end
	active_handle = nil
end

---@param issue JiraIssue|nil
---@param opts? { force_refresh?: boolean }
function M.show(issue, opts)
	opts = opts or {}
	local force_refresh = opts.force_refresh == true
	local current_key = state.issue and state.issue.key or nil
	local next_key = issue and issue.key or nil

	if force_refresh or current_key ~= next_key then
		cancel_active_handle()
	end

	if not force_refresh and current_key == next_key and state.md_description == "loading" then
		state.issue = issue
		state.line_map = {}
		require("atlas.jira.panel.init").refresh()
		return
	end

	state.issue = issue
	state.line_map = {}

	if issue == nil or issue.key == "" then
		state.adf_description = nil
		state.md_description = nil
		state.custom_fields = nil
		return
	end

	if not force_refresh and current_key == next_key and state.md_description ~= nil and state.md_description ~= "loading" then
		return
	end

	local issue_key = issue.key
	state.adf_description = "loading"
	state.md_description = "loading"
	state.custom_fields = nil
	footer.notify("loading", string.format("Loading description for %s...", issue_key))
	require("atlas.jira.panel.init").refresh()

	local project_key = issue.project and issue.project.key or nil
	local project_cfg = project_key
			and type(config.options.jira.project_config) == "table"
			and config.options.jira.project_config[project_key]
		or nil

	local extra_fields = {}
	if type(project_cfg) == "table" then
		for field_id, _ in pairs(project_cfg) do
			table.insert(extra_fields, field_id)
		end
	end

	active_handle = issues.get_issue_detail(issue_key, function(detail, err)
		active_handle = nil
		if state.issue == nil or state.issue.key ~= issue_key then
			return
		end

		if err ~= nil then
			state.adf_description = nil
			state.md_description = nil
			state.custom_fields = nil
			footer.notify("error", string.format("Failed loading description for %s", issue_key))
		else
			local description = detail and detail.description or nil
			if type(description) == "table" then
				state.adf_description = description
				local markdown = adf.to_markdown(description)
				-- Keep empty string to mark "loaded but empty" and avoid refetch loops.
				state.md_description = markdown
			else
				-- Jira returns `description = null` for empty descriptions.
				-- Treat this as loaded-empty so we do not refetch on every tab switch.
				state.adf_description = nil
				state.md_description = ""
			end

			if type(project_cfg) == "table" and detail and detail.custom_fields then
				local fields = {}
				for field_id, field_cfg in pairs(project_cfg) do
					local raw_value = detail.custom_fields[field_id]
					if raw_value == vim.NIL then
						raw_value = nil
					end
					local formatted = nil
					if type(field_cfg.format) == "function" then
						local ok, result = pcall(field_cfg.format, raw_value)
						if result == vim.NIL then
							result = nil
						end
						if ok and (type(result) == "string" or result == nil) then
							formatted = result
						end
					end
					if type(formatted) == "string" and formatted ~= "" then
						table.insert(fields, {
						name = field_cfg.name or field_id,
						formatted = formatted,
						hl_group = field_cfg.hl_group,
						display = field_cfg.display == "table" and "table" or "chip",
					})
					end
				end
				state.custom_fields = #fields > 0 and fields or nil
			end

			footer.notify("success", string.format("Description loaded for %s", issue_key), 1200)
		end

		require("atlas.jira.panel.init").refresh()
	end, {
		extra_fields = #extra_fields > 0 and extra_fields or nil,
		force_load = force_refresh,
	})
end

function M.toggle_view_mode()
	if state.view_mode == "raw" then
		state.view_mode = "markdown"
		footer.notify("info", "Overview: Markdown view", 1000)
	else
		state.view_mode = "raw"
		footer.notify("info", "Overview: Raw ADF view", 1000)
	end

	require("atlas.jira.panel.init").refresh()
end

---@param delta integer
function M.move(delta)
	if panel_state.current_tab ~= "overview" then
		return
	end

	local win = detail_win()
	if win == nil then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local max_line = vim.api.nvim_buf_line_count(buf)

	if delta == 0 then
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
		return
	end

	if delta == math.huge then
		vim.api.nvim_win_set_cursor(win, { max_line, 0 })
		return
	end

	local line = vim.api.nvim_win_get_cursor(win)[1]
	local step = delta > 0 and 1 or -1
	local target = math.max(1, math.min(max_line, line + step))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
end

function M.refresh()
	if state.issue == nil then
		return
	end

	M.show(state.issue, { force_refresh = true })
end

function M.reset()
	cancel_active_handle()
	state.reset()
end

function M.deactivate()
end

---@return boolean
function M.is_loading()
	return state.md_description == "loading"
end

return M
