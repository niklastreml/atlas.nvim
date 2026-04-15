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
---
--- Views:
---@field views fun(): PullsView[]
---
--- Actions (provider owns the full UX: picker, execution, result handling):
---@field open_actions fun(pr: PullRequest|nil, opts: table, on_done: fun(result: PullsActionResult|nil))|nil
---
--- Provider-specific operations:
---@field open_diff fun(pr: PullRequest, on_done: fun(ok: boolean))|nil
---@field checkout fun(pr: PullRequest, on_done: fun(ok: boolean))|nil
---
--- Panel customisation:
---@field panel_header_rows fun(pr: PullRequest): PullsPanelHeaderRow[]|nil
---@field panel_chips fun(pr: PullRequest): PullsPanelChip[]|nil
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
