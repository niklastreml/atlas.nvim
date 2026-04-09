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

---@param workspace string
---@param repo_slug string
---@param existing_name string|nil
---@return string
local function repo_full_name(workspace, repo_slug, existing_name)
	local full_name = tostring(existing_name or "")
	if full_name ~= "" then
		return full_name
	end

	if workspace == "" or repo_slug == "" then
		return ""
	end

	return string.format("%s/%s", workspace, repo_slug)
end

---@param full_name string
---@return table|nil
local function repo_settings_for(full_name)
	if full_name == "" then
		return nil
	end

	return vim.tbl_get(config.options, "bitbucket", "repo_config", "settings", full_name)
end

---@param raw_repo table|nil
---@return table
local function normalize_selected_repo(raw_repo)
	local repo = raw_repo or {}
	local workspace = tostring(repo.workspace or "")
	local repo_slug = tostring(repo.slug or repo.repo_slug or repo.repo or "")
	local full_name = repo_full_name(workspace, repo_slug, repo.full_name or repo.name)
	local repo_settings = repo_settings_for(full_name)

	return {
		kind = "repo",
		workspace = workspace,
		slug = repo_slug,
		repo_slug = repo_slug,
		full_name = full_name,
		readme = repo.readme or (repo_settings and repo_settings.readme or nil),
	}
end

---@return table|nil
local function selected_repo()
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end

	if node.kind == "repo" then
		return normalize_selected_repo(node)
	end

	if type(node._repo) == "table" then
		return normalize_selected_repo(node._repo)
	end

	if node.kind == "pr" and type(node.pr) == "table" then
		return normalize_selected_repo({
			workspace = node.pr.workspace,
			repo_slug = node.pr.repo_slug or node.pr.repo,
			full_name = node.pr.repo_full_name,
		})
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
			index = 1,
		},
		{
			key = "/",
			desc = "Search repositories",
			callback = function()
				actions.open_pr_search_popup()
			end,
			index = 2,
		},
		{
			key = "o",
			desc = "Toggle repository panel",
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
			index = 3,
		},

		{
			key = "gx",
			desc = "Open PR in browser",
			callback = function()
				actions.browse_current_pr(selected_pr())
			end,
			index = 6,
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
			index = 8,
		},
		{
			key = "R",
			desc = "Refresh current Bitbucket view",
			callback = function()
				controller.refresh_current_view(function()
					navigation.focus_first_item()
				end)
			end,
			index = 9,
		},
		{
			key = "K",
			desc = "Show PR details popup",
			callback = function()
				controller.show_pr_details(buf)
			end,
			index = 10,
		},
		{
			key = "y",
			desc = "Copy PR id",
			callback = function()
				actions.copy_current_pr_id(selected_pr())
			end,
			index = 11,
		},
		{
			key = "Y",
			desc = "Copy PR URL",
			callback = function()
				actions.copy_current_pr_url(selected_pr())
			end,
			index = 12,
		},
	}
	local view_items = {}

	for _, view in ipairs(views or {}) do
		if view.key ~= nil and view.key ~= "" then
			local v = view
			table.insert(view_items, {
				key = v.key,
				desc = string.format("Switch to %s", v.name),
				hidden = true,
				callback = function()
					controller.switch_view(v, function()
						navigation.focus_first_item()
					end)
				end,
			})
		end
	end

	help.register("Bitbucket", items, {
		index = 220,
		buffer = buf,
	})

	help.register("Bitbucket", view_items, {
		index = 220,
		buffer = buf,
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
