local M = {}

function M.is_nvim()
    return type(vim) == "table" and vim.api ~= nil and vim.fn ~= nil
end

function M.print(msg)
    if M.is_nvim() then
        vim.notify(msg, vim.log.levels.INFO)
    else
        print(msg)
    end
end

function M.error(msg)
    if M.is_nvim() then
        vim.notify(msg, vim.log.levels.ERROR)
    else
        io.stderr:write(msg .. "\n")
    end
end

return M
