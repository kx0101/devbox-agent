local M = {}
local endpoint = "http://localhost:8080/ask"

function M.ask(prompt, context, on_chunk)
    local json = require("dkjson")
    local body = json.encode({
        message = prompt,
        cwd = context and context.cwd or os.getenv("PWD"),
        filetype = context and context.filetype or nil,
        selection = context and context.selection or nil,
    })

    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)

    local handle
    handle = vim.loop.spawn("curl", {
        args = { "-s", "-N", "-X", "POST",
            "-H", "Content-Type: application/json",
            "-d", body, endpoint },
        stdio = { nil, stdout, stderr },
    }, function(_code, _signal)
        stdout:close();
        stderr:close()
        handle:close()
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
