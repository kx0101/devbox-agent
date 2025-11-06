local devbox = require("devbox.core")
local util = require("devbox.util")
local help = require("devbox.commands.help")

local M = {}

local function explain_selection()
    local selection = util.get_visual_selection()
    if not selection or selection == "" then
        print("No selection detected")
        return
    end

    local buf = util.create_floating_win("DevBox: Explain")
    local context = { cwd = vim.fn.getcwd(), filetype = vim.bo.filetype, selection = selection }

    util.handle_stream(buf, function(on_chunk)
        devbox.ask("Explain this code:\n" .. selection, context, on_chunk)
    end)
end

local function review_repo()
    local buf = util.create_floating_win("DevBox: Review")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Collecting git diffs..." })
    local ok, payload = pcall(util.get_review_payload, "origin/develop")
    if not ok then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Error: " .. payload })
        return
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Requesting review..." })
    util.handle_stream(buf, function(on_chunk)
        devbox.review(payload, on_chunk)
    end)
end

function M.setup()
    vim.keymap.set("v", "<leader>d", explain_selection, { desc = "Explain code with DevBox" })
    vim.keymap.set("n", "<leader>p", review_repo, { desc = "Review repo with DevBox" })
    vim.keymap.set("n", "<leader>h", help, { desc = "Ask HelpBox" })

    vim.api.nvim_create_user_command("DevboxExplain", explain_selection, { range = true })
    vim.api.nvim_create_user_command("DevboxReview", review_repo, {})
    vim.api.nvim_create_user_command("DevboxHelp", help, {})
end

return M
