local M = {}

local footer = require("atlas.ui.components.footer")
local md_to_adf = require("atlas.jira.converted.markdown")
local utils = require("atlas.utils")
local icons = require("atlas.ui.icons")
local issue_helper = require("atlas.jira.ui.issue.helper")
local issue_layout = require("atlas.jira.ui.issue.layout")
local users_api = require("atlas.jira.api.users")
local issues_api = require("atlas.jira.api.issues")
local spinner = require("atlas.ui.components.spinner")
local spinner_popup = require("atlas.ui.popups.spinner")
local async_picker = require("atlas.ui.components.async_picker")

---@class IssueFields
---@field summary string
---@field description table|string|nil
---@field assignee JiraUser|nil
---@field reporter JiraUser
---@field project string
---@field issue_key string|nil
---@field issue_type JiraIssueType|nil

---@class IssueWindows
---@field title_buf integer|nil
---@field title_win integer|nil
---@field meta_buf integer|nil
---@field meta_win integer|nil
---@field desc_buf integer|nil
---@field desc_win integer|nil
---@field container_win integer|nil
---@field container_buf integer|nil

---@class IssueState
---@field layout IssueWindows
---@field preview_mode boolean
---@field original_markdown string
---@field fields IssueFields
---@field assignees JiraUser[]|"loading"|nil
---@field issue_types JiraIssueType[]|"loading"|nil
---@field spinner SpinnerInstance|nil
---@field assignees_handle { job_id: integer, cancel: fun() }|nil
---@field issue_types_handle { job_id: integer, cancel: fun() }|nil
---@field content_width integer
---@field on_submit fun(fields: IssueFields, done: fun(ok: boolean, err: string|nil))|nil

local state = {
	layout = {
		title_buf = nil,
		title_win = nil,
		meta_buf = nil,
		meta_win = nil,
		desc_buf = nil,
		desc_win = nil,
		container_win = nil,
		container_buf = nil,
	},
	preview_mode = false,
	original_markdown = "",
	fields = {
		summary = "",
		description = nil,
		assignee = nil,
		reporter = nil,
		project = "",
		issue_key = nil,
		issue_type = nil,
	},
	assignees = nil,
	issue_types = nil,
	spinner = nil,
	assignees_handle = nil,
	issue_types_handle = nil,
	content_width = 0,
	on_submit = nil,
}

local ns = vim.api.nvim_create_namespace("atlas.jira.create_issue")

local function valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function get_title()
	if not valid_buf(state.layout.title_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.layout.title_buf, 0, -1, false)
	return table.concat(lines, " ")
end

local function get_description()
	if not valid_buf(state.layout.desc_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.layout.desc_buf, 0, -1, false)
	return table.concat(lines, "\n")
end

local function is_modified()
	local title = vim.trim(get_title())
	local desc = vim.trim(get_description())
	return title ~= "" or desc ~= ""
end

---@param issue_types JiraIssueType[]
---@return JiraIssueType|nil
local function pick_default_issue_type(issue_types)
	for _, issue_type in ipairs(issue_types) do
		if tostring(issue_type.name or ""):lower() == "task" then
			return issue_type
		end
	end

	return issue_types[1]
