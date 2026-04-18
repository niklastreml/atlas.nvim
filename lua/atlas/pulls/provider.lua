--------------------------------------------------------------------------------
-- Provider Interface
--------------------------------------------------------------------------------

---@class PullsFetchOpts
---@field force_load boolean|nil
---@field pagelen number|nil


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
---@field fetch_pullrequests fun(view: AtlasPullsViewConfig, opts: PullsFetchOpts, on_done: fun(groups: PullsGroup[], err: string[]|nil)): { cancel: fun() }|nil
---@field fetch_pullrequest fun(pr: PullRequest, opts: PullsFetchOpts, on_done: fun(pr: PullRequest|nil, err: string|nil)): { cancel: fun() }|nil
---@field fetch_reviewers (fun(pr: PullRequest, opts: { force_refresh: boolean|nil }|nil, on_done: fun(reviewers: PullsReviewer[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_builds (fun(pr: PullRequest, on_done: fun(builds: PullsBuild[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_diffstat (fun(pr: PullRequest, opts: { force_refresh: boolean|nil }|nil, on_done: fun(entries: PullsDiffstatEntry[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_activity (fun(pr: PullRequest, opts: { force_refresh: boolean|nil }|nil, on_done: fun(entries: PullsActivityEntry[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_comments (fun(pr: PullRequest, opts: { force_refresh: boolean|nil }|nil, on_done: fun(comments: PullsComment[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_commits (fun(pr: PullRequest, opts: { force_refresh: boolean|nil }|nil, on_done: fun(commits: PullsCommit[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_diff (fun(pr: PullRequest, opts: { force_refresh: boolean|nil }|nil, on_done: fun(files: PullsDiffFile[]|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field fetch_commit_status (fun(pr: PullRequest, commit: PullsCommit, opts: { force_refresh: boolean|nil }|nil, on_done: fun(status: string|nil, url: string|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---
---@field add_comment (fun(pr: PullRequest, content: string, on_done: fun(comment: PullsComment|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field reply_comment (fun(pr: PullRequest, parent_id: number, content: string, on_done: fun(comment: PullsComment|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field edit_comment (fun(pr: PullRequest, comment_id: number, content: string, on_done: fun(comment: PullsComment|nil, err: string|nil)): { cancel: fun() }|nil)|nil
---@field delete_comment (fun(pr: PullRequest, comment_id: number, on_done: fun(ok: boolean, err: string|nil)): { cancel: fun() }|nil)|nil
---@field comment_completion (fun(pr: PullRequest): AtlasMarkdownCompletionProvider|nil)|nil
---
---@field views fun(): AtlasPullsViewConfig[]
---@field open_actions fun(pr: PullRequest|nil, source: "main"|"panel"|nil, on_done: fun(result: PullsActionResult|nil))|nil
---@field search fun()|nil
---
---@field panel PullsProviderPanel|nil
---
---@field health fun()|nil

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
---@field on_select (fun(pr: PullRequest, repo: PullsRepo|nil, done: fun(), opts: { force_refresh: boolean|nil }|nil))|nil
---@field is_selectable_line (fun(lnum: integer, entry: table): boolean)|nil
---@field on_enter (fun(pr: PullRequest, entry: table): boolean|nil)|nil
---@field setup_keymaps (fun(buf: integer, cursor_entry: fun(): table|nil, done: fun()))|nil
---@field teardown_keymaps (fun(buf: integer))|nil

---@class PullsPanelTab
---@field key string
---@field label string
---@field icon string|nil
---@field mod PullsPanelTabModule
