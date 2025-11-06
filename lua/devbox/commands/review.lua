local devbox = require("devbox.core")
local util_ok, util = pcall(require, "devbox.util")
local env = require("devbox.env")

return function(_args)
    local in_nvim = env.is_nvim()

    if in_nvim and util_ok then
        local buf = util.create_floating_win("DevBox: Review")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Collecting git diffs..." })

        local ok, payload = pcall(util.get_review_payload, "origin/develop")
        if not ok then
            env.error("Error: " .. payload)
            return
        end

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Requesting review..." })
        util.handle_stream(buf, function(on_chunk)
            devbox.review(payload, on_chunk)
        end)

        return
    end

    if not util_ok then
        env.error("Review requires util.lua")
        return
    end

    local payload = util.get_review_payload()
    devbox.review(payload, function(chunk)
        io.write(chunk)
        io.flush()
    end)
end
