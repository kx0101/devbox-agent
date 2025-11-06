local uv = require("luv")

local function get_git_root()
    local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
    if not handle then
        return nil
    end

    local root = handle:read("*l")
    handle:close()

    return root
end

local function get_file_diffs(base)
    base = base or "origin/develop"
    local root = get_git_root()
    if not root then
        error("Not inside a git repository")
    end

    local handle = io.popen("cd " .. root .. " && git diff " .. base .. " --name-only")
    if not handle then
        return {}
    end

    local files = {}
    for path in handle:lines() do
        if path ~= "" then
            local diff_handle = io.popen("cd " .. root .. " && git diff " .. base .. " --no-color -- " .. path)
            local diff = diff_handle and diff_handle:read("*a") or ""
            if diff_handle then
                diff_handle:close()
            end

            local abs_path = root .. "/" .. path
            local f = io.open(abs_path, "r")
            local content = f and f:read("*a") or ""
            if f then
                f:close()
            end

            table.insert(files, {
                Path = path,
                Diff = diff,
                Content = content,
            })
        end
    end

    handle:close()

    return files
end

local function get_review_payload(base)
    return { Files = get_file_diffs(base) }
end

local function get_visual_selection()
    local s = vim.fn.getpos("'<")
    local e = vim.fn.getpos("'>")
    local lines = vim.fn.getline(s[2], e[2])

    if #lines == 0 then
        return nil
    end

    lines[#lines] = string.sub(lines[#lines], 1, e[3])
    lines[1] = string.sub(lines[1], s[3])

    return table.concat(lines, "\n")
end

local function create_floating_win(title)
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
        title = title or "DevBox",
        title_pos = "center",
    })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Thinking..." })
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_win_set_option(win, "wrap", true)
    vim.api.nvim_win_set_option(win, "linebreak", true)
    vim.api.nvim_win_set_option(win, "breakindent", true)

    return buf, win
end

local function start_spinner(buf, label)
    local timer = uv.new_timer()
    local dots = 0

    local function stop()
        if not timer or timer:is_closing() then
            return
        end

        pcall(function()
            timer:stop()
            timer:close()
        end)
    end

    timer:start(0, 300, vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(buf) then
            stop()
            return
        end

        local ok, mod = pcall(vim.api.nvim_buf_get_option, buf, "modifiable")
        if not ok or not mod then
            stop()
            return
        end

        dots = (dots + 1) % 4
        pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, { label .. string.rep(".", dots) })
    end))

    return stop
end

local function handle_stream(buf, stream_fn)
    local first_chunk, lines = true, {}
    local stop_spinner = start_spinner(buf, "Thinking")

    stream_fn(function(chunk)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
                stop_spinner()
                return
            end

            if chunk:find("%[DONE%]") then
                stop_spinner()
                vim.api.nvim_buf_set_option(buf, "modifiable", false)
                return
            end

            if first_chunk then
                first_chunk = false
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
            end

            table.insert(lines, chunk)
            local formatted = vim.split(table.concat(lines), "\n", { plain = true })

            pcall(function()
                vim.api.nvim_buf_set_option(buf, "modifiable", true)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
                vim.api.nvim_buf_set_option(buf, "modifiable", false)
            end)
        end)
    end)
end

return {
    get_git_root = get_git_root,
    get_file_diffs = get_file_diffs,
    get_review_payload = get_review_payload,
    get_visual_selection = get_visual_selection,
    create_floating_win = create_floating_win,
    handle_stream = handle_stream,
}
