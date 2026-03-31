local M = {
	worklogs = nil,
	line_map = {},
}

function M.reset()
	M.worklogs = nil
	M.line_map = {}
end

return M
