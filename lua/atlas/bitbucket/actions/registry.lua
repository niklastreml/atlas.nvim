local M = {}

local pullrequests = require("atlas.bitbucket.api.pullrequests")
local footer = require("atlas.ui.components.footer")
local checkout = require("atlas.core.git.checkout")
local logger = require("atlas.core.logger")

---@class BitbucketActionContext
---@field pr BitbucketPR|nil
---@field source "panel"|"main"|nil

---@class BitbucketActionResult
---@field changed_pr boolean
---@field message string|nil

---@class BitbucketActionDef
---@field id string
---@field label string
---@field is_available fun(ctx: BitbucketActionContext): boolean
---@field run fun(ctx: BitbucketActionContext, done: fun(result: BitbucketActionResult|nil, err: string|nil))

---@param ctx BitbucketActionContext
---@return boolean
local function has_pr(ctx)
	return ctx.pr ~= nil and ctx.pr.id ~= nil
end

---@param ctx BitbucketActionContext
---@param pr BitbucketPR|nil
---@return string|nil open_cmd
---@return string|nil command
---@return string|nil err
local function diff_open_command(ctx, pr)
	if not has_pr(ctx) or type(pr) ~= "table" then
		return nil, nil, "No PR selected"
	end

	local cfg = require("atlas.config").options.bitbucket or {}
	local diff = cfg.diff or {}
	local cmd = tostring(diff.open_cmd or "")
	cmd = (cmd:gsub("^%s+", ""):gsub("%s+$", ""))
	if cmd == "" then
		return nil, nil, "bitbucket.diff.open_cmd is not configured"
	end

	if vim.fn.exists(":" .. cmd) ~= 2 then
		return nil, nil, string.format("bitbucket.diff.open_cmd command not found: %s", cmd)
	end

	local src = tostring((pr.source or {}).branch or "")
	local dst = tostring((pr.destination or {}).branch or "")
	if src == "" or dst == "" then
		return nil, nil, "PR branch refs are missing"
	end

	local range = "origin/" .. dst .. "...origin/" .. src
	return cmd, cmd .. " " .. range, nil
end

---@param ctx BitbucketActionContext
---@return boolean
local function has_repo_paths_configured(ctx)
	if not has_pr(ctx) then
		return false
	end
	local cfg = require("atlas.config").options.bitbucket or {}
	return not vim.tbl_isempty((cfg.repo_config or {}).paths or {})
end

