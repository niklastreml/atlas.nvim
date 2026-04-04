local M = {}

local footer = require("atlas.ui.components.footer")
local md_to_adf = require("atlas.jira.converted.markdown")
local icons = require("atlas.ui.icons")
local helper = require("atlas.jira.ui.helper")
local jira_state = require("atlas.jira.state")
local users_api = require("atlas.jira.api.users")
local issues_api = require("atlas.jira.api.issues")
local spinner = require("atlas.ui.components.spinner")
local spinner_popup = require("atlas.ui.popups.spinner")
local table_tree_v2 = require("atlas.ui.components.table_tree_v2")

---@class CreateIssueFields
---@field summary string
---@field description table|nil
---@field assignee JiraUser|nil
---@field project string
---@field issue_type JiraCreateIssueType|nil

---@class JiraCreateIssueType
---@field id string
---@field name string
---@field description string
---@field subtask boolean

---@class CreateIssueState
---@field title_buf integer|nil
---@field title_win integer|nil
---@field meta_buf integer|nil
---@field meta_win integer|nil
---@field desc_buf integer|nil
---@field desc_win integer|nil
---@field container_win integer|nil
---@field container_buf integer|nil
---@field preview_mode boolean
---@field original_markdown string
---@field assignees JiraUser[]|nil
---@field assignees_loading boolean
---@field selected_assignee JiraUser|nil
---@field issue_types JiraCreateIssueType[]|nil
---@field issue_types_loading boolean
---@field selected_issue_type JiraCreateIssueType|nil
---@field spinner SpinnerInstance|nil
---@field assignees_handle { job_id: integer, cancel: fun() }|nil
---@field issue_types_handle { job_id: integer, cancel: fun() }|nil
---@field submitting boolean
---@field content_width integer
---@field on_submit fun(fields: CreateIssueFields, done: fun(ok: boolean, err: string|nil))|nil
---@field project string|nil

local state = {
	title_buf = nil,
	title_win = nil,
	meta_buf = nil,
	meta_win = nil,
	desc_buf = nil,
	desc_win = nil,
	container_win = nil,
	container_buf = nil,
	preview_mode = false,
	original_markdown = "",
	assignees = nil,
	assignees_loading = false,
	selected_assignee = nil,
	issue_types = nil,
	issue_types_loading = false,
	selected_issue_type = nil,
	spinner = nil,
	assignees_handle = nil,
	issue_types_handle = nil,
	submitting = false,
	content_width = 0,
	on_submit = nil,
	project = nil,
}

local ns = vim.api.nvim_create_namespace("atlas.jira.create_issue")

local function valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

---@param opts { buftype: string, modifiable: boolean, name: string, filetype?: string }
---@return integer
local function create_ui_buffer(opts)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", opts.buftype, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	if opts.filetype then
		vim.api.nvim_set_option_value("filetype", opts.filetype, { buf = buf })
	end
	vim.api.nvim_set_option_value("modifiable", opts.modifiable, { buf = buf })
	pcall(vim.api.nvim_buf_set_name, buf, opts.name)
	return buf
end

local function get_title()
	if not valid_buf(state.title_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.title_buf, 0, -1, false)
	return table.concat(lines, " ")
end

local function get_description()
	if not valid_buf(state.desc_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.desc_buf, 0, -1, false)
	return table.concat(lines, "\n")
end

local function is_modified()
	local title = vim.trim(get_title())
	local desc = vim.trim(get_description())
	return title ~= "" or desc ~= ""
end

local function get_reporter_name()
	local user = jira_state.current_user
	if user and user.display_name then
		return user.display_name
	end
	return "Unknown"
end

local function get_assignee_display()
	if state.assignees_loading then
		local frame = state.spinner and state.spinner:current_frame() or "⠋"
		return frame .. " Loading...", true
	end
	if state.selected_assignee then
		return icons.entity("user") .. " " .. state.selected_assignee.display_name, false
	end
	return icons.entity("user") .. " Unassigned", false
end

local function get_issue_type_display()
	if state.issue_types_loading then
		local frame = state.spinner and state.spinner:current_frame() or "⠋"
		return frame .. " Loading...", true
	end

	if state.selected_issue_type and state.selected_issue_type.name ~= "" then
		local name = state.selected_issue_type.name
		return string.format("%s %s", icons.jira_icon(name), name), false
	end

	return "None", false
end

