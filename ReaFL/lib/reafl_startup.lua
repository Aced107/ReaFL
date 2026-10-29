-- ReaFL startup init, run from Scripts/__startup.lua (line added by "ReaFL - Setup").
-- Always start in the Default tool: restores your own mouse modifiers and lights the
-- Default toolbar button. Opens the ReaFL toolbar once, right after setup.
local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local FLT = dofile(dir .. "reafl_core.lua")
FLT.activate("default")
local pending = reaper.GetExtState(FLT.SECTION, "toolbar_show_pending")
local tb_cmd = tonumber(reaper.GetExtState(FLT.SECTION, "toolbar_cmd"))
if pending == "1" and tb_cmd then
  if reaper.GetToggleCommandState(tb_cmd) ~= 1 then reaper.Main_OnCommand(tb_cmd, 0) end
  reaper.DeleteExtState(FLT.SECTION, "toolbar_show_pending", true)
end
FLT.no_undo()