---@type BitbucketActionDef[]
local ACTIONS = {
	{
		id = "checkout",
		label = "Checkout",
		is_available = function(ctx)
			return has_pr(ctx) and has_repo_paths_configured(ctx)
		end,
		run = function(ctx, done)
			local pr = ctx.pr
			if pr == nil then
				footer.notify("warn", "No PR selected")
				done(nil, "No PR selected")
				return
			end

			footer.notify("loading", string.format("Checking out PR #%s", tostring(pr.id or "")))
			checkout.checkout_pr(pr, function(_, err)
				vim.schedule(function()
					if err ~= nil then
						footer.notify("error", string.format("Checkout failed: %s", tostring(err)))
						done(nil, tostring(err))
						return
					end

					footer.notify("success", string.format("Checked out PR #%s", tostring(pr.id or "")))
					done({ changed_pr = false, message = "Checked out" }, nil)
				end)
			end)
		end,
	},
	{
		id = "open_diffview",
		label = "Open PR Diff",
		is_available = function(ctx)
			if not has_pr(ctx) or ctx.pr == nil or not has_repo_paths_configured(ctx) then
				return false
			end

			local src = tostring((ctx.pr.source or {}).branch or "")
			local dst = tostring((ctx.pr.destination or {}).branch or "")
			return src ~= "" and dst ~= ""
		end,
		run = function(ctx, done)
			local pr = ctx.pr
			if pr == nil then
				done(nil, "No PR selected")
				return
			end

			local resolved_path = checkout.resolve_repo_path_for_pr(pr, { require_git = true, require_existing = true })
			if resolved_path == nil or resolved_path == "" then
				footer.notify("warn", "Local repo not found")
				done(nil, "Local repo not found")
				return
			end

			local repo_path = vim.fn.fnameescape(resolved_path)
			local open_cmd, command, open_cmd_err = diff_open_command(ctx, pr)
			if open_cmd_err ~= nil or open_cmd == nil or command == nil then
				local level = open_cmd_err == "PR branch refs are missing" and "warn" or "error"
				footer.notify(level, tostring(open_cmd_err))
				done(nil, tostring(open_cmd_err))
				return
			end

			footer.notify("loading", "Fetching remote branches...")
			checkout.fetch_pr_branches(pr, resolved_path, function(fetch_err)
				if fetch_err ~= nil then
					local message = "Fetch failed: " .. tostring(fetch_err)
					logger.logerror(
						"bitbucket.diff.fetch_failed",
						{ pr_id = pr.id, repo_path = resolved_path, command = command, error = tostring(fetch_err) }
					)
					footer.notify("error", message)
					done(nil, message)
					return
				end

				logger.loginfo("bitbucket.diff.open", { pr_id = pr.id, repo_path = resolved_path, command = command })
				local ok, err = pcall(function()
					if open_cmd == "DiffviewOpen" then
						local prev_path = vim.fn.fnameescape(vim.fn.getcwd())
						vim.cmd("cd " .. repo_path)
						local cmd_ok, cmd_err = pcall(function()
							vim.cmd(command)
						end)

						vim.cmd("cd " .. prev_path)
						if not cmd_ok then
							error(cmd_err)
						end
						return
					end

					vim.cmd("tabnew")
					vim.cmd("cd " .. repo_path)
					vim.cmd(command)
				end)

				if not ok then
					local message = string.format("%s failed: %s", open_cmd, tostring(err))
					logger.logerror(
						"bitbucket.diff.open_failed",
						{ pr_id = pr.id, repo_path = resolved_path, command = command, error = tostring(err) }
					)
					footer.notify("error", message)
					done(nil, message)
					return
				end

				footer.notify("success", "Opened PR diff", 1200)
				done({ changed_pr = false, message = "Opened PR diff" }, nil)
			end)
		end,
	},
	{
		id = "merge",
		label = "Merge",
		is_available = function(ctx)
			if not has_pr(ctx) or ctx.pr == nil then
				return false
			end
			local merge_url = tostring((ctx.pr.links or {}).merge or "")
			return merge_url ~= ""
		end,
		run = function(ctx, done)
			local pr = ctx.pr
			if pr == nil then
				done(nil, "No PR selected")
				return
			end

			local merge_url = tostring((pr.links or {}).merge or "")
			if merge_url == "" then
				merge_url = tostring((((pr._raw or {}).links or {}).merge or {}).href or "")
			end

			if merge_url == "" then
				done(nil, "No merge URL available")
				return
			end

			vim.ui.input({
				prompt = string.format("Confirm merge PR #%s? [y/N]: ", tostring(pr.id or "")),
			}, function(input)
				if input == nil then
					done({ changed_pr = false, message = "Merge cancelled" }, nil)
					return
				end

				local normalized = vim.trim(tostring(input)):lower()
				if normalized ~= "y" and normalized ~= "yes" then
					footer.notify("info", "Merge cancelled")
					done({ changed_pr = false, message = "Merge cancelled" }, nil)
					return
				end

				footer.notify("loading", "Starting Merge...")
				pullrequests.merge(merge_url, {
					close_source_branch = true,
					merge_strategy = "merge_commit",
				}, function(_, err)
					if err ~= nil then
						footer.notify("error", string.format("Merge failed: %s", tostring(err)))
						done(nil, tostring(err))
						return
					end

					footer.notify("success", "Merge succeeded", 1200)
					done({ changed_pr = true, message = "Merged" }, nil)
				end)
			end)
		end,
	},
	{
		id = "approve",
		label = "Approve",
		is_available = function(ctx)
			if not has_pr(ctx) or ctx.pr == nil then
				return false
			end
			local link = tostring((ctx.pr.links or {}).approve or "")
			return link ~= ""
		end,
		run = function(ctx, done)
			local pr = ctx.pr
			if pr == nil then
				done(nil, "No PR selected")
				return
			end

			local approve_url = tostring((pr.links or {}).approve or "")
			if approve_url == "" then
				done(nil, "No approve URL available")
				return
			end

			footer.notify("loading", "Approving PR...")
			pullrequests.approve(approve_url, function(_, err)
				if err ~= nil then
					footer.notify("error", string.format("Approve failed: %s", tostring(err)))
					done(nil, tostring(err))
					return
				end

				footer.notify("success", "PR approved", 1200)
				done({ changed_pr = true, message = "Approved" }, nil)
			end)
		end,
	},
	{
		id = "request_changes",
		label = "Request changes",
		is_available = function(ctx)
			if not has_pr(ctx) or ctx.pr == nil then
				return false
			end
			return tostring((ctx.pr.links or {}).request_changes or "") ~= ""
		end,
		run = function(ctx, done)
			local pr = ctx.pr
			if pr == nil then
				done(nil, "No PR selected")
				return
			end

			local request_changes_url = tostring((pr.links or {}).request_changes or "")
			if request_changes_url == "" then
				done(nil, "No request changes URL available")
				return
			end

			footer.notify("loading", "Requesting changes...")
			pullrequests.request_changes(request_changes_url, function(_, err)
				if err ~= nil then
					footer.notify("error", string.format("Request changes failed: %s", tostring(err)))
					done(nil, tostring(err))
					return
				end

				footer.notify("success", "Changes requested", 1200)
				done({ changed_pr = true, message = "Changes requested" }, nil)
			end)
		end,
	},
}

