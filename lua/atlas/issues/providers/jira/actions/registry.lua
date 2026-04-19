local M = {}

local config = require("atlas.config")
local icons = require("atlas.ui.shared.icons")
local footer = require("atlas.ui.components.footer")
local async_picker = require("atlas.ui.components.async_picker")
local issues_api = require("atlas.issues.providers.jira.api.issues")

---@param ctx table
---@return boolean
local function has_issue_key(ctx)
	local issue = type(ctx) == "table" and ctx.issue or nil
	if type(issue) ~= "table" then
		return false
	end
	local key = tostring(issue.key or "")
	return key ~= ""
end

---@type table[]
local ACTIONS = {
	{
		id = "search_query_issue",
		label = "Search Issue",
		is_available = function()
			return true, nil
		end,
		run = function(_, done)
			async_picker.open({
				title = "Search Query Ticket",
				prompt = "Search tickets",
				debounce_ms = 200,
				identifier = "jira_issue_picker_search",
				cache_ttl_ms = 30000,
				fetch_on_open = true,
				format_item = function(item)
					return string.format("%s %s", icons.issues_provider("jira", "provider"), tostring(item.label or ""))
				end,
				fetch = function(fetch_ctx, fetch_done)
					local query = vim.trim(fetch_ctx.query)
					issues_api.search_issue(query, function(items, err)
						if fetch_ctx.signal.cancelled then
							return
						end

						if err ~= nil or items == nil then
							fetch_done(nil, err or "Failed to search tickets")
							return
						end

						local picker_items = {}
						for _, issue in ipairs(items) do
							table.insert(picker_items, {
								id = tostring(issue.id or issue.key),
								label = string.format("%s - %s", issue.key, issue.summary),
								secondary = issue.key,
								value = issue,
							})
						end

						fetch_done(picker_items, nil)
					end)
				end,
				on_select = function(item)
					local issue = item.value
					local issue_key = tostring((issue or {}).key or "")
					if issue_key == "" then
						done(nil, "Selected issue is missing key")
						return
					end

					local search_view = {
						name = string.format("Search (%s)", issue_key),
						jql = string.format('key = "%s"', issue_key),
					}

					require("atlas.issues.ui.main.controller").switch_view(search_view)
					done({ changed_issue_key = issue_key, message = string.format("Opened %s", issue_key) }, nil)
				end,
				on_cancel = function()
					done({ changed_issue_key = nil, message = "Search cancelled" }, nil)
				end,
			})
		end,
	},
	{
		id = "browse_issue",
		label = "Open Issue In Browser",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local base_url = tostring(((config.options and config.options.jira) or {}).base_url or ""):gsub("/$", "")
			local issue_key = tostring(issue.key or "")
			if base_url == "" or issue_key == "" then
				done(nil, "No URL found for issue")
				return
			end

			vim.ui.open(string.format("%s/browse/%s", base_url, issue_key))
			done({ changed_issue_key = nil, message = string.format("Opened %s in browser", issue_key) }, nil)
		end,
	},
	{
		id = "copy_issue_key",
		label = "Copy Issue Key",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local issue_key = tostring(issue.key or "")
			if issue_key == "" then
				done(nil, "Nothing to copy")
				return
			end

			vim.fn.setreg("+", issue_key)
			vim.fn.setreg('"', issue_key)
			done({ changed_issue_key = nil, message = "Copied issue key" }, nil)
		end,
	},
	{
		id = "copy_issue_url",
		label = "Copy Issue URL",
		is_available = has_issue_key,
		run = function(ctx, done)
			local issue = ctx.issue
			if not has_issue_key(ctx) or issue == nil then
				done(nil, "No issue selected")
				return
			end

			local base_url = tostring(((config.options and config.options.jira) or {}).base_url or ""):gsub("/$", "")
			local issue_key = tostring(issue.key or "")
			local url = (base_url ~= "" and issue_key ~= "") and string.format("%s/browse/%s", base_url, issue_key) or ""
			if url == "" then
				done(nil, "No URL found for issue")
				return
			end

			vim.fn.setreg("+", url)
			vim.fn.setreg('"', url)
			done({ changed_issue_key = nil, message = "Copied issue URL" }, nil)
		end,
	},
}

---@param ctx table
---@return table[]
function M.available(ctx)
	local out = {}
	for _, action in ipairs(ACTIONS) do
		local ok = action.is_available(ctx)
		if ok then
			table.insert(out, action)
		end
	end
	return out
end

---@param id string
---@return table|nil
function M.find(id)
	for _, action in ipairs(ACTIONS) do
		if action.id == id then
			return action
		end
	end
	return nil
end

return M
