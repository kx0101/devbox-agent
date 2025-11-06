#!/usr/bin/env lua

local devbox = require('devbox')

local args = table.concat(arg, " ")
if args == "" then
    print("Usage: devbox <prompt>")
    os.exit(1)
end

print(devbox.ask(args))
