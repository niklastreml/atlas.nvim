---@class AtlasJiraViewConfig : AtlasIssuesViewConfig
---@field jql string

---@class AtlasJiraCustomFieldConfig
---@field name string
---@field format fun(value: any): string|nil
---@field hl_group string|nil
---@field display "chip"|"table"|nil

---@class AtlasJiraProjectConfig
---@field story_points_field string|nil
---[project_key] AtlasJiraCustomFieldConfig

---@class AtlasJiraIssuesConfig
---@field base_url string
---@field email string
---@field token string
---@field cache_ttl number|nil
---@field views AtlasJiraViewConfig[]|nil
---@field project_config AtlasJiraProjectConfig|nil
