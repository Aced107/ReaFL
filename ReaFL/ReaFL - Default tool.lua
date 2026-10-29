-- @noindex
-- ReaFL - Default tool: normal REAPER mouse behaviour. Shortcut: 1
local FLT = dofile(debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") .. "lib/reafl_core.lua")
FLT.set_action_options(1 | 2)   -- pressing again quickly never asks "terminate instances?"
FLT.activate("default")
FLT.no_undo()
