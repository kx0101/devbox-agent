local M = {}
local endpoint = "http://localhost:8080/ask"

local uv
if rawget(_G, "vim") and vim.loop then
    uv = vim.loop
else
    uv = require("luv")
end

function M.ask(prompt, context, on_chunk)
    local json = require("dkjson")
    local body = json.encode({
        message = prompt,
        cwd = context and context.cwd or os.getenv("PWD"),
        filetype = context and context.filetype or nil,
        selection = context and context.selection or nil,
    })

    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local handle
    handle = uv.spawn("curl", {
        args = {
            "-s",
            "-N",
            "-X",
            "POST",
            "-H", "Content-Type: application/json",
            "-d", body, endpoint
        },
        stdio = {
            nil,
            stdout,
            stderr
        },
    }, function(_code, _signal)
        stdout:close();
        stderr:close()
        handle:close()
        uv:stop()
    end)

    stdout:read_start(function(err, data)
        assert(not err, err)

        if data and on_chunk then
            on_chunk(data)
        end
    end)

    stderr:read_start(function(_, _) end)
end

return M
