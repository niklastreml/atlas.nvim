--------------------------------------------------------------------------------
-- Provider Interface
--------------------------------------------------------------------------------

---@class PullsProvider
---@field id string
---@field name string
---@field icon string
---@field hl_group string
---
--- Lifecycle:
---@field setup fun()|nil
---
--- Core data methods:
---@field fetch_user fun(on_done: fun(user: PullsUser|nil, err: string|nil))
---@field fetch_pullrequests fun(view: PullsView, opts: table, on_done: fun(groups: PullsGroup[], err: string[]|nil)): { cancel: fun() }|nil
---@field fetch_pullrequest fun(repo_id: string, pr_id: string|number, opts: table, on_done: fun(pr: PullRequest|nil, err: string|nil)): { cancel: fun() }|nil
---@field fetch_reviewers (fun(pr: PullRequest, on_done: fun(reviewers: PullsReviewer[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_builds (fun(pr: PullRequest, on_done: fun(builds: PullsBuild[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_diffstat (fun(pr: PullRequest, on_done: fun(entries: PullsDiffstatEntry[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_activity (fun(pr: PullRequest, on_done: fun(entries: PullsActivityEntry[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_comments (fun(pr: PullRequest, on_done: fun(comments: PullsComment[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_commits (fun(pr: PullRequest, on_done: fun(commits: PullsCommit[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_diff (fun(pr: PullRequest, on_done: fun(files: PullsDiffFile[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_commit_status (fun(pr: PullRequest, commit_hash: string, on_done: fun(status: string|nil, url: string|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---
--- Views:
---@field views fun(): PullsView[]
---
--- Actions:
---@field open_actions fun(pr: PullRequest|nil, opts: table, on_done: fun(result: PullsActionResult|nil))|nil
---@field open_diff fun(pr: PullRequest, on_done: fun(ok: boolean))|nil
---@field checkout fun(pr: PullRequest, on_done: fun(ok: boolean))|nil
---
--- Panel:
---@field panel PullsProviderPanel|nil
---
--- Healthcheck:
---@field health fun()|nil

--------------------------------------------------------------------------------
-- Action Result
--------------------------------------------------------------------------------

---@class PullsActionResult
---@field changed_pr boolean
---@field message string|nil

--------------------------------------------------------------------------------
-- Provider Panel Interface
--------------------------------------------------------------------------------

---@class PullsProviderPanel
---@field header_rows (fun(pr: PullRequest): PullsPanelHeaderRow[])|nil
---@field chips (fun(pr: PullRequest): PullsPanelChip[])|nil
---@field tabs (fun(): PullsPanelTab[])|nil
---@field fetches (fun(pr: PullRequest, done: fun()))|nil
---@field is_loading (fun(pr: PullRequest): boolean)|nil

--------------------------------------------------------------------------------
-- Panel types
--------------------------------------------------------------------------------

---@class PullsPanelHeaderRow
---@field k1 string
---@field v1 string
---@field v1_hl string
---@field k2 string
---@field v2 string
---@field v2_hl string

---@class PullsPanelChip
---@field label string
---@field hl string|nil

---@class PullsPanelTabModule
---@field render fun(pr: PullRequest, width: integer): string[], table[], table<integer, table>|nil
---@field on_select (fun(pr: PullRequest, repo: PullsRepo|nil, done: fun()))|nil

---@class PullsPanelTab
---@field key string
---@field label string
---@field icon string|nil
---@field mod PullsPanelTabModule
