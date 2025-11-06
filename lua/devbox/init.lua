local devbox = require("devbox.core")
local M = {}

local function get_visual_selection()
    local s = vim.fn.getpos("'<")
    local e = vim.fn.getpos("'>")
    local lines = vim.fn.getline(s[2], e[2])

    if #lines == 0 then return nil end

    lines[#lines] = string.sub(lines[#lines], 1, e[3])
    lines[1]      = string.sub(lines[1], s[3])

    return table.concat(lines, "\n")
end

local function explain_selection()
    local selection = get_visual_selection()
    if not selection or selection == "" then
        print("No selection detected."); return
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local w, h = math.floor(vim.o.columns * 0.85), math.floor(vim.o.lines * 0.85)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = w,
        height = h,
        row = math.floor((vim.o.lines - h) / 2),
        col = math.floor((vim.o.columns - w) / 2),
        style = "minimal",
        border = "rounded",
    })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Waiting for DevBox..." })
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_win_set_option(win, "wrap", true)
    vim.api.nvim_win_set_option(win, "linebreak", true)
    vim.api.nvim_win_set_option(win, "breakindent", true)

    local dots, timer = 0, vim.loop.new_timer()
    timer:start(0, 300, vim.schedule_wrap(function()
        dots = (dots + 1) % 4

        if not vim.api.nvim_buf_is_valid(buf) then
            timer:stop();
            timer:close();

            return
        end

        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "Waiting for DevBox" .. string.rep(".", dots) })
    end))

    local first_chunk = true
    local line_accum = {}

    local context = {
        cwd = vim.fn.getcwd(),
        filetype = vim.bo.filetype,
        selection = selection,
    }

    devbox.ask("Explain this code:\n" .. selection, context, function(chunk)
        vim.schedule(function()
            if first_chunk then
                timer:stop();
                timer:close()

                vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

                first_chunk = false
            end

            table.insert(line_accum, chunk)

            local text = table.concat(line_accum)
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n"))
            end
        end)
    end)
end

function M.setup()
    vim.keymap.set("v", "<leader>d", explain_selection, { desc = "Explain code with DevBox" })
    vim.api.nvim_create_user_command("DevboxExplain", explain_selection, { range = true })
end

return M
