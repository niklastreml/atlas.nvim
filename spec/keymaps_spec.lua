if _G.vim == nil then
	_G.vim = {}
end

vim.env = vim.env or {}

local config = require("atlas.config")
local keymaps = require("atlas.core.keymaps")

local function deep_copy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deep_copy(v)
	end
	return copy
end

local default_keymaps = {
	ui = {
		toggle_panel = "p",
		next_panel_tab = { "]", "<Tab>" },
		refresh = "r",
	},
	jira = {
		open_actions = "A",
		search = "/",
		refresh_tab = "r",
	},
	bitbucket = {
		checkout_pr = "gc",
		open_diffview = "gd",
		refresh_tab = "r",
		pr_files_toggle_fold = "za",
		pr_files_next_hunk = "]h",
		pr_files_previous_hunk = "[h",
	},
}

describe("atlas keymaps resolver", function()
	before_each(function()
		config.options.keymaps = deep_copy(default_keymaps)
	end)

	it("resolves single-key mapping", function()
		assert.are.same({ "p" }, keymaps.resolve("ui.toggle_panel"))
	end)

	it("resolves aliases for list mapping", function()
		assert.are.same({ "]", "<Tab>" }, keymaps.resolve("ui.next_panel_tab"))
	end)

	it("returns nil when keymap is disabled", function()
		config.options.keymaps.ui.toggle_panel = false
		assert.is_nil(keymaps.resolve("ui.toggle_panel"))
	end)

	it("supports alias and disable patterns used by ui modules", function()
		config.options.keymaps.ui.next_panel_tab = { "]", "<Tab>", "gn" }
		config.options.keymaps.ui.refresh = false

		local aliases = keymaps.resolve("ui.next_panel_tab")
		local disabled = keymaps.resolve("ui.refresh")

		assert.are.same({ "]", "<Tab>", "gn" }, aliases)
		assert.is_nil(disabled)
	end)

	it("resolves jira and bitbucket picker action IDs", function()
		assert.are.same({ "A" }, keymaps.resolve("jira.open_actions"))
		assert.are.same({ "/" }, keymaps.resolve("jira.search"))
		assert.are.same({ "gc" }, keymaps.resolve("bitbucket.checkout_pr"))
		assert.are.same({ "gd" }, keymaps.resolve("bitbucket.open_diffview"))
	end)

	it("resolves panel action IDs", function()
		assert.are.same({ "r" }, keymaps.resolve("jira.refresh_tab"))
		assert.are.same({ "r" }, keymaps.resolve("bitbucket.refresh_tab"))
		assert.are.same({ "gc" }, keymaps.resolve("bitbucket.checkout_pr"))
	end)

	it("resolves bitbucket pr-files action IDs", function()
		assert.are.same({ "za" }, keymaps.resolve("bitbucket.pr_files_toggle_fold"))
		assert.are.same({ "]h" }, keymaps.resolve("bitbucket.pr_files_next_hunk"))
		assert.are.same({ "[h" }, keymaps.resolve("bitbucket.pr_files_previous_hunk"))
	end)

	it("returns nil for missing or disabled mappings", function()
		config.options.keymaps.bitbucket.pr_files_toggle_fold = false
		assert.is_nil(keymaps.resolve("bitbucket.pr_files_toggle_fold"))
		assert.is_nil(keymaps.resolve("jira.does_not_exist"))
	end)
end)
