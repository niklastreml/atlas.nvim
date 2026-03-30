local M = {}

local config = require("atlas.config")
local actions = require("atlas.bitbucket.ui.main.controller")
local service = require("atlas.bitbucket.api.service")
local help = require("atlas.ui.popups.help")
local navigation = require("atlas.ui.navigation")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")

---@return BitbucketPR|nil
local function current_pr_item()
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end
	if node.kind == "pr" and type(node.pr) == "table" then
		return node.pr
	end
	if node.kind == "pr" then
		return node
	end
	return nil
end

---@param pr BitbucketPR|nil
---@return string
local function pr_browser_url(pr)
	if type(pr) ~= "table" then
		return ""
	end

	local raw_html = (((pr._raw or {}).links or {}).html or {}).href
	if type(raw_html) == "string" and raw_html ~= "" then
		return raw_html
	end

	return tostring((pr.links or {}).self or "")
end

---@param value string
---@param label string
local function copy_value(value, label)
	if value == "" then
		footer.notify("warn", "Bitbucket: Nothing to copy")
		return
	end

	vim.fn.setreg("+", value)
	vim.fn.setreg('"', value)
	footer.notify("info", string.format("Bitbucket: Copied %s", label))
end

---@param text any
---@return string
local function footer_text(text)
	return tostring(text or ""):gsub("[\r\n]+", " | ")
end

local function open_pr_actions_popup()
	local pr = current_pr_item()
	if pr == nil then
		footer.notify("warn", "Bitbucket: No PR selected")
		return
	end

	local options = {
		{ id = "merge", label = "Merge" },
		{ id = "request_changes", label = "Request changes" },
		{ id = "approve", label = "Approve" },
	}

	vim.ui.select(options, {
		prompt = string.format("PR #%s action", tostring(pr.id or "")),
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice == nil then
			return
		end
		footer.notify("info", string.format("Bitbucket: %s for PR #%s", choice.label, tostring(pr.id or "")))

		local function on_done(_, err)
			if err ~= nil then
				footer.notify("error", string.format("Bitbucket: %s failed: %s", choice.label, footer_text(err)))
				return
			end

			footer.notify("success", string.format("Bitbucket: %s succeeded", choice.label))
			actions.refresh_current_view(function()
				navigation.focus_first_item()
			end)
		end

		if choice.id == "merge" then
			local merge_url = tostring((pr.links or {}).merge or "")
			if merge_url == "" then
				merge_url = tostring((((pr._raw or {}).links or {}).merge or {}).href or "")
			end
			service.merge_pullrequest(merge_url, {
				close_source_branch = true,
				merge_strategy = "merge_commit",
			}, on_done)
			return
		end

		if choice.id == "approve" then
			service.approve_pullrequest(tostring((pr.links or {}).approve or ""), on_done)
			return
		end

		if choice.id == "request_changes" then
			service.request_changes_pullrequest(tostring((pr.links or {}).request_changes or ""), on_done)
		end
	end)
end

---@param buf integer
---@param views BitbucketViewConfig[]
local function register_dynamic_keys(buf, views)
	local items = {
		{
			key = "a",
			desc = "Open PR actions",
			callback = function()
				open_pr_actions_popup()
			end,
		},
		{
			key = "gx",
			desc = "Open PR in browser",
			callback = function()
				local pr = current_pr_item()
				local url = pr_browser_url(pr)
				if url == "" then
					footer.notify("warn", "Bitbucket: No PR selected")
					return
				end
				vim.ui.open(url)
			end,
		},
		{
			key = "y",
			desc = "Copy PR id",
			callback = function()
				local pr = current_pr_item()
				local id = pr and tostring(pr.id or "") or ""
				copy_value(id, "PR id")
			end,
		},
		{
			key = "Y",
			desc = "Copy PR URL",
			callback = function()
				local pr = current_pr_item()
				copy_value(pr_browser_url(pr), "PR URL")
			end,
		},
		{
			key = "g",
			desc = "Go to first PR",
			callback = function()
				navigation.focus_first_item()
			end,
		},
		{
			key = "G",
			desc = "Go to last PR",
			callback = function()
				navigation.focus_last_item()
			end,
		},
		{
			key = "R",
			desc = "Refresh current Bitbucket view",
			callback = function()
				actions.refresh_current_view(function()
					navigation.focus_first_item()
				end)
			end,
		},
	}
	local view_items = {}

	for _, view in ipairs(views or {}) do
		if view.key ~= nil and view.key ~= "" then
			local v = view
			table.insert(view_items, {
				key = v.key,
				desc = string.format("Switch to %s", v.name),
				callback = function()
					actions.switch_view(v, function()
						navigation.focus_first_item()
					end)
				end,
			})
		end
	end

	for _, item in ipairs(items) do
		help.unregister_key("Bitbucket", item.key, { buf = buf })
	end
	for _, item in ipairs(view_items) do
		help.unregister_key("Bitbucket", item.key, { buf = buf })
	end

	help.register_keys("Bitbucket", items, {
		index = 220,
		buf = buf,
	})

	help.register_keys("Bitbucket", view_items, {
		index = 220,
		buf = buf,
		add_to_registry = false,
	})
end

function M.setup()
	footer.clear_items()

	local target_buf = layout.buf_id("main")
	if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
	register_dynamic_keys(target_buf, views)
end

return M
