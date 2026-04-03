local M = {}

local config = require("atlas.config")
local footer = require("atlas.ui.components.footer")

---@param value string
---@param label string
local function copy_value(value, label)
	if value == "" then
		footer.notify("warn", "Nothing to copy")
		return
	end

	vim.fn.setreg("+", value)
	vim.fn.setreg('"', value)
	footer.notify("info", string.format("Copied %s", label))
end

---@return string
local function jira_base_url()
	local jira = (config.options and config.options.jira) or {}
	local base_url = tostring(jira.base_url or "")
	if base_url == "" then
		return ""
	end

	return (base_url:gsub("/$", ""))
end

---@param issue JiraIssue|nil
---@return string
local function issue_key(issue)
	if type(issue) ~= "table" then
		return ""
	end

	return tostring(issue.key or "")
end

---@param key string
---@return string
local function issue_url_for_key(key)
	local base_url = jira_base_url()
	if base_url == "" or key == "" then
		return ""
	end

	return string.format("%s/browse/%s", base_url, key)
end

function M.create_issue()
	local base_url = jira_base_url()
	if base_url == "" then
		footer.notify("warn", "Missing Jira base URL")
		return
	end

	vim.ui.open(string.format("%s/secure/CreateIssue!default.jspa", base_url))
end

---@param issue JiraIssue|nil
function M.browse_issue(issue)
	local key = issue_key(issue)
	if key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local url = issue_url_for_key(key)
	if url == "" then
		footer.notify("warn", "No URL found for issue")
		return
	end

	vim.ui.open(url)
end

---@param issue JiraIssue|nil
function M.copy_issue_key(issue)
	copy_value(issue_key(issue), "issue key")
end

---@param issue JiraIssue|nil
function M.copy_issue_url(issue)
	local key = issue_key(issue)
	if key == "" then
		footer.notify("warn", "No issue selected")
		return
	end

	local url = issue_url_for_key(key)
	if url == "" then
		footer.notify("warn", "No URL found for issue")
		return
	end

	copy_value(url, "issue URL")
end

return M
