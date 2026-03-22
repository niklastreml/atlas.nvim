local M = {}

function M.setup() end
local footer = require("atlas.ui.components.footer")

footer.clear_items("bitbucket")
---TODO: add better options. This is just for testing.
footer.register_item("bitbucket", { text = "PRs", hl_group = "AtlasFooterText" })
footer.register_item("bitbucket", { text = "|", hl_group = "AtlasFooterMuted" })
footer.register_item("bitbucket", { text = "r refresh", hl_group = "AtlasFooterText" })

return M
