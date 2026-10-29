-- @noindex
-- ReaFL - Uninstall setup: reverses "ReaFL - Setup" (shortcuts, toolbar, startup block,
-- saved state). The scripts themselves are removed by uninstalling ReaFL in ReaPack.
local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local FLT = dofile(dir .. "lib/reafl_core.lua")
local S = assert(loadfile(dir .. "lib/reafl_setup_common.lua"))(FLT)
local E = FLT.SECTION
local report = {}
local function say(s) report[#report + 1] = s end

if reaper.MB("Remove ReaFL's shortcuts, toolbar and startup entry?", "ReaFL - Uninstall setup", 1) ~= 1 then return end

FLT.activate("default")                  -- stops any tool engine, restores mouse modifiers
local ids = { FLT.named("default"), FLT.named("mute") }

-- toolbar window
local tb = tonumber(reaper.GetExtState(E, "toolbar_cmd"))
if tb and reaper.GetToggleCommandState(tb) == 1 then reaper.Main_OnCommand(tb, 0) end

-- 1. shortcuts
do
  local path = S.res("reaper-kb.ini")
  local text = FLT.read_file(path)
  if text then
    local lines, nl = FLT.lines(text)
    local out, removed = {}, 0
    for _, l in ipairs(lines) do
      local flags, key, cmd = S.parse_key(l)
      if flags and (cmd == ids[1] or cmd == ids[2] or l:find("# ReaFL :", 1, true)) then removed = removed + 1
      else out[#out + 1] = l end
    end
    local restored = 0
    local prev = reaper.GetExtState(E, "replaced_keys")
    for l in prev:gmatch("[^|]+") do out[#out + 1] = l; restored = restored + 1 end
    local new = table.concat(out, nl) .. nl
    if new ~= text then FLT.backup_file(path); FLT.write_file(path, new) end
    say(("Removed %d ReaFL shortcut line(s)%s."):format(removed,
      restored > 0 and (", restored " .. restored .. " shortcut(s) they replaced") or ""))
  end
end

-- 2. toolbar
do
  local path = S.res("reaper-menu.ini")
  local text = FLT.read_file(path)
  if text then
    local pre, secs, nl = S.parse_ini(text)
    local keep, n = {}, 0
    for _, s in ipairs(secs) do if S.is_reafl_toolbar(s) then n = n + 1 else keep[#keep + 1] = s end end
    if n > 0 then
      FLT.backup_file(path)
      local new = S.build_ini(pre, keep, nl)
      if new:match("^%s*$") and reaper.GetExtState(E, "created_menu_ini") == "1" then os.remove(path)
      else FLT.write_file(path, new) end
      say("Removed the ReaFL toolbar from reaper-menu.ini.")
    end
  end
end

-- 3. __startup.lua
do
  local path = FLT.join(reaper.GetResourcePath(), "Scripts", "__startup.lua")
  local text = FLT.read_file(path)
  if text then
    local new, found = S.strip_startup_block(text)
    if found then
      FLT.backup_file(path)
      if new:match("^%s*$") and reaper.GetExtState(E, "created_startup") == "1" then os.remove(path)
      else FLT.write_file(path, new) end
      say("Removed the ReaFL block from Scripts/__startup.lua.")
    end
  end
end

-- 4. saved state
for _, k in ipairs({ "mode", "saved_modifiers", "replaced_keys", "toolbar_slot", "toolbar_cmd",
                     "toolbar_show_pending", "created_menu_ini", "created_startup", "setup_done" }) do
  reaper.DeleteExtState(E, k, true)
end
FLT.update_toggle_states("none")

reaper.MB("ReaFL setup removed:\n\n- " .. table.concat(report, "\n- ")
  .. "\n\nRestart REAPER to finish (shortcuts and toolbars reload at startup).\n"
  .. "To delete the scripts too, uninstall ReaFL in Extensions > ReaPack > Manage/Browse packages.",
  "ReaFL - Uninstall setup", 0)
FLT.no_undo()
