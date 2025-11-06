local devbox = require("devbox.core")
local util_ok, util = pcall(require, "devbox.util")
local env = require("devbox.env")

return function(args)
    local in_nvim = env.is_nvim()
    local question

    if in_nvim then
        question = vim.fn.input("Ask DevBox (help): ")
    else
        question = table.concat(args or {}, " ")
    end

    if not question or question == "" then
        env.error("Usage: devbox help <question>")
        return
    end

    if in_nvim and util_ok then
        local buf = util.create_floating_win("DevBox: Help")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Thinking about your project..." })

        util.handle_stream(buf, function(on_chunk)
            devbox.request("/help", { question = question, cwd = vim.fn.getcwd() }, on_chunk)
        end)

        return
    end

    devbox.request("/help", { question = question, cwd = os.getenv("PWD") }, function(chunk)
        io.write(chunk)
        io.flush()
    end)
end
