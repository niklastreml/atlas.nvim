local M = {
	comments = nil, ---@type PullsComment[]|"loading"|string|nil
	activity = nil, ---@type PullsActivityEntry[]|"loading"|string|nil
}

function M.reset()
	M.comments = nil
	M.activity = nil
end

function M.any_loading()
	return M.comments == "loading" or M.activity == "loading"
end

return M
