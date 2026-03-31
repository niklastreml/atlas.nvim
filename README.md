# Atlas.nvim

A Neovim plugin for managing Bitbucket PRs and Jira issues without leaving your editor.

> [!CAUTION]
> **Still in early development, will have breaking changes!**

<img width="2541" height="1365" alt="CleanShot 2026-03-31 at 02 54 23" src="https://github.com/user-attachments/assets/931ec50b-a0ca-4321-9326-3d53aea2432f" />

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
              { workspace = "your-workspace", repo = "atlas" },
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

### Custom Actions

You can add custom PR actions under `bitbucket.custom_actions`.

`ctx` includes:

- `repo_path` (resolved local path or `nil`)
- `workspace`
- `repo`
- `source_branch`
- `target_branch`
- `pr_id`
- `pr_url`

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
      ---@param pr BitbucketPR
      ---@param ctx table
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

### Features

- [x] Multiple Bitbucket views
- [x] PR tabs: overview, activity, comments, commits, files
- [x] PR actions: merge, approve, request changes
- [x] Add custom actions to PRs
- [x] Resolve and checkout PR branches locally
- [ ] Pagination for API results (PRs, comments, commits, files, activity)
- [ ] Bulk actions: approve/request changes on multiple PRs at once
- [ ] PR files: fuzzy filter changed files by path

<img width="2532" height="1366" alt="CleanShot 2026-03-31 at 02 51 32" src="https://github.com/user-attachments/assets/d08dde1f-8bae-446f-8db1-a9f53b118fad" />

## Jira

> [!NOTE]
Inspired by [jira.nvim](https://github.com/letieu/jira.nvim) since it fitted nicely in this here. I highly recommend checking out the original project for a more general-purpose solution.

### Configuration

```lua
return {
  "emrearmagan/atlas.nvim",
  config = function()
    require("atlas").setup({
    })
  end,
}
```

### Commands

- `:AtlasBitbucket` - Open Bitbucket PR picker
- `:AtlasLogs` - Toggle Atlas logs

### Keymaps

### Main UI

| Context | Key | Action |
|---|---|---|
| Global | `q` | Close Atlas |
| Global | `j` / `k` | Move cursor |
| Global | `gg` / `G` | First / last item |
| Global | `[` / `]` | Previous / next panel tab |
| Bitbucket | `p` | Toggle PR panel (or switch to PR panel) |
| Bitbucket | `o` | Toggle repository panel (or switch to repository panel) |

### Bitbucket

| Key | Action |
|---|---|
| `R` | Refresh current Bitbucket view |
| `r` | Refetch selected PR |
| `a` | Open PR actions |
| `gx` | Open PR in browser |
| `y` | Copy PR id |
| `Y` | Copy PR URL |
| `/` | Search repositories |


## License

MIT License - see [LICENSE](LICENSE) for details.
