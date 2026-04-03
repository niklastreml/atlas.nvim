---@class BitbucketPanelState
---@field panel_type "pr"|"repo"|nil  -- Which panel context is active
---@field current_item table|nil       -- The selected PR or Repository
---@field current_tab string           -- Current tab key
---@field line_map table<number, table> -- Maps line numbers to interactive elements
---
--- PR-specific data (only populated when panel_type == "pr")
---@field current_pr_detail BitbucketPRDetail|"loading"|nil
---@field current_pr_activity BitbucketPRActivity|"loading"|nil
---@field current_pr_comments BitbucketPRComments|"loading"|nil
---@field current_pr_commits BitbucketPRCommits|"loading"|nil
---@field current_pr_diffstat BitbucketPRDiffstat|"loading"|nil
---@field current_pr_diff BitbucketPRDiff|"loading"|nil
---
--- Repository-specific data (only populated when panel_type == "repo")
---@field current_repo_detail BitbucketRepositoryDetail|"loading"|nil
---@field current_repo_readme string|"loading"|nil
---@field current_repo_branches BitbucketRepositoryBranches|"loading"|nil
---@field current_repo_tags BitbucketRepositoryTags|"loading"|nil

---@type BitbucketPanelState
local M = {
	panel_type = nil,
	current_item = nil,
	current_tab = "overview",
	line_map = {},

	-- PR data
	current_pr_detail = nil,
	current_pr_activity = nil,
	current_pr_comments = nil,
	current_pr_commits = nil,
	current_pr_diffstat = nil,
	current_pr_diff = nil,

	-- Repository data
	current_repo_detail = nil,
	current_repo_readme = nil,
	current_repo_branches = nil,
	current_repo_tags = nil,
}

---@param panel_type "pr"|"repo"|nil
function M.set_panel_type(panel_type)
	M.panel_type = panel_type
end

---@param item table|nil
function M.set_current_item(item)
	M.current_item = item
	M.line_map = {}

	-- Reset all data when item changes
	M.current_pr_detail = nil
	M.current_pr_activity = nil
	M.current_pr_comments = nil
	M.current_pr_commits = nil
	M.current_pr_diffstat = nil
	M.current_pr_diff = nil
	M.current_repo_detail = nil
	M.current_repo_readme = nil
	M.current_repo_branches = nil
	M.current_repo_tags = nil
end

---@param tab_key string
function M.set_current_tab(tab_key)
	M.current_tab = tab_key
	M.line_map = {}
end

-- PR Detail setters
function M.set_pr_detail_loading()
	M.current_pr_detail = "loading"
end

---@param detail BitbucketPRDetail|nil
function M.set_pr_detail(detail)
	M.current_pr_detail = detail
end

-- PR Activity setters
function M.set_pr_activity_loading()
	M.current_pr_activity = "loading"
end

---@param activity BitbucketPRActivity|nil
function M.set_pr_activity(activity)
	M.current_pr_activity = activity
end

-- PR Comments setters
function M.set_pr_comments_loading()
	M.current_pr_comments = "loading"
end

---@param comments BitbucketPRComments|nil
function M.set_pr_comments(comments)
	M.current_pr_comments = comments
end

-- PR Commits setters
function M.set_pr_commits_loading()
	M.current_pr_commits = "loading"
end

---@param commits BitbucketPRCommits|nil
function M.set_pr_commits(commits)
	M.current_pr_commits = commits
end

-- PR Diffstat setters
function M.set_pr_diffstat_loading()
	M.current_pr_diffstat = "loading"
end

---@param diffstat BitbucketPRDiffstat|nil
function M.set_pr_diffstat(diffstat)
	M.current_pr_diffstat = diffstat
end

-- PR Diff setters
function M.set_pr_diff_loading()
	M.current_pr_diff = "loading"
end

---@param diff BitbucketPRDiff|nil
function M.set_pr_diff(diff)
	M.current_pr_diff = diff
end

-- Repository Detail setters
function M.set_repo_detail_loading()
	M.current_repo_detail = "loading"
end

---@param detail BitbucketRepositoryDetail|nil
function M.set_repo_detail(detail)
	M.current_repo_detail = detail
end

-- Repository Readme setters
function M.set_repo_readme_loading()
	M.current_repo_readme = "loading"
end

---@param readme string|nil
function M.set_repo_readme(readme)
	M.current_repo_readme = readme
end

-- Repository Branches setters
function M.set_repo_branches_loading()
	M.current_repo_branches = "loading"
end

---@param branches BitbucketRepositoryBranches|nil
function M.set_repo_branches(branches)
	M.current_repo_branches = branches
end

-- Repository Tags setters
function M.set_repo_tags_loading()
	M.current_repo_tags = "loading"
end

---@param tags BitbucketRepositoryTags|nil
function M.set_repo_tags(tags)
	M.current_repo_tags = tags
end

function M.reset()
	M.panel_type = nil
	M.current_item = nil
	M.current_tab = "overview"
	M.line_map = {}

	M.current_pr_detail = nil
	M.current_pr_activity = nil
	M.current_pr_comments = nil
	M.current_pr_commits = nil
	M.current_pr_diffstat = nil
	M.current_pr_diff = nil

	M.current_repo_detail = nil
	M.current_repo_readme = nil
	M.current_repo_branches = nil
	M.current_repo_tags = nil
end

return M
