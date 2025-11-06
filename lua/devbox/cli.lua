#!/usr/bin/env lua

local devbox = require("devbox.core")
local luv = require("luv")

local args = table.concat(arg, " ")
if args == "" then
    print("Usage: devbox <prompt>")
    os.exit(1)
end

devbox.ask(args, nil, function(chunk)
    io.write(chunk)
    io.flush()
end)

luv.run()