---@param ctx BitbucketActionContext
---@return BitbucketActionDef[]
function M.available(ctx)
	local cfg = require("atlas.config").options.bitbucket or {}
	local custom_actions = cfg.custom_actions or {}

	local out = {}

	-- Add built-in actions
	for _, action in ipairs(ACTIONS) do
		if action.is_available(ctx) then
			table.insert(out, action)
		end
	end

	-- Add custom actions
	for _, item in ipairs(custom_actions) do
		if type(item) == "table" and type(item.label) == "string" and type(item.run) == "function" then
			table.insert(out, {
				id = tostring(item.id or item.label),
				label = item.label,
				is_available = function()
					return has_pr(ctx)
				end,
				run = function(action_ctx, done)
					footer.notify("loading", string.format("Running %s...", tostring(item.label)))

					local done_called = false
					local function custom_done(ok, message)
						if done_called then
							return
						end
						done_called = true

						vim.schedule(function()
							if ok == false then
								footer.notify("error", tostring(message or (item.label .. " failed")))
								logger.logerror(string.format("Custom action failed: %s", tostring(message)))
								done(nil, tostring(message or (item.label .. " failed")))
								return
							end
							footer.notify("success", tostring(message or (item.label .. " done")))
							done({ changed_pr = false, message = tostring(message or (item.label .. " done")) }, nil)
						end)
					end

					local repo_path = checkout.resolve_repo_path_for_pr(action_ctx.pr, {
						require_git = false,
						require_existing = false,
					})

					local ok, err = pcall(item.run, action_ctx.pr, {
						repo_path = repo_path,
						pr = action_ctx.pr,
					}, custom_done)

					if not ok then
						custom_done(false, string.format("Custom action failed: %s", tostring(err)))
						logger.logerror(
							string.format("Custom action '%s' execution error: %s", item.label, tostring(err))
						)
					end
				end,
			})
		end
	end

	return out
end

---@param id string
---@return BitbucketActionDef|nil
function M.find(id)
	for _, action in ipairs(ACTIONS) do
		if action.id == id then
			return action
		end
	end
	return nil
end

return M
