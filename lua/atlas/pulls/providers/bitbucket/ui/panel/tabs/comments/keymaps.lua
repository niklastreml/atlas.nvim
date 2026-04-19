local M = {}

local help = require("atlas.ui.popups.help")

---@param buf integer
---@param cursor_entry fun(): table|nil
---@param done fun()
function M.setup(buf, cursor_entry, done)
	local tab = require("atlas.pulls.providers.bitbucket.ui.panel.tabs.comments")
	local panel_state = require("atlas.pulls.ui.panel.pr.state")

	local items = {
		{
			key = { "a", "i" },
			desc = "Add comment",
			opts = { nowait = true, silent = true },
			callback = function()
				local pr = panel_state.current_pr
				if pr then
					tab.add_comment(pr, done)
				end
			end,
		},
		{
			key = "T",
			desc = "Add task",
			opts = { nowait = true, silent = true },
			callback = function()
				local pr = panel_state.current_pr
				if pr then
					tab.add_task(pr, done)
				end
			end,
		},
		{
			key = "c",
			desc = "Reply to comment",
			opts = { nowait = true, silent = true },
			callback = function()
				local pr = panel_state.current_pr
				local entry = cursor_entry()
				if pr and entry then
					tab.reply_comment(pr, entry, done)
				end
			end,
		},
		{
			key = "t",
			desc = "Toggle task resolved",
			opts = { nowait = true, silent = true },
			callback = function()
				local pr = panel_state.current_pr
				local entry = cursor_entry()
				if pr and entry then
					tab.toggle_task(pr, entry, done)
				end
			end,
		},
		{
			key = "e",
			desc = "Edit comment/task",
			opts = { nowait = true, silent = true },
			callback = function()
				local pr = panel_state.current_pr
				local entry = cursor_entry()
				if pr and entry then
					tab.edit_comment(pr, entry, done)
				end
			end,
		},
		{
			key = "d",
			desc = "Delete comment/task",
			opts = { nowait = true, silent = true },
			callback = function()
				local pr = panel_state.current_pr
				local entry = cursor_entry()
				if pr and entry then
					tab.delete_comment(pr, entry, done)
				end
			end,
		},
	}

	help.register("Panel", items, { index = 212, buffer = buf })
end

---@param buf integer
function M.teardown(buf)
	help.remove("Panel", {
		{ key = "a" },
		{ key = "T" },
		{ key = "i" },
		{ key = "c" },
		{ key = "t" },
		{ key = "e" },
		{ key = "d" },
	}, { buffer = buf })
end

return M
