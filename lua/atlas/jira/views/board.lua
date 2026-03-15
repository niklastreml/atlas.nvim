local M = {}

function M.build()
	return {
		columns = {
			{ key = "key", title = "Key", width = 14 },
			{ key = "summary", title = "Summary", width = 48 },
			{ key = "status", title = "Status", width = 12 },
		},
		rows = {
			{ key = "JIRA-1", summary = "Fake Jira row", status = "TODO" },
		},
	}
end

return M
