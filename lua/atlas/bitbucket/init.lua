local M = {}

local config = require("atlas.config")
local ui_state = require("atlas.ui.state")
local renderer = require("atlas.ui.renderer")
local state = require("atlas.bitbucket.state")
local help = require("atlas.ui.popups.help")

---@param direction "up"|"down"
local function navigate_to_next_pr(direction)
	local win = ui_state.win_id
	local buf = ui_state.buf_id
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local line_map = ui_state.line_map or {}
	local current_line = vim.api.nvim_win_get_cursor(win)[1]
	local last_line = vim.api.nvim_buf_line_count(buf)
	local step = direction == "up" and -1 or 1
	local stop = direction == "up" and 1 or last_line

	for line = current_line + step, stop, step do
		local node = line_map[line]
		if node and node.kind == "pr" then
			vim.api.nvim_win_set_cursor(win, { line, 0 })
			return
		end
	end
end

---@param buf integer
---@param views BitbucketViewConfig[]
local function register_dynamic_keys(buf, views)
	local items = {
		{
			key = "j",
			desc = "Jump to next PR",
			callback = function()
				navigate_to_next_pr("down")
			end,
		},
		{
			key = "k",
			desc = "Jump to previous PR",
			callback = function()
				navigate_to_next_pr("up")
			end,
		},
		{
			key = "r",
			desc = "Refresh current Bitbucket view",
			callback = function()
				renderer.render("bitbucket", { force_refresh = true })
			end,
		},
	}

	for _, view in ipairs(views or {}) do
		if view.key ~= nil and view.key ~= "" then
			local v = view
			table.insert(items, {
				key = v.key,
				desc = string.format("Switch to %s", v.name),
				callback = function()
					state.active_view = v
					renderer.render("bitbucket")
				end,
			})
		end
	end

	for _, item in ipairs(items) do
		help.unregister_key("Bitbucket", item.key, { buf = buf })
	end

	help.register_keys("Bitbucket", items, {
		index = 220,
		add_to_registry = false,
		buf = buf,
	})
end

function M.setup() end
local footer = require("atlas.ui.components.footer")

footer.clear_items("bitbucket")
---TODO: add better options. This is just for testing.
footer.register_item("bitbucket", { text = "PRs", hl_group = "AtlasFooterText" })
footer.register_item("bitbucket", { text = "|", hl_group = "AtlasFooterText" })
footer.register_item("bitbucket", { text = "r refresh", hl_group = "AtlasFooterText" })

local target_buf = ui_state.buf_id
if target_buf == nil or not vim.api.nvim_buf_is_valid(target_buf) then
	return
end

local views = (config.options.bitbucket and config.options.bitbucket.views) or {}
register_dynamic_keys(target_buf, views)

return M
