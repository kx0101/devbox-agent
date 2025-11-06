#!/usr/bin/env lua

local luv = require("luv")

local command_name = arg[1]
if not command_name then
    print("Usage: devbox <command> [args]")
    os.exit(1)
end

table.remove(arg, 1)

local ok, command = pcall(require, "devbox.commands." .. command_name)
if not ok or type(command) ~= "function" then
    io.stderr:write("Unknown command: " .. tostring(command_name) .. "\n")
    os.exit(1)
end

command(arg)
luv.run()
