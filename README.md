[![Neovim](https://img.shields.io/badge/Neovim-0.10+-blue.svg)](https://neovim.io/)
[![Version](https://img.shields.io/github/v/tag/emrearmagan/atlas.nvim.svg)](https://github.com/emrearmagan/atlas.nvim/tags)
[![Tests](https://github.com/emrearmagan/atlas.nvim/actions/workflows/main.yml/badge.svg)](https://github.com/emrearmagan/atlas.nvim/actions/workflows/main.yml)
[![License](https://img.shields.io/github/license/emrearmagan/atlas.nvim?style=flat-square&color=blue)](LICENSE)

# Atlas.nvim

A Neovim plugin for managing Bitbucket PRs and Jira issues without leaving your editor.

> [!CAUTION]
> **Still in early development, will have breaking changes!**

<img src="https://github.com/user-attachments/assets/3da6e584-47a1-411e-91f6-110dbdc75293"/>
<img src="https://github.com/user-attachments/assets/80eeb59a-4a04-40e0-90fb-92ac5d4da249"/>

## Table of Contents

- [Installation](#installation)
- [Jira](#jira)
- [Bitbucket](#bitbucket)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "emrearmagan/atlas.nvim",
  dependencies = {
    "MeanderingProgrammer/render-markdown.nvim", -- optional but recommended (Jira)
    "sindrets/diffview.nvim", -- optional (Bitbucket PR diff)
    "esmuellert/codediff.nvim", -- optional (Bitbucket PR diff alternative)
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

## Requirements

- Neovim: `0.10+`
- Jira: Jira Cloud REST API v3 (`*.atlassian.net`)
- Bitbucket: Bitbucket Cloud REST API 2.0 (`api.bitbucket.org`)

> [!NOTE]
> I have only tested this with my personal and work accounts. If you encounter any issues, please feel free to open an issue.
> See: https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/

## Commands

- `:AtlasJira` - Open Jira issue picker
- `:AtlasJqlSearch {query}` - Search Jira issues with JQL
- `:AtlasBitbucket` - Open Bitbucket PR picker
- `:AtlasClearCache` - Clear Atlas disk and memory cache
- `:AtlasLogs` - Toggle Atlas logs

## Jira

- [x] Create and Edit issues
- [x] View and edit issues as markdown -> ADF conversion for issue descriptions (experimental)
- [x] Issue panel tabs: overview, comments, history
- [x] Jira actions: transition, change assignee, change reporter, edit title
- [x] Comment workflows (create, reply, edit, delete)
- [x] Search issues
- [x] JQL support and completion
- [x] Support for custom fields
- [x] Create and edit issue templates
- [ ] Save JQL queries as custom views
- [ ] Save and filter issues

> [!IMPORTANT]
> The markdown editor for issue descriptions and comments is still experimental and may not work perfectly in all cases. You can toggle between markdown and ADF view in the overview tab to see the raw ADF content and how it translates to markdown. If you encounter any issues with the markdown editor, please open an issue with details.

<div>
    <img width = "49%" alt="Edit/Create Issue" src="https://github.com/user-attachments/assets/76913fbf-1667-4f35-9962-d3c1b4619c7f" />
    <img width = "49%"alt="Jira Panel" src="https://github.com/user-attachments/assets/e188582e-f784-46a8-aacd-ac989054c378" />
</div>

### Configuration

```lua
return {
  "emrearmagan/atlas.nvim",
  config = function()
    require("atlas").setup({
      ---@type JiraConfig
      jira = {
        base_url = "https://your-site.atlassian.net",
        email = "you@example.com",
        --- See: https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/
        token = "your_jira_api_token",
        cache_ttl = 300,
        max_result = 100,
        resolve_parent_issues = true,

        project_config = {
          KAN = {
            customfield_10003 = {
              name = "Approvers",
              format = function(value)
                if type(value) ~= "table" or #value == 0 then
                  return nil -- nil hides the field
                end

                return table.concat(value, ", ")
              end,
              hl_group = "AtlasChipActive",
              display = "chip", -- "chip" (default) or "table"
            },
          },
        },

        ---@type JiraViewConfig[]
        views = {
          {
            name = "My Board",
            key = "M",
            jql = "project = KAN AND assignee = currentUser() ORDER BY updated DESC",
          },
          {
            name = "Team Board",
            key = "T",
            jql = "project = KAN ORDER BY updated DESC",
          },
        },
      },
    })
  end,
}
```

### JQL Search Command

Use `:AtlasJqlSearch` to run JQL directly from command mode. It also supports command-line completion while typing the query.

Examples:

```vim
:AtlasJqlSearch project = KAN AND assignee = currentUser() ORDER BY updated DESC
:AtlasJqlSearch summary ~ "login bug"
```

## Bitbucket

#### Features

- [x] Multiple Bitbucket views
- [x] PR tabs: overview, activity, comments, commits, files
- [x] PR actions: merge, approve, request changes
- [x] Comment workflows (create, reply, edit, delete)
- [x] Add custom actions to PRs
- [x] Resolve and checkout PR branches locally
- [x] Open PR diff in given command
- [x] View Repository details like branches, tags, commits
- [ ] Pagination for API results (PRs, comments, commits, files, activity)
- [ ] Switch between open, merged and superseded PRs
- [ ] Bulk actions: approve/request changes on multiple PRs at once
- [ ] Shows pull request checks
- [ ] Support for Bitbucket Server
- [ ] Save and filter pull requests

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
        diff = {
          -- Command must support range input: origin/<destination>...origin/<source>
          open_cmd = "DiffviewOpen", -- e.g. "DiffviewOpen" or "CodeDiff", defaults to nil.
        },
        repo_config = {
          -- Maps `workspace/repo` to local paths. Used for checkout and custom actions.
          paths = {
            ["your-workspace/*"] = "~/code/repos/*",
            ["your-workspace/atlas"] = "~/code/atlas",
          },

          settings = {
            ["your-workspace/atlas"] = {
              readme = "README.md", -- optional, defaults to README.md
            },
          },
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
            name = "Team",
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
  repo_config = {
    paths = {
      ["your-workspace/*"] = "~/code/repos/*",
    },
    settings = {},
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

### Keymaps

Set an action to `false` to disable it, or set it to a list to add aliases.

```lua
require("atlas").setup({
  keymaps = {
    ui = {
      toggle_panel = false,
      next_panel_tab = { "]", "<Tab>", "gn" },
      previous_panel_tab = { "[", "<S-Tab>", "gp" },
    },
    jira = {
      create_issue = "i",
      manage_templates = "gT",
    },
    bitbucket = {
      open_diffview = { "go", "gd" },
    },
  },
})
```

#### General

| Context | Key                     | Action                              |
| ------- | ----------------------- | ----------------------------------- |
| Atlas   | `q`                     | Close Atlas                         |
| Atlas   | `?`                     | Toggle help popup                   |
| Atlas   | `p`                     | Toggle detail pane                  |
| Atlas   | `<S-Tab>`               | Previous panel tab                  |
| Atlas   | `<Tab>`                 | Next panel tab                      |
| Atlas   | `K`                     | Show issue/pr details               |
| Atlas   | `R`                     | Refresh current view                |
| Atlas   | `r`                     | Refresh selected issue/pr           |
| Atlas   | `a/i` / `c` / `e` / `d` | Add / reply / edit / delete comment |

#### Jira

| Context | Key         | Action                       |
| ------- | ----------- | ---------------------------- |
| Jira    | `A`         | Open Jira actions            |
| Jira    | `/`         | Search issues                |
| Jira    | `ge`        | Edit Issue                   |
| Jira    | `gs`        | Transition Issue             |
| Jira    | `ga` / `gr` | Change Assignee and reporter |
| Jira    | `gt`        | Change issue type            |
| Jira    | `gT`        | Open template editor         |
| Jira    | `gx`        | Open issue in browser        |
| Jira    | `c`         | Create issue                 |
| Jira    | `y` / `Y`   | Copy issue key / URL         |
| Jira    | `m`         | Toggle ADF / markdown view   |

#### Bitbucket

| Context                  | Key         | Action                   |
| ------------------------ | ----------- | ------------------------ |
| Bitbucket                | `A`         | Open PR actions          |
| Bitbucket                | `/`         | Search repositories      |
| Bitbucket                | `o`         | Toggle repository panel  |
| Bitbucket                | `gc`        | Checkout selected PR     |
| Bitbucket                | `gd`        | Open selected PR diff    |
| Bitbucket                | `gx`        | Open pr/build in browser |
| Bitbucket                | `y` / `Y`   | Copy PR id / URL         |
| Bitbucket (File changes) | `za`        | Toggle hunk fold         |
| Bitbucket (File changes) | `]h` / `[h` | Next / previous hunk     |

## Contributors ✨

Thanks go to these wonderful people ([emoji key](https://allcontributors.org/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://khanriza.com"><img src="https://avatars.githubusercontent.com/u/51720003?v=4?s=100" width="100px;" alt="Riza Khan"/><br /><sub><b>Riza Khan</b></sub></a><br /><a href="#code-RizaHKhan" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

## License

MIT License - see [LICENSE](LICENSE) for details.