end
local function update_meta_buffer(width)
	if not valid_buf(state.layout.meta_buf) then
		return
	end

	local w = width or state.content_width
	local lines, spans =
		issue_helper.render_meta_lines(w, state.fields, state.assignees, state.issue_types, state.spinner)
	vim.api.nvim_set_option_value("modifiable", true, { buf = state.layout.meta_buf })
	vim.api.nvim_buf_set_lines(state.layout.meta_buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.layout.meta_buf })

	vim.api.nvim_buf_clear_namespace(state.layout.meta_buf, ns, 0, -1)
	for _, span in ipairs(spans) do
		vim.api.nvim_buf_set_extmark(state.layout.meta_buf, ns, span.line, span.start_col, {
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

local function stop_loading_spinner_if_done()
	if not state.spinner then
		return
	end

	if state.assignees == "loading" or state.issue_types == "loading" then
		return
	end

	state.spinner:stop()
	state.spinner = nil
end

local function cancel_pending_requests()
	if state.assignees_handle and state.assignees_handle.cancel then
		pcall(state.assignees_handle.cancel)
	end
	state.assignees_handle = nil

	if state.issue_types_handle and state.issue_types_handle.cancel then
		pcall(state.issue_types_handle.cancel)
	end
	state.issue_types_handle = nil
end

local function close_ui()
	cancel_pending_requests()
	spinner_popup.stop()

	if state.spinner then
		state.spinner:stop()
		state.spinner = nil
	end

	issue_layout.close(state.layout)

	state.layout = {
		title_buf = nil,
		title_win = nil,
		meta_buf = nil,
		meta_win = nil,
		desc_buf = nil,
		desc_win = nil,
		container_win = nil,
		container_buf = nil,
	}
	state.preview_mode = false
	state.original_markdown = ""
	state.fields = {
		summary = "",
		description = nil,
		assignee = nil,
		reporter = nil,
		project = "",
		issue_key = nil,
		issue_type = nil,
	}
	state.assignees = nil
	state.issue_types = nil
	state.assignees_handle = nil
	state.issue_types_handle = nil
	state.content_width = 0
	state.on_submit = nil
end

local function confirm_close()
	if not is_modified() then
		close_ui()
		return
	end

	vim.ui.input({
		prompt = "Discard changes? [y/N]: ",
	}, function(input)
		if input == nil then
			return
		end

		local normalized = vim.trim(tostring(input)):lower()
		if normalized == "y" or normalized == "yes" then
			close_ui()
		end
	end)
end

local function create_issue()
	local title = vim.trim(get_title())
	local desc = get_description()

	if title == "" then
		footer.notify("warn", "Title is required")
		return
	end

	local adf_description = nil
	if desc ~= "" then
		local markdown_content = state.preview_mode and state.original_markdown or desc
		adf_description = md_to_adf.to_adf(markdown_content)
	end

	local fields = vim.deepcopy(state.fields)
	fields.summary = title
	fields.description = adf_description

	local on_submit = state.on_submit
	if not on_submit then
		return
	end

	spinner_popup.start("Saving issue...")

	on_submit(fields, function(ok, err)
		vim.schedule(function()
			spinner_popup.stop()

			if ok then
				close_ui()
				return
			end

			if err and err ~= "" then
				footer.notify("error", err)
			end
		end)
	end)
end

local function toggle_preview()
	if not valid_buf(state.layout.desc_buf) or not valid_win(state.layout.desc_win) then
		return
	end

	if state.preview_mode then
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.layout.desc_buf })
		local lines = vim.split(state.original_markdown, "\n", { plain = true })
		vim.api.nvim_buf_set_lines(state.layout.desc_buf, 0, -1, false, lines)
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = state.layout.desc_buf })
		state.preview_mode = false
		footer.notify("info", "Editing markdown")
	else
		state.original_markdown = get_description()
		local adf = md_to_adf.to_adf(state.original_markdown)
		local formatted = utils.encode_pretty_json(adf)
		local lines = vim.split(formatted, "\n", { plain = true })
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.layout.desc_buf })
		vim.api.nvim_buf_set_lines(state.layout.desc_buf, 0, -1, false, lines)
		vim.api.nvim_set_option_value("modifiable", false, { buf = state.layout.desc_buf })
		vim.api.nvim_set_option_value("filetype", "json", { buf = state.layout.desc_buf })
		state.preview_mode = true
		footer.notify("info", "ADF preview (read-only)")
	end
end