local function pick_default_issue_type(issue_types)
	if type(issue_types) ~= "table" then
		return nil
	end

	for _, issue_type in ipairs(issue_types) do
		if type(issue_type) == "table" and tostring(issue_type.name or ""):lower() == "task" then
			return issue_type
		end
	end

	return issue_types[1]
end

local function render_meta_lines(width)
	local user_icon = icons.entity("user")
	local project_icon = icons.entity("project")
	local assignee_text, is_loading = get_assignee_display()
	local issue_type_text, issue_type_loading = get_issue_type_display()
	local reporter_name = get_reporter_name()
	local project_name = state.project or "Unknown"

	local assignee_hl
	if is_loading then
		assignee_hl = "AtlasTextMuted"
	elseif state.selected_assignee then
		assignee_hl = helper.person_hl(state.selected_assignee.display_name)
	else
		assignee_hl = helper.person_hl(nil)
	end

	local rows = {
		{
			k1 = "Assignee:",
			v1 = assignee_text,
			v1_hl = assignee_hl,
			k2 = "Reporter:",
			v2 = string.format("%s %s", user_icon, reporter_name),
			v2_hl = helper.person_hl(reporter_name),
		},
		{
			k1 = "Project:",
			v1 = string.format("%s %s", project_icon, project_name),
			v1_hl = "AtlasProjectKey",
			k2 = "Type:",
			v2 = issue_type_text,
			v2_hl = issue_type_loading and "AtlasTextMuted" or helper.issue_type_hl(state.selected_issue_type and state.selected_issue_type.name or nil),
		},
	}

	local lines, _, spans = table_tree_v2.render({
		columns = {
			{ key = "k1", name = "", can_grow = false },
			{ key = "v1", name = "", can_grow = true },
			{ key = "k2", name = "", can_grow = false },
			{ key = "v2", name = "", can_grow = true, grow_last = true },
		},
		rows = rows,
		width = width,
		margin = 0,
		show_header = false,
		column_gap = 2,
		fill = true,
		cell_hl = function(row, col)
			if col.key == "k1" or col.key == "k2" then
				local label = col.key == "k1" and row.k1 or row.k2
				if label == "" then
					return nil
				end
				return {
					{ start_col = 0, end_col = #label, hl_group = "AtlasTextMuted" },
				}
			end

			if col.key == "v1" then
				return {
					{ start_col = 0, end_col = #row.v1, hl_group = row.v1_hl },
				}
			end

			if col.key == "v2" and row.v2 ~= "" then
				return {
					{ start_col = 0, end_col = #row.v2, hl_group = row.v2_hl },
				}
			end

			return nil
		end,
	})

	return lines, spans
end

local function update_meta_buffer(width)
	if not valid_buf(state.meta_buf) then
		return
	end

	local w = width or state.content_width
	local lines, spans = render_meta_lines(w)
	vim.api.nvim_set_option_value("modifiable", true, { buf = state.meta_buf })
	vim.api.nvim_buf_set_lines(state.meta_buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.meta_buf })

	vim.api.nvim_buf_clear_namespace(state.meta_buf, ns, 0, -1)
	for _, span in ipairs(spans) do
		vim.api.nvim_buf_set_extmark(state.meta_buf, ns, span.line, span.start_col, {
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

local function stop_loading_spinner_if_done()
	if not state.spinner then
		return
	end

	if state.assignees_loading or state.issue_types_loading then
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

	if valid_win(state.desc_win) then
		vim.api.nvim_win_close(state.desc_win, true)
	end
	if valid_win(state.meta_win) then
		vim.api.nvim_win_close(state.meta_win, true)
	end
	if valid_win(state.title_win) then
		vim.api.nvim_win_close(state.title_win, true)
	end
	if valid_win(state.container_win) then
		vim.api.nvim_win_close(state.container_win, true)
	end

	if valid_buf(state.desc_buf) then
		vim.api.nvim_buf_delete(state.desc_buf, { force = true })
	end
	if valid_buf(state.meta_buf) then
		vim.api.nvim_buf_delete(state.meta_buf, { force = true })
	end
	if valid_buf(state.title_buf) then
		vim.api.nvim_buf_delete(state.title_buf, { force = true })
	end
	if valid_buf(state.container_buf) then
		vim.api.nvim_buf_delete(state.container_buf, { force = true })
	end

	state.title_buf = nil
	state.title_win = nil
	state.meta_buf = nil
	state.meta_win = nil
	state.desc_buf = nil
	state.desc_win = nil
	state.container_win = nil
	state.container_buf = nil
	state.preview_mode = false
	state.original_markdown = ""
	state.assignees = nil
	state.assignees_loading = false
	state.selected_assignee = nil
	state.issue_types = nil
	state.issue_types_loading = false
	state.selected_issue_type = nil
	state.assignees_handle = nil
	state.issue_types_handle = nil
	state.submitting = false
	state.content_width = 0
	state.on_submit = nil
end

local function confirm_close()
	if state.submitting then
		footer.notify("info", "Issue creation in progress...")
		return
	end

	if not is_modified() then
		close_ui()
		return
	end

	vim.ui.select({ "Yes", "No" }, {
		prompt = "Discard changes?",
	}, function(choice)
		if choice == "Yes" then
			close_ui()
		end
	end)
end

local function create_issue()
	if state.submitting then
		return
	end

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

	local fields = {
		summary = title,
		description = adf_description,
		assignee = state.selected_assignee,
		project = state.project,
		issue_type = state.selected_issue_type,
	}

	local on_submit = state.on_submit
	if not on_submit then
		return
	end

	state.submitting = true
	spinner_popup.start("Creating issue...")

	on_submit(fields, function(ok, err)
		vim.schedule(function()
			state.submitting = false
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
	if not valid_buf(state.desc_buf) or not valid_win(state.desc_win) then
		return
	end

	if state.preview_mode then
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.desc_buf })
		local lines = vim.split(state.original_markdown, "\n", { plain = true })
		vim.api.nvim_buf_set_lines(state.desc_buf, 0, -1, false, lines)
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = state.desc_buf })
		state.preview_mode = false
		footer.notify("info", "Editing markdown")
	else
		state.original_markdown = get_description()
		local adf = md_to_adf.to_adf(state.original_markdown)
		local json_str = vim.fn.json_encode(adf)
		local ok, formatted = pcall(function()
			return vim.fn.system({ "jq", "." }, json_str)
		end)
		if not ok or vim.v.shell_error ~= 0 then
			formatted = json_str
		end
		local lines = vim.split(formatted, "\n", { plain = true })
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.desc_buf })
		vim.api.nvim_buf_set_lines(state.desc_buf, 0, -1, false, lines)
		vim.api.nvim_set_option_value("modifiable", false, { buf = state.desc_buf })
		vim.api.nvim_set_option_value("filetype", "json", { buf = state.desc_buf })
		state.preview_mode = true
		footer.notify("info", "ADF preview (read-only)")
	end
