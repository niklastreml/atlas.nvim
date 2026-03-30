---@class BitbucketPanelState
---@field current_pr table|nil
---@field current_pr_detail BitbucketPRDetail|"loading"|nil
---@field current_pr_activity BitbucketPRActivity|"loading"|nil
---@field current_pr_comments BitbucketPRComments|"loading"|nil
---@field current_pr_commits BitbucketPRCommits|"loading"|nil
---@field current_pr_diffstat BitbucketPRDiffstat|"loading"|nil
---@field current_pr_diff BitbucketPRDiff|"loading"|nil
---@field current_tab "overview"|"activity"|"comments"|"commits"|"files"
local M = {
	current_pr = nil,
	current_pr_detail = nil,
	current_pr_activity = nil,
	current_pr_comments = nil,
	current_pr_commits = nil,
	current_pr_diffstat = nil,
	current_pr_diff = nil,
	current_tab = "overview",
}

---@param pr table|nil
function M.set_current(pr)
	M.current_pr = pr
	M.current_pr_detail = nil
	M.current_pr_activity = nil
	M.current_pr_comments = nil
	M.current_pr_commits = nil
	M.current_pr_diffstat = nil
	M.current_pr_diff = nil
end

---@param detail BitbucketPRDetail|nil
function M.set_current_detail(detail)
	M.current_pr_detail = detail
end

function M.set_current_detail_loading()
	M.current_pr_detail = "loading"
end

---@param commits BitbucketPRCommits|nil
function M.set_current_commits(commits)
	M.current_pr_commits = commits
end

function M.set_current_commits_loading()
	M.current_pr_commits = "loading"
end

---@param activity BitbucketPRActivity|nil
function M.set_current_activity(activity)
	M.current_pr_activity = activity
end

function M.set_current_activity_loading()
	M.current_pr_activity = "loading"
end

---@param comments BitbucketPRComments|nil
function M.set_current_comments(comments)
	M.current_pr_comments = comments
end

function M.set_current_comments_loading()
	M.current_pr_comments = "loading"
end

---@param diffstat BitbucketPRDiffstat|nil
function M.set_current_diffstat(diffstat)
	M.current_pr_diffstat = diffstat
end

function M.set_current_diffstat_loading()
	M.current_pr_diffstat = "loading"
end

---@param diff BitbucketPRDiff|nil
function M.set_current_diff(diff)
	M.current_pr_diff = diff
end

function M.set_current_diff_loading()
	M.current_pr_diff = "loading"
end

---@param tab "overview"|"activity"|"comments"|"commits"|"files"
function M.set_current_tab(tab)
	if tab == "overview" or tab == "activity" or tab == "comments" or tab == "commits" or tab == "files" then
		M.current_tab = tab
	end
end

function M.reset_current()
	M.current_pr = nil
	M.current_pr_detail = nil
	M.current_pr_activity = nil
	M.current_pr_comments = nil
	M.current_pr_commits = nil
	M.current_pr_diffstat = nil
	M.current_pr_diff = nil
	M.current_tab = "overview"
end

return M
