local M = {}

local helper = require("atlas.pulls.ui.main.helper")

---@param pr PullRequest
---@param opts { padding_x?: integer, extra_chips?: PullsPanelChip[] }|nil
---@return string, table[]
function M.render(pr, opts)
	opts = opts or {}
	local chips = {
		{ label = tostring(pr.state or "UNKNOWN"), hl = helper.pr_state_hl(pr.state) },
	}

	for _, chip in ipairs(opts.extra_chips or {}) do
		table.insert(chips, chip)
	end

	local pad = math.max(0, opts.padding_x or 1)
	local line = string.rep(" ", pad)
	local spans = {}
	local col = pad

	for _, chip in ipairs(chips) do
		if chip ~= nil then
			local label = string.format(" %s ", chip.label)
			line = line .. label .. " "
			if chip.hl ~= nil then
				table.insert(spans, {
					start_col = col,
					end_col = col + #label,
					hl_group = chip.hl,
				})
			end
			col = col + #label + 1
		end
	end

	return line, spans
end

return M
