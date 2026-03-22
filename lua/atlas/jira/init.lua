local M = {}

function M.setup() end
local footer = require("atlas.ui.components.footer")

footer.clear_items("jira")

---TODO: add better options. This is just for testing.
footer.register_item("jira", { text = "PRs", hl_group = "AtlasFooterText" })
footer.register_item("jira", { text = "|", hl_group = "AtlasFooterMuted" })
footer.register_item("jira", { text = "r refresh", hl_group = "AtlasFooterText" })

return M
