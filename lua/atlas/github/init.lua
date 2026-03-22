local M = {}

function M.setup() end
local footer = require("atlas.ui.components.footer")

footer.clear_items("github")
---TODO: add better options. This is just for testing.
footer.register_item("github", { text = "PRs", hl_group = "AtlasFooterText" })
footer.register_item("github", { text = "|", hl_group = "AtlasFooterMuted" })
footer.register_item("github", { text = "r refresh", hl_group = "AtlasFooterText" })

return M
