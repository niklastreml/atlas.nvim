local M = {}

---@param state string|nil
---@return string|nil
local function state_hl(state)
	local key = string.upper(tostring(state or ""))
	if key == "OPEN" then
		return "AtlasBitbucketPROpen"
	end
	if key == "MERGED" then
		return "AtlasBitbucketPRMerged"
	end
	if key == "DECLINED" then
		return "AtlasBitbucketPRDeclined"
	end
	return nil
end

---@param pr table
---@return string line
---@return table[] spans
function M.render(pr)
	local chips = {
		{ label = tostring(pr.state or "UNKNOWN"), hl = state_hl(pr.state) },
		pr.is_draft and { label = "DRAFT", hl = "AtlasBitbucketPRDraft" } or nil,
	}

	local line = ""
	local spans = {}
	local col = 0

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
