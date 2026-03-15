local M = {}

---@param method string HTTP method (GET, POST, PUT, DELETE)
---@param url string Full URL
---@param headers table<string, string> HTTP headers
---@param data? string JSON data for POST/PUT
---@param callback fun(result?: table, err?: string)
function M.curl_request(method, url, headers, data, callback)
	local header_args = {}
	for key, value in pairs(headers) do
		table.insert(header_args, string.format('-H "%s: %s"', key, value))
	end
	local header_str = table.concat(header_args, " ")

	local cmd
	if data then
		cmd = string.format("curl -s -X %s %s -d '%s' \"%s\"", method, header_str, data, url)
	else
		cmd = string.format('curl -s -X %s %s "%s"', method, header_str, url)
	end

	local out = {}
	local err_out = {}

	vim.fn.jobstart(cmd, {
		on_stdout = function(_, response)
			if response then
				vim.list_extend(out, response)
			end
		end,
		on_stderr = function(_, response)
			if response then
				vim.list_extend(err_out, response)
			end
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				if #out == 0 then
					callback(nil, "Empty response from server")
					return
				end

				if code ~= 0 then
					local err = "curl exited with code " .. code
					if #err > 0 then
						err = err .. ": " .. table.concat(err, "\n")
					end
					callback(nil, err)
					return
				end
			end)

			local raw = table.concat(out, "\n")
			local ok, result = pcall(vim.json.decode, raw)
			if not ok then
				callback(nil, "Failed to parse JSON: " .. tostring(result) .. "\nRaw: " .. raw:sub(1, 200))
				return
			end

			callback(result, nil)
		end,
	})
end

return M
