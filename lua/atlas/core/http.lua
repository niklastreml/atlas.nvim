local M = {}

---@param method string HTTP method (GET, POST, PUT, DELETE)
---@param url string Full URL
---@param headers table<string, string> HTTP headers
---@param data? string JSON data for POST/PUT
---@param callback fun(result?: table, err?: string)
---@return { job_id: integer, cancel: fun() }
function M.curl_request(method, url, headers, data, callback)
	local header_args = {}
	for key, value in pairs(headers or {}) do
		table.insert(header_args, string.format('-H "%s: %s"', key, value))
	end
	local header_str = table.concat(header_args, " ")

	local cmd
	if data then
		cmd = string.format(
			"curl -sS -X %s %s -d '%s' -w '__ATLAS_HTTP_CODE:%%{http_code}' \"%s\"",
			method,
			header_str,
			data,
			url
		)
	else
		cmd = string.format('curl -sS -X %s %s -w "__ATLAS_HTTP_CODE:%%{http_code}" "%s"', method, header_str, url)
	end

	local out = {}
	local err_out = {}

	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
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
				local raw = table.concat(out, "")
				local stderr_text = table.concat(err_out, "")

				if code ~= 0 then
					local err = "curl exited with code " .. tostring(code)
					if stderr_text ~= "" then
						err = err .. ": " .. stderr_text
					end
					callback(nil, err)
					return
				end

				if raw == "" then
					callback(nil, "Empty response from server")
					return
				end

				local body = raw
				local http_status = nil
				local marker_start, marker_end, status_str = raw:find("__ATLAS_HTTP_CODE:(%d+)%s*$")
				if marker_start ~= nil then
					body = raw:sub(1, marker_start - 1)
					http_status = tonumber(status_str)
				end

				if body == "" then
					if http_status ~= nil and http_status >= 200 and http_status < 300 then
						callback({ __http_status = http_status }, nil)
						return
					end
					callback(nil, string.format("HTTP %s", tostring(http_status or "?")))
					return
				end

				local ok, result = pcall(vim.json.decode, body)
				if not ok then
					callback(
						nil,
						"Failed to parse JSON: "
							.. tostring(result)
							.. "\nStatus: "
							.. tostring(http_status or "?")
							.. "\nRaw: "
							.. body
					)
					return
				end

				if type(result) == "table" then
					result.__http_status = http_status
				end

				callback(result, nil)
			end)
		end,
	})

	return {
		job_id = job_id,
		cancel = function()
			if job_id and job_id > 0 then
				pcall(vim.fn.jobstop, job_id)
			end
		end,
	}
end

return M
