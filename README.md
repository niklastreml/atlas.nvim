# Atlas.nvim

A Neovim plugin for managing Bitbucket PRs and Jira issues without leaving your editor.

> [!CAUTION]
> **Still in early development, will have breaking changes!**

<div>
  
  <img src="https://github.com/user-attachments/assets/3da6e584-47a1-411e-91f6-110dbdc75293" width="49%" />
  <img src="https://github.com/user-attachments/assets/80eeb59a-4a04-40e0-90fb-92ac5d4da249" width="49%" />
</div>

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "emrearmagan/atlas.nvim",
  dependencies = {
    "MeanderingProgrammer/render-markdown.nvim", -- optional but recommended
  },
  config = function()
    require("atlas").setup({
        bitbucket = { }, -- See configuration below
        jira = { },      -- See configuration below
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "emrearmagan/atlas.nvim",
  config = function()
    require("atlas").setup({
        bitbucket = { }, -- See configuration below
        jira = { },      -- See configuration below
    })
  end
}
```

> [!tip]
> It's a good idea to run `:checkhealth atlas` to see if everything is set up correctly.

## Bitbucket

### Configuration

```lua
return {
  "emrearmagan/atlas.nvim",
  config = function()
    require("atlas").setup({
      ---@type BitbucketConfig
      bitbucket = {
        user = os.getenv("BITBUCKET_USER") or "",
        token = os.getenv("BITBUCKET_TOKEN") or "",
        cache_ttl = 300,
        -- Maps `workspace/repo` to local paths. Used for checkout and custom actions.
        repo_paths = {
          ["your-workspace/*"] = "~/code/repos/*",
          ["your-workspace/atlas"] = "~/code/atlas",
        },
        custom_actions = {}, -- See Custom Actions below.

        ---@type BitbucketViewConfig[]
        views = {
          {
            name = "Me",
            key = "M",
            layout = "compact", -- "compact" or "plain"
            repos = {
              { workspace = "your-workspace", repo = "atlas", readme = "README.md" }, --- readme is optional, if provided it will be rendered in the PR details panel. Defaults to README.md
            },

            ---@param pr BitbucketPR
            ---@param ctx table
            filter = function(pr, ctx)
              local user = ctx.user or {}
              return pr.author and pr.author.account_id == user.account_id
            end,
          },
          {
            name = "Others",
            key = "O",
            layout = "plain", -- "compact" or "plain"
            repos = {
              { workspace = "your-workspace", repo = "atlas" },
              { workspace = "your-workspace", repo = "other-repo" },
            },
          },
        },
      },
    })
  end,
}
```

#### Custom Actions

You can add custom PR actions under `bitbucket.custom_actions`.

Context type:

```lua
---@class BitbucketCustomActionContext
---@field repo_path string|nil
---@field pr BitbucketPR
```

Example:

```lua
bitbucket = {
  repo_paths = {
    ["your-workspace/*"] = "~/code/repos/*",
  },
  custom_actions = {
    {
      id = "open_tmux_window",
      label = "Open repo in tmux window",
      confirmation = true, -- present a confirmation prompt before running the action
      ---@param pr BitbucketPR
      ---@param ctx BitbucketCustomActionContext
      ---@param done fun(ok: boolean|nil, message: string|nil)
      run = function(_, ctx, done)
        if not ctx.repo_path then
          done(false, "No repo path")
          return
        end

        vim.system({ "tmux", "new-window", "-c", ctx.repo_path }, { text = true }, function(res)
          vim.schedule(function()
            if res.code ~= 0 then
              done(false, "Failed to open tmux window")
              return
            end
            done(true, "Opened tmux window")
          end)
        end)
      end,
    },
  },
}
```

![CleanShot2026-03-31at20 08 06-ezgif com-video-to-gif-converter](https://github.com/user-attachments/assets/a8ca355b-09e2-428c-b3fb-3280fd161110)

#### Features

- [x] Multiple Bitbucket views
- [x] PR tabs: overview, activity, comments, commits, files
- [x] PR actions: merge, approve, request changes
- [x] Add custom actions to PRs
- [x] Resolve and checkout PR branches locally
- [ ] Pagination for API results (PRs, comments, commits, files, activity)
- [ ] Switch between open, merged and superseded PRs
- [ ] Bulk actions: approve/request changes on multiple PRs at once
- [ ] PR files: fuzzy filter changed files by path

<img width="2532" height="1366" alt="CleanShot 2026-03-31 at 02 51 32" src="https://github.com/user-attachments/assets/d08dde1f-8bae-446f-8db1-a9f53b118fad" />

## Jira

> [!NOTE]
> Inspired by [jira.nvim](https://github.com/letieu/jira.nvim) since it fitted nicely in this here. I highly recommend checking out the original project for a more general-purpose solution.

### Configuration

```lua
return {
  "emrearmagan/atlas.nvim",
  config = function()
    require("atlas").setup({
      ---@type JiraConfig
      jira = {
        base_url = os.getenv("JIRA_BASE_URL") or "",
        email = os.getenv("JIRA_EMAIL") or "",
        token = os.getenv("JIRA_TOKEN") or "",
        cache_ttl = 300,

        ---@type JiraViewConfig[]
        views = {
          {
            name = "My Board",
            key = "M",
            project = "KAN",
            -- project is optional
            jql = "project = KAN AND assignee = currentUser() ORDER BY updated DESC",
          },
          {
            name = "Team Board",
            key = "T",
            project = "KAN",
          },
        },
      },
    })
  end,
}
```

#### Comments

- Create, reply, edit, and delete comments directly in the Jira panel.

<img width="1001" height="426" alt="CleanShot 2026-04-03 at 01 07 06" src="https://github.com/user-attachments/assets/e188582e-f784-46a8-aacd-ac989054c378" />

#### Issue Editing (Experimental)

- Edit issue description directly from Overview.
- Supports markdown editing with markdown -> ADF conversion.
- Supports raw ADF mode for direct document editing.

<img width="2520" height="1373" alt="CleanShot 2026-04-03 at 01 11 10" src="https://github.com/user-attachments/assets/b46a4018-6adf-4b9f-b6fe-0b8bdbb5efaa" />

#### Features

- [x] Multiple Jira views
- [x] Issue panel tabs: overview, comments, history
- [x] Jira actions: transition, change assignee, change reporter, edit title
- [x] Full comment workflows (create, reply, edit, delete)
- [x] Markdown -> ADF conversion for issue descriptions (experimental)
- [x] View and edit issues as markdown
- [x] Search issues
- [ ] Add support for custom fields in issue details
- [ ] Create issues

### Commands

- `:AtlasJira` - Open Jira issue picker
- `:AtlasBitbucket` - Open Bitbucket PR picker
- `:AtlasLogs` - Toggle Atlas logs

### Keymaps

### Main UI

| Key        | Action                    |
| ---------- | ------------------------- |
| `q`        | Close Atlas               |
| `j` / `k`  | Move cursor               |
| `gg` / `G` | First / last item         |
| `[` / `]`  | Previous / next panel tab |
| `p`        | Toggle detail panel       |

### Bitbucket

| Key  | Action                         |
| ---- | ------------------------------ |
| `R`  | Refresh current Bitbucket view |
| `r`  | Refetch selected PR            |
| `A`  | Open PR actions                |
| `gx` | Open PR in browser             |
| `y`  | Copy PR id                     |
| `Y`  | Copy PR URL                    |
| `/`  | Search repositories            |
| `o`  | Toggle repository panel        |

### Jira

| Key  | Action                    |
| ---- | ------------------------- |
| `R`  | Refresh current Jira view |
| `r`  | Reload selected issue     |
| `K`  | Show issue details popup  |
| `A`  | Open Jira actions         |
| `c`  | Create issue              |
| `gx` | Open issue in browser     |
| `y`  | Copy issue key            |
| `Y`  | Copy issue URL            |

### Jira Panel

| Key | Action                                  |
| --- | --------------------------------------- |
| `m` | Toggle Overview mode (markdown/raw ADF) |
| `e` | Edit Overview description               |
| `a` | Add comment (Comments tab)              |
| `c` | Reply to comment (Comments tab)         |
| `d` | Delete comment (Comments tab)           |

## License

MIT License - see [LICENSE](LICENSE) for details.
