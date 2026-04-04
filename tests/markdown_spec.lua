if _G.vim == nil then
	_G.vim = {
		split = function(s, sep, opts)
			local plain = opts and opts.plain
			local result = {}
			local from = 1
			while true do
				local start, finish = s:find(sep, from, plain)
				if not start then
					table.insert(result, s:sub(from))
					break
				end
				table.insert(result, s:sub(from, start - 1))
				from = finish + 1
			end
			return result
		end,
	}
end

local md = require("atlas.jira.converted.markdown")

--- Helper: wraps content nodes in a full ADF doc
local function doc(content)
	return { type = "doc", version = 1, content = content }
end

local function p(nodes)
	return { type = "paragraph", content = nodes }
end

local function text(t, marks)
	return { type = "text", text = t, marks = marks }
end

describe("markdown to adf", function()
	describe("paragraph", function()
		it("converts plain text", function()
			assert.are.same(doc({ p({ text("hello world") }) }), md.to_adf("hello world"))
		end)

		it("separates paragraphs by blank lines", function()
			assert.are.same(doc({ p({ text("first") }), p({ text("second") }) }), md.to_adf("first\n\nsecond"))
		end)
	end)

	describe("inline marks", function()
		it("converts bold", function()
			assert.are.same(
				doc({ p({ text("bold", { { type = "strong" } }) }) }),
				md.to_adf("**bold**")
			)
		end)

		it("converts italic", function()
			assert.are.same(
				doc({ p({ text("italic", { { type = "em" } }) }) }),
				md.to_adf("*italic*")
			)
		end)

		it("converts inline code", function()
			assert.are.same(
				doc({ p({ text("code", { { type = "code" } }) }) }),
				md.to_adf("`code`")
			)
		end)

		it("converts strikethrough", function()
			assert.are.same(
				doc({ p({ text("gone", { { type = "strike" } }) }) }),
				md.to_adf("~~gone~~")
			)
		end)

		it("converts link", function()
			assert.are.same(
				doc({ p({ text("click", { { type = "link", attrs = { href = "https://example.com" } } }) }) }),
				md.to_adf("[click](https://example.com)")
			)
		end)
	end)

	describe("mention", function()
		it("converts mention with id", function()
			assert.are.same(
				doc({ p({ { type = "mention", attrs = { id = "abc", text = "@user", accessLevel = "" } } }) }),
				md.to_adf("[@user]{mention:abc}")
			)
		end)
	end)

	describe("date", function()
		it("converts date link", function()
			assert.are.same(
				doc({ p({ { type = "date", attrs = { timestamp = "1609459200000" } } }) }),
				md.to_adf("[2021-01-01](atlas-date:1609459200000)")
			)
		end)
	end)

	describe("heading", function()
		it("converts h1", function()
			assert.are.same(
				doc({ { type = "heading", attrs = { level = 1 }, content = { text("Title") } } }),
				md.to_adf("# Title")
			)
		end)

		it("converts h3", function()
			assert.are.same(
				doc({ { type = "heading", attrs = { level = 3 }, content = { text("Sub") } } }),
				md.to_adf("### Sub")
			)
		end)
	end)

	describe("codeBlock", function()
		it("converts with language", function()
			assert.are.same(
				doc({ { type = "codeBlock", attrs = { language = "lua" }, content = { { type = "text", text = "print('hi')" } } } }),
				md.to_adf("```lua\nprint('hi')\n```")
			)
		end)

		it("converts without language", function()
			assert.are.same(
				doc({ { type = "codeBlock", content = { { type = "text", text = "code" } } } }),
				md.to_adf("```\ncode\n```")
			)
		end)
	end)

	describe("blockquote", function()
		it("converts quoted line", function()
			assert.are.same(
				doc({ { type = "blockquote", content = { p({ text("quoted") }) } } }),
				md.to_adf("> quoted")
			)
		end)
	end)

	describe("bulletList", function()
		it("converts items", function()
			assert.are.same(
				doc({
					{
						type = "bulletList",
						content = {
							{ type = "listItem", content = { p({ text("a") }) } },
							{ type = "listItem", content = { p({ text("b") }) } },
						},
					},
				}),
				md.to_adf("* a\n* b")
			)
		end)
	end)

	describe("orderedList", function()
		it("converts numbered items", function()
			assert.are.same(
				doc({
					{
						type = "orderedList",
						content = {
							{ type = "listItem", content = { p({ text("first") }) } },
							{ type = "listItem", content = { p({ text("second") }) } },
						},
					},
				}),
				md.to_adf("1. first\n2. second")
			)
		end)
	end)

	describe("rule", function()
		it("converts horizontal rule", function()
			assert.are.same(
				doc({ p({ text("above") }), { type = "rule" }, p({ text("below") }) }),
				md.to_adf("above\n\n---\n\nbelow")
			)
		end)
	end)

	describe("table", function()
		it("converts table with header and rows", function()
			assert.are.same(
				doc({
					{
						type = "table",
						content = {
							{
								type = "tableRow",
								content = {
									{ type = "tableHeader", content = { p({ text("A") }) } },
									{ type = "tableHeader", content = { p({ text("B") }) } },
								},
							},
							{
								type = "tableRow",
								content = {
									{ type = "tableCell", content = { p({ text("1") }) } },
									{ type = "tableCell", content = { p({ text("2") }) } },
								},
							},
						},
					},
				}),
				md.to_adf("| A | B |\n| --- | --- |\n| 1 | 2 |")
			)
		end)
	end)

	describe("empty input", function()
		it("handles empty string", function()
			assert.are.same(doc({}), md.to_adf(""))
		end)

		it("handles nil", function()
			assert.are.same(doc({}), md.to_adf(nil))
		end)
	end)
end)
