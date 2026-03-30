local M = {}
local utils = require("atlas.utils")

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
	local commit_hash = tostring(pr.source_commit_hash or "")
	if commit_hash == "" then
		commit_hash = "-"
	end

	local chips = {
		{ label = tostring(pr.state or "UNKNOWN"), hl = state_hl(pr.state) },
		{ label = commit_hash, hl = "AtlasTabInactive" },
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

---@param repo table
---@return string line
---@return table[] spans
function M.render_repo(repo)
	if type(repo) ~= "table" then
		return "", {}
	end

	local chips = {
		{ label = string.format("%s", utils.human_size(repo.size)), hl = "AtlasTabInactive" },
		{ label = tostring((repo.mainbranch or {}).name or "-"), hl = "AtlasBitbucketPRMerged" },
		repo.is_private == true and { label = "private", hl = "AtlasBitbucketPRDraft" }
			or { label = "public", hl = "AtlasTextPositive" },
	}

	local line = ""
	local spans = {}
	local col = 0

	for _, chip in ipairs(chips) do
		if chip ~= nil then
			local label = string.format(" %s ", chip.label)
			line = line .. label .. " "
			table.insert(spans, {
				start_col = col,
				end_col = col + #label,
				hl_group = chip.hl,
			})
			col = col + #label + 1
		end
	end

	return line, spans
end

return M
