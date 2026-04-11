local M = {}
local utils = require("atlas.utils")
local icons = require("atlas.ui.utils.icons")
local pr_helper = require("atlas.bitbucket.panel.tabs.pr.helper")

local MAX_HASH_CHIP_LEN = 12

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

---@param status "successful"|"failed"|"inprogress"|"stopped"|"unknown"
---@return string
local function status_hl(status)
	if status == "successful" then
		return "AtlasTextPositive"
	end
	if status == "failed" then
		return "AtlasLogError"
	end
	if status == "inprogress" then
		return "AtlasTextWarning"
	end
	if status == "stopped" then
		return "AtlasTextMuted"
	end
	return "AtlasTextMuted"
end

---@param statuses BitbucketPRStatuses|"loading"|nil
---@return "successful"|"failed"|"inprogress"|"stopped"|"unknown"|nil
local function aggregate_status(statuses)
	if statuses == "loading" then
		return nil
	end
	return pr_helper.statuses.aggregate(statuses)
end

---@param pr BitbucketPR
---@param statuses BitbucketPRStatuses|"loading"|nil
---@param opts { padding_x?: integer }|nil
---@return string line
---@return table[] spans
function M.render(pr, statuses, opts)
	local commit_hash = tostring((pr.source or {}).commit_hash or "")
	if commit_hash == "" then
		commit_hash = "-"
	elseif #commit_hash > MAX_HASH_CHIP_LEN then
		commit_hash = commit_hash:sub(1, MAX_HASH_CHIP_LEN)
	end

	local checks_status = aggregate_status(statuses)
	local checks_chip = nil
	local checks_hl = nil
	if statuses == "loading" then
		checks_chip = string.format("%s Loading builds", icons.bitbucket_icon("bitbucket.status.inprogress"))
		checks_hl = "AtlasTextMuted"
	elseif checks_status ~= nil and checks_status ~= "unknown" then
		checks_chip = string.format("%s %s", icons.bitbucket_icon("bitbucket.status." .. checks_status), pr_helper.statuses.label(checks_status))
		checks_hl = status_hl(checks_status)
	end

	local chips = {
		{ label = tostring(pr.state or "UNKNOWN"), hl = state_hl(pr.state) },
		{ label = commit_hash, hl = "AtlasTabInactive" },
		checks_chip ~= nil and { label = checks_chip, hl = checks_hl } or nil,
		pr.is_draft and { label = "DRAFT", hl = "AtlasBitbucketPRDraft" } or nil,
	}

	local pad = math.max(0, (opts or {}).padding_x or 1)
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

---@param repo BitbucketRepository
---@param opts { padding_x?: integer }|nil
---@return string line
---@return table[] spans
function M.render_repo(repo, opts)
	if type(repo) ~= "table" then
		return "", {}
	end

	local chips = {
		{ label = string.format("%s %s", icons.bitbucket_icon("bitbucket.entity.files"), utils.human_size(repo.size)), hl = "AtlasTabInactive" },
		{
			label = string.format("%s %s", icons.bitbucket_icon("bitbucket.entity.branch"), tostring(repo.mainbranch or "-")),
			hl = "AtlasBitbucketPRMerged",
		},
		repo.is_private == true and { label = "private", hl = "AtlasBitbucketPRDraft" }
			or { label = "public", hl = "AtlasTextPositive" },
	}

	local pad = math.max(0, (opts or {}).padding_x or 1)
	local line = string.rep(" ", pad)
	local spans = {}
	local col = pad

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
