local devbox = require("devbox.core")
local util_ok, util = pcall(require, "devbox.util")
local env = require("devbox.env")

return function(args)
    local in_nvim = env.is_nvim()
    local selection

    if in_nvim and util_ok then
        selection = util.get_visual_selection()
        if not selection or selection == "" then
            env.error("No selection detected")
            return
        end

        local buf = util.create_floating_win("DevBox: Explain")
        util.handle_stream(buf, function(on_chunk)
            devbox.ask("Explain this code:\n" .. selection, { filetype = vim.bo.filetype }, on_chunk)
        end)

        return
    end

    local code = table.concat(args, " ")
    if code == "" then
        env.error("Usage: devbox explain <code snippet>")
        return
    end

    devbox.ask("Explain this code:\n" .. code, nil, function(chunk)
        io.write(chunk)
        io.flush()
    end)
end
