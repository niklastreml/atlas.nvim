---@class AtlasJiraViewConfig : AtlasIssuesViewConfig
---@field jql string

---@class AtlasJiraCustomFieldConfig
---@field name string
---@field format fun(value: any): string|nil
---@field hl_group string|nil
---@field display "table"|"chip"|nil

---@class AtlasJiraIssuesConfig
---@field base_url string
---@field email string
---@field token string
---@field cache_ttl number|nil
---@field views AtlasJiraViewConfig[]|nil
---@field project_config table<string, table<string, AtlasJiraCustomFieldConfig>>|nil