local function show_assignee_picker()
	---@type AsyncPickerItem[]
	local initial_items = {}

	table.insert(initial_items, {
		id = "__unassign__",
		label = "Unassign",
		value = { account_id = nil, display_name = "Unassign" },
	})

	if state.assignees and state.assignees ~= "loading" then
		for _, user in ipairs(state.assignees) do
			table.insert(initial_items, {
				id = user.account_id or "",
				label = user.display_name or "",
				value = user,
			})
		end
	end

	async_picker.open({
		title = "Select Assignee",
		prompt = "Search users",
		initial_items = initial_items,
		fetch_on_open = not (state.assignees and state.assignees ~= "loading" and #state.assignees > 0),
		debounce_ms = 250,
		cache_ttl_ms = 60000,
		identifier = "jira_users:" .. (state.fields.project or ""),
		format_item = function(item)
			if item.id == "__unassign__" then
				return item.label
			end
			return string.format("%s %s", icons.entity("user"), item.label or "")
		end,
		fetch = function(ctx, done)
			users_api.get_assignable_users(
				{ project = state.fields.project, issue_key = state.fields.issue_key },
				ctx.query,
				function(users, err)
					if err then
						done(nil, err)
						return
					end
					local items = {}
					table.insert(items, {
						id = "__unassign__",
						label = "Unassign",
						value = { account_id = nil, display_name = "Unassign" },
					})
					for _, u in ipairs(users or {}) do
						table.insert(items, {
							id = u.account_id or "",
							label = u.display_name or "",
							value = u,
						})
					end
					done(items, nil)
				end
			)
		end,
		on_select = function(item)
			if item.id == "__unassign__" then
				state.fields.assignee = nil
			else
				state.fields.assignee = item.value
			end
			update_meta_buffer()
		end,
	})
end

local function show_reporter_picker()
	---@type AsyncPickerItem[]
	local initial_items = {}

	if state.assignees and state.assignees ~= "loading" then
		for _, user in ipairs(state.assignees) do
			table.insert(initial_items, {
				id = user.account_id or "",
				label = user.display_name or "",
				value = user,
			})
		end
	end

	async_picker.open({
		title = "Select Reporter",
		prompt = "Search users",
		initial_items = initial_items,
		fetch_on_open = not (state.assignees and state.assignees ~= "loading" and #state.assignees > 0),
		debounce_ms = 250,
		cache_ttl_ms = 60000,
		identifier = "jira_users:" .. (state.fields.project or ""),
		format_item = function(item)
			return string.format("%s %s", icons.entity("user"), item.label or "")
		end,
		fetch = function(ctx, done)
			users_api.get_assignable_users(
				{ project = state.fields.project, issue_key = state.fields.issue_key },
				ctx.query,
				function(users, err)
					if err then
						done(nil, err)
						return
					end
					local items = {}
					for _, u in ipairs(users or {}) do
						table.insert(items, {
							id = u.account_id or "",
							label = u.display_name or "",
							value = u,
						})
					end
					done(items, nil)
				end
			)
		end,
		on_select = function(item)
			state.fields.reporter = item.value
			update_meta_buffer()
		end,
	})
end

local function show_issue_type_picker()
	---@type AsyncPickerItem[]
	local initial_items = {}

	if state.issue_types and state.issue_types ~= "loading" then
		for _, issue_type in ipairs(state.issue_types) do
			if type(issue_type) == "table" then
				table.insert(initial_items, {
					id = tostring(issue_type.id or ""),
					label = tostring(issue_type.name or ""),
					value = issue_type,
				})
			end
		end
	end

	async_picker.open({
		title = "Select Issue Type",
		prompt = "Filter types",
		initial_items = initial_items,
		fetch_on_open = not (state.issue_types and state.issue_types ~= "loading" and #state.issue_types > 0),
		debounce_ms = 0,
		identifier = "jira_issue_types:" .. (state.fields.project or ""),
		format_item = function(item)
			return string.format("%s %s", icons.jira_icon(item.label), item.label)
		end,
		fetch = function(ctx, fetch_done)
			local function do_filter()
				if ctx.signal.cancelled then
					return
				end

				-- Still loading — poll until ready
				if state.issue_types == "loading" then
					vim.defer_fn(do_filter, 100)
					return
				end

				-- Rebuild initial_items if we had to wait
				if #initial_items == 0 and state.issue_types then
					for _, issue_type in ipairs(state.issue_types) do
						if type(issue_type) == "table" then
							table.insert(initial_items, {
								id = tostring(issue_type.id or ""),
								label = tostring(issue_type.name or ""),
								value = issue_type,
							})
						end
					end
				end

				local query = vim.trim(ctx.query):lower()
				if query == "" then
					fetch_done(initial_items, nil)
					return
				end
				local filtered = {}
				for _, item in ipairs(initial_items) do
					if item.label:lower():find(query, 1, true) then
						table.insert(filtered, item)
					end
				end
				fetch_done(filtered, nil)
			end

			do_filter()
		end,
		on_select = function(item)
			state.fields.issue_type = item.value
			update_meta_buffer()
		end,
	})
end

---@param on_submit fun(fields: IssueFields, done: fun(ok: boolean, err: string|nil))|nil
---@param opts IssueFields
function M.open(on_submit, opts)
	if valid_win(state.layout.container_win) then
		close_ui()
	end

	state.on_submit = on_submit
	state.fields = opts
	state.assignees = nil
	state.issue_types = nil

	issue_layout.open_layout(state)

	state.assignees = "loading"
	state.issue_types = "loading"
	state.spinner = spinner.create({
		on_tick = function()
			if state.assignees == "loading" or state.issue_types == "loading" then
				update_meta_buffer()
			end
		end,
	})
	state.spinner:start()

	update_meta_buffer(state.content_width)

	if state.fields.project ~= "" then
		state.assignees_handle = users_api.get_assignable_users(
			{ project = state.fields.project, issue_key = state.fields.issue_key },
			"",
			function(users, err)
				state.assignees_handle = nil

				if err then
					footer.notify("warn", "Failed to load assignees: " .. err, 2000)
					state.assignees = {}
				else
					state.assignees = users or {}
				end

				stop_loading_spinner_if_done()

				vim.schedule(function()
					update_meta_buffer()
				end)
			end
		)

		state.issue_types_handle = issues_api.get_create_meta(state.fields.project, function(issue_types, err)
			state.issue_types_handle = nil

			if err then
				footer.notify("warn", "Failed to load issue types: " .. err, 2000)
				state.issue_types = {}
				state.fields.issue_type = nil
			else
				local filtered_issue_types = {}
				for _, issue_type in ipairs(issue_types or {}) do
					-- TODO: Dont support subtask yet. need parent
					if not issue_type.subtask then
						table.insert(filtered_issue_types, issue_type)
					end
				end
				state.issue_types = filtered_issue_types
				if not state.fields.issue_type then
					state.fields.issue_type = pick_default_issue_type(state.issue_types)
				end
			end

			stop_loading_spinner_if_done()

			vim.schedule(function()
				update_meta_buffer()
			end)
		end)
	else
		state.assignees = {}
		state.issue_types = {}
		stop_loading_spinner_if_done()
		state.fields.issue_type = nil
		update_meta_buffer(state.content_width)
	end

	issue_layout.setup(state, {
		confirm_close = confirm_close,
		toggle_preview = toggle_preview,
		show_assignee_picker = show_assignee_picker,
		show_reporter_picker = show_reporter_picker,
		show_issue_type_picker = show_issue_type_picker,
		create_issue = create_issue,
	})

	vim.api.nvim_set_current_win(state.layout.title_win)

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(state.layout.container_win),
		once = true,
		callback = function()
			close_ui()
		end,
	})
end

return M
