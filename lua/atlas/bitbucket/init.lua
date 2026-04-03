local M = {}

local config = require("atlas.config")
local controller = require("atlas.bitbucket.ui.controller")
local actions = require("atlas.bitbucket.ui.actions")
local help = require("atlas.ui.popups.help")
local navigation = require("atlas.ui.navigation")
local layout = require("atlas.ui.layout")
local footer = require("atlas.ui.components.footer")

---@return BitbucketPR|nil
local function selected_pr()
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

---@return table|nil
local function selected_repo()
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end

	if node.kind == "repo" then
		return node
	end

	if type(node._repo) == "table" then
		return node._repo
	end

	if node.kind == "pr" and type(node.pr) == "table" then
		local r = node.pr.repo or {}
		local workspace = tostring(r.workspace or "")
		local repo_slug = tostring(r.repo or "")
		local full_name = tostring(r.name or "")
		if full_name == "" and workspace ~= "" and repo_slug ~= "" then
			full_name = string.format("%s/%s", workspace, repo_slug)
		end

		return {
			kind = "repo",
			workspace = workspace,
			repo_slug = repo_slug,
			full_name = full_name,
			readme = "README.md", --TODO: Use config
		}
	end

	return nil
end

---@param buf integer
---@param views BitbucketViewConfig[]
local function register_dynamic_keys(buf, views)
	local items = {
		{
			key = "A",
			desc = "Open PR actions",
			callback = function()
				actions.open_pr_actions_popup(selected_pr())
			end,
		},
		{
			key = "gx",
			desc = "Open PR in browser",
			callback = function()
				actions.browse_current_pr(selected_pr())
			end,
		},
		{
			key = "y",
			desc = "Copy PR id",
			callback = function()
				actions.copy_current_pr_id(selected_pr())
			end,
		},
		{
			key = "Y",
			desc = "Copy PR URL",
			callback = function()
				actions.copy_current_pr_url(selected_pr())
			end,
		},
		{
			key = "R",
			desc = "Refresh current Bitbucket view",
			callback = function()
				controller.refresh_current_view(function()
					navigation.focus_first_item()
				end)
			end,
		},
		{
			key = "r",
			desc = "Refetch selected PR",
			callback = function()
				local panel = require("atlas.ui.panel")
				local panel_state = require("atlas.ui.panel.state")
				if panel.is_open() then
					local selected = panel_state.selected_item
					if type(selected) == "table" and selected.kind == "repo" then
						require("atlas.bitbucket.panel.tabs.repo.overview.controller").refresh()
						return
					end
				end

				actions.refresh_pr(selected_pr())
			end,
		},
		{
			key = "o",
			desc = "Open repository panel",
			callback = function()
				local repo = selected_repo()
				if repo == nil then
					footer.notify("warn", "No repository selected")
					return
				end

				local panel = require("atlas.ui.panel")
				local panel_state = require("atlas.ui.panel.state")
				if panel.is_open() then
					local selected = panel_state.selected_item
					if type(selected) == "table" and selected.kind == "repo" then
						panel.close()
						return
					end
				end
				panel.show("bitbucket", repo)
			end,
		},
		{
			key = "/",
			desc = "Search repositories",
			callback = function()
				actions.open_pr_search_popup()
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
					controller.switch_view(v, function()
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