end

local function focus_description()
	if valid_win(state.desc_win) then
		vim.api.nvim_set_current_win(state.desc_win)
	end
end

local function focus_title()
	if valid_win(state.title_win) then
		vim.api.nvim_set_current_win(state.title_win)
	end
end

local function show_assignee_picker()
	if state.assignees_loading then
		footer.notify("info", "Still loading assignees...")
		return
	end

	if not state.assignees or #state.assignees == 0 then
		footer.notify("warn", "No assignees available")
		return
	end

	-- Build options: Unassign first if currently assigned, then all users
	local options = {}
	if state.selected_assignee then
		table.insert(options, { account_id = nil, display_name = "Unassign" })
	end
	for _, user in ipairs(state.assignees) do
		table.insert(options, user)
	end

	vim.ui.select(options, {
		prompt = "Select Assignee",
		kind = "atlas_jira_assignees",
		format_item = function(item)
			return tostring((item and item.display_name) or "")
		end,
	}, function(selected)
		if selected == nil then
			return
		end

		if selected.account_id == nil then
			state.selected_assignee = nil
		else
			state.selected_assignee = selected
		end
		update_meta_buffer()
	end)
end

local function show_issue_type_picker()
	if state.issue_types_loading then
		footer.notify("info", "Still loading issue types...")
		return
	end

	if not state.issue_types or #state.issue_types == 0 then
		footer.notify("warn", "No issue types available")
		return
	end

	vim.ui.select(state.issue_types, {
		prompt = "Select Issue Type",
		kind = "atlas_jira_issue_types",
		format_item = function(item)
			if type(item) ~= "table" then
				return ""
			end
			return string.format("%s %s", icons.jira_icon(item.name), tostring(item.name or ""))
		end,
	}, function(selected)
		if selected == nil then
			return
		end

		state.selected_issue_type = selected
		update_meta_buffer()
	end)
end

