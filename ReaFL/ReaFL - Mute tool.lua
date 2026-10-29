-- @noindex
-- ReaFL - Mute tool (FL Studio style). Shortcut: T
--   Left click on an item:  toggle that item's mute (selection untouched)
--   Double-click:           two toggles = no net change (like FL); no MIDI editor
--   Right click on an item: delete that item
--   Ctrl/Alt + click, and clicks off items: normal REAPER behaviour
-- Stays running in the background while the tool is active (needs js_ReaScriptAPI).
local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local FLT = dofile(dir .. "lib/reafl_core.lua")
FLT.set_action_options(1 | 2)   -- re-running restarts cleanly instead of asking
if FLT.activate("mute") == "mute" then
  local run_engine = assert(loadfile(dir .. "lib/reafl_engine.lua"))(FLT)
  reaper.defer(function() run_engine("mute") end)  -- defer: no "ReaScript: Run" undo point
else
  FLT.no_undo()
end
