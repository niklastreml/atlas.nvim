local M = {}

function M.search_issues(jql, page_token, max_results, fields, callback) end

function M.get_issue(issue_key, callback) end

function M.create_issue(fields, callback) end

function M.update_issue(issue_key, fields, callback) end

function M.get_create_meta(project_key, callback) end

return M