local function setup_keymaps()
	local keymap_opts = { silent = true, nowait = true }

	if valid_buf(state.title_buf) then
		vim.keymap.set("n", "q", confirm_close, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
		vim.keymap.set("n", "<CR>", focus_description, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
		vim.keymap.set("n", "<Tab>", focus_description, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
		vim.keymap.set("n", "ga", show_assignee_picker, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
		vim.keymap.set("n", "gt", show_issue_type_picker, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
		vim.keymap.set("i", "<CR>", function()
			vim.cmd("stopinsert")
			focus_description()
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
		vim.keymap.set("i", "<Tab>", function()
			vim.cmd("stopinsert")
			focus_description()
		end, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
		vim.keymap.set("n", "m", toggle_preview, vim.tbl_extend("force", keymap_opts, { buffer = state.title_buf }))
	end

	if valid_buf(state.meta_buf) then
		vim.keymap.set("n", "q", confirm_close, vim.tbl_extend("force", keymap_opts, { buffer = state.meta_buf }))
		vim.keymap.set("n", "<CR>", show_assignee_picker, vim.tbl_extend("force", keymap_opts, { buffer = state.meta_buf }))
		vim.keymap.set("n", "<Tab>", focus_description, vim.tbl_extend("force", keymap_opts, { buffer = state.meta_buf }))
		vim.keymap.set("n", "<S-Tab>", focus_title, vim.tbl_extend("force", keymap_opts, { buffer = state.meta_buf }))
		vim.keymap.set("n", "m", toggle_preview, vim.tbl_extend("force", keymap_opts, { buffer = state.meta_buf }))
	end

	if valid_buf(state.desc_buf) then
		vim.keymap.set("n", "q", confirm_close, vim.tbl_extend("force", keymap_opts, { buffer = state.desc_buf }))
		vim.keymap.set("n", "<Tab>", focus_title, vim.tbl_extend("force", keymap_opts, { buffer = state.desc_buf }))
		vim.keymap.set("n", "<S-Tab>", focus_title, vim.tbl_extend("force", keymap_opts, { buffer = state.desc_buf }))
		vim.keymap.set("n", "ga", show_assignee_picker, vim.tbl_extend("force", keymap_opts, { buffer = state.desc_buf }))
		vim.keymap.set("n", "gt", show_issue_type_picker, vim.tbl_extend("force", keymap_opts, { buffer = state.desc_buf }))
		vim.keymap.set("n", "m", toggle_preview, vim.tbl_extend("force", keymap_opts, { buffer = state.desc_buf }))
	end
end

local function setup_autocmds()
	local write_bufs = { state.title_buf, state.desc_buf }
	for _, buf in ipairs(write_bufs) do
		if valid_buf(buf) then
			vim.api.nvim_create_autocmd("BufWriteCmd", {
				buffer = buf,
				callback = function()
					create_issue()
				end,
			})
		end
	end

	local all_bufs = { state.title_buf, state.meta_buf, state.desc_buf, state.container_buf }
	for _, buf in ipairs(all_bufs) do
		if valid_buf(buf) then
			vim.api.nvim_create_autocmd("QuitPre", {
				buffer = buf,
				callback = function()
					vim.schedule(function()
						confirm_close()
					end)
					-- Return true to prevent the quit
					return true
				end,
			})
		end
	end
end

---@param project string
---@param on_submit fun(fields: CreateIssueFields, done: fun(ok: boolean, err: string|nil))|nil
function M.open(project, on_submit)
	if valid_win(state.container_win) then
		close_ui()
	end

	state.on_submit = on_submit
	state.project = project
	state.selected_issue_type = nil
	state.issue_types = nil

	local width = math.max(math.floor(vim.o.columns * 0.6), 60)
	local height = math.max(math.floor(vim.o.lines * 0.6), 20)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local inner_width = width - 2

	state.container_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.container_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.container_buf })

	state.container_win = vim.api.nvim_open_win(state.container_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		focusable = false,
		mouse = false,
		title = " Create Issue ",
		title_pos = "center",
		footer = " q/:q close | :w create | ga assignee | gt issue type | m toggle ADF preview ",
		footer_pos = "center",
	})
	vim.api.nvim_set_option_value("wrap", false, { win = state.container_win })

	state.title_buf = create_ui_buffer({
		buftype = "acwrite",
		modifiable = true,
		name = "atlas://jira/create/title",
	})

	state.meta_buf = create_ui_buffer({
		buftype = "nofile",
		modifiable = false,
		name = "atlas://jira/create/meta",
	})

	state.desc_buf = create_ui_buffer({
		buftype = "acwrite",
		modifiable = true,
		name = "atlas://jira/create/description.md",
		filetype = "markdown",
	})

	local content_width = inner_width - 4
	local content_col = 2
	state.content_width = content_width

	local separator_line = string.rep("─", inner_width)
	vim.api.nvim_buf_set_lines(state.container_buf, 0, -1, false, vim.fn["repeat"]({ "" }, height))

	state.title_win = vim.api.nvim_open_win(state.title_buf, true, {
		relative = "win",
		win = state.container_win,
		width = content_width,
		height = 2,
		row = 0,
		col = content_col,
		style = "minimal",
		border = "none",
	})
	vim.api.nvim_set_option_value("number", false, { win = state.title_win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = state.title_win })
	vim.api.nvim_set_option_value("cursorline", false, { win = state.title_win })
	vim.api.nvim_set_option_value("wrap", false, { win = state.title_win })
	vim.api.nvim_set_option_value("winbar", "Summary", { win = state.title_win })

	state.meta_win = vim.api.nvim_open_win(state.meta_buf, false, {
		relative = "win",
		win = state.container_win,
		width = content_width,
		height = 2,
		row = 4,
		col = content_col,
		style = "minimal",
		border = "none",
		focusable = false,
	})
	vim.api.nvim_set_option_value("number", false, { win = state.meta_win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = state.meta_win })
	vim.api.nvim_set_option_value("cursorline", false, { win = state.meta_win })
	vim.api.nvim_set_option_value("wrap", false, { win = state.meta_win })

	state.desc_win = vim.api.nvim_open_win(state.desc_buf, false, {
		relative = "win",
		win = state.container_win,
		width = content_width,
		height = math.max(1, height - 8),
		row = 7,
		col = content_col,
		style = "minimal",
		border = "none",
	})
	vim.api.nvim_set_option_value("number", false, { win = state.desc_win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = state.desc_win })
	vim.api.nvim_set_option_value("cursorline", false, { win = state.desc_win })
	vim.api.nvim_set_option_value("wrap", true, { win = state.desc_win })
	vim.api.nvim_set_option_value("winbar", "Description", { win = state.desc_win })

	vim.api.nvim_buf_set_lines(state.container_buf, 3, 4, false, { separator_line })
	vim.api.nvim_buf_set_lines(state.container_buf, 6, 7, false, { separator_line })

	state.assignees_loading = true
	state.issue_types_loading = true
	state.spinner = spinner.create({
		on_tick = function()
			if state.assignees_loading or state.issue_types_loading then
				update_meta_buffer()
			end
		end,
	})
	state.spinner:start()

	update_meta_buffer(content_width)

	if state.project and state.project ~= "" then
		state.assignees_handle = users_api.get_assignable_users_for_project(state.project, "", function(users, err)
			state.assignees_handle = nil
			state.assignees_loading = false
			stop_loading_spinner_if_done()

			if err then
				footer.notify("warn", "Failed to load assignees: " .. err, 2000)
				state.assignees = {}
			else
				state.assignees = users or {}
			end

			vim.schedule(function()
				update_meta_buffer()
			end)
		end)

		state.issue_types_handle = issues_api.get_create_meta(state.project, function(issue_types, err)
			state.issue_types_handle = nil
			state.issue_types_loading = false
			stop_loading_spinner_if_done()

			if err then
				footer.notify("warn", "Failed to load issue types: " .. err, 2000)
				state.issue_types = {}
				state.selected_issue_type = nil
			else
				local filtered_issue_types = {}
				for _, issue_type in ipairs(issue_types or {}) do
					-- TODO: Dont support subtask yet. need parent
					if not issue_type.subtask then
						table.insert(filtered_issue_types, issue_type)
					end
				end
				state.issue_types = filtered_issue_types
				state.selected_issue_type = pick_default_issue_type(state.issue_types)
			end

			vim.schedule(function()
				update_meta_buffer()
			end)
		end)
	else
		state.assignees_loading = false
		state.issue_types_loading = false
		stop_loading_spinner_if_done()
		state.assignees = {}
		state.issue_types = {}
		state.selected_issue_type = nil
		update_meta_buffer(content_width)
	end

	setup_keymaps()
	setup_autocmds()

	vim.api.nvim_set_current_win(state.title_win)
	vim.cmd("startinsert")

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(state.container_win),
		once = true,
		callback = function()
			close_ui()
		end,
	})
end

return M
