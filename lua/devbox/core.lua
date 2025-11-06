local json = require("dkjson")
local uv = rawget(_G, "vim") and vim.loop or require("luv")

local M = {}

M.config = {
    endpoint = "http://localhost:8080"
}

local function spawn_curl(url, body, on_chunk)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local handle
    handle = uv.spawn("curl", {
        args = {
            "-sS", "--no-buffer",
            "-X",
            "POST",
            "-H", "Content-Type: application/json",
            "-d", body,
            url
        },
        stdio = {
            nil,
            stdout,
            stderr
        },
    }, function(_code, _signal)
        stdout:read_stop()
        stderr:read_stop()

        stdout:close()
        stderr:close()
        handle:close()
    end)

    stdout:read_start(function(err, data)
        assert(not err, err)

        if data and on_chunk then
            on_chunk(data)
        end
    end)

    stderr:read_start(function(_, data)
        if data then
            io.stderr:write(data)
        end
    end)
end

--- unified async request
--- @param path string the backend endpoint, e.g. "/ask" "/review"
--- @param payload table|string payload
--- @param on_chunk function callback for each chunk of data received
function M.request(path, payload, on_chunk)
    local body = type(payload) == "string" and payload or json.encode(payload)
    local url = M.config.endpoint .. path

    spawn_curl(url, body, on_chunk)
end

function M.ask(prompt, context, on_chunk)
    local payload = {
        message = prompt,
        context = context or {},
        filetype = context and context.filetype or nil,
        selection = context and context.selection or nil,
    }

    M.request("/ask", payload, on_chunk)
end

function M.review(payload, on_chunk)
    M.request("/review", payload, on_chunk)
end

function M.setup(opts)
    if opts and opts.endpoint then
        M.config.endpoint = opts.endpoint
    end
end

return M
