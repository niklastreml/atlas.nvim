local M = {
	comments = nil,
	line_map = {},
}

function M.reset()
	M.comments = nil
	M.line_map = {}
end

return M
