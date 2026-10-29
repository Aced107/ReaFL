-- @noindex
-- ReaFL - Setup (run once after install). Safe to run again: it updates its own
-- entries instead of adding duplicates. Undo everything with "ReaFL - Uninstall setup".
--   1. Shortcuts (Main section): 1 -> ReaFL - Default tool, T -> ReaFL - Mute tool
--   2. A "ReaFL" floating toolbar (Default / Mute buttons) in a free toolbar slot
--   3. A guarded block in Scripts/__startup.lua: REAPER always starts in the Default tool
-- Every file is backed up to <resource path>/ReaFL_backups before it is changed.
local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])")
local FLT = dofile(dir .. "lib/reafl_core.lua")
local S = assert(loadfile(dir .. "lib/reafl_setup_common.lua"))(FLT)
local E = FLT.SECTION
local report, restart = {}, false
local function say(s) report[#report + 1] = s end

local ids = { default = FLT.named("default"), mute = FLT.named("mute") }
if not ids.default or not ids.mute then
  reaper.MB("Couldn't find the ReaFL tool actions next to this script.\nReinstall ReaFL from ReaPack and try again.", "ReaFL Setup", 0)
  return
end

---------------------------------------------------------------- 1. shortcuts
do
  local all_active = true
  for _, k in ipairs(S.KEYS) do
    if not S.shortcut_active(FLT.cmd(k.tool), k.label) then all_active = false end
  end
  local path = S.res("reaper-kb.ini")
  local text = FLT.read_file(path) or ""
  local lines, nl = FLT.lines(text)
  local out, replaced = {}, {}
  local prev = reaper.GetExtState(E, "replaced_keys")
  for _, l in ipairs(lines) do
    local flags, key, cmd, sec = S.parse_key(l)
    local drop = false
    if flags == 1 and sec == 0 then
      for _, k in ipairs(S.KEYS) do
        if key == k.vk then
          drop = true
          if cmd ~= ids.default and cmd ~= ids.mute then replaced[#replaced + 1] = l end
        end
      end
    end
    if not drop then out[#out + 1] = l end
  end
  for _, k in ipairs(S.KEYS) do
    out[#out + 1] = ("KEY 1 %d %s 0\t\t # ReaFL : %s : %s tool"):format(k.vk, ids[k.tool], k.label, FLT.tools[k.tool].label)
  end
  local new = table.concat(out, nl) .. nl
  if new ~= text then
    local bak = FLT.backup_file(path)
    FLT.write_file(path, new)
    if #replaced > 0 then  -- remember what we replaced so uninstall can put it back
      local keep = prev ~= "" and (prev .. "||") or ""
      reaper.SetExtState(E, "replaced_keys", keep .. table.concat(replaced, "||"), true)
    end
    say("Shortcuts 1 and T written to reaper-kb.ini" .. (bak and " (backup saved)" or "") .. ".")
  else
    say("Shortcuts 1 and T were already in reaper-kb.ini.")
  end
  if all_active then say("Shortcuts are already active.")
  else restart = true; say("Shortcuts take effect after restarting REAPER.") end
end

---------------------------------------------------------------- 2. toolbar
do
  local path = S.res("reaper-menu.ini")
  local text = FLT.read_file(path)
  if not text then reaper.SetExtState(E, "created_menu_ini", "1", true) end
  local pre, secs, nl = S.parse_ini(text or "")
  local slot, sec
  for _, s in ipairs(secs) do
    if S.is_reafl_toolbar(s) then sec = s; slot = tonumber(s.name:match("(%d+)$")) end
  end
  if not sec then
    local used = {}
    for _, s in ipairs(secs) do local n = s.name:match("^Floating toolbar (%d+)$"); if n then used[tonumber(n)] = true end end
    for n = 1, 16 do if not used[n] then slot = n; break end end
    if not slot then
      say("No free floating toolbar slot (1-16): toolbar NOT installed. Add the actions to a toolbar by hand.")
    else
      sec = { name = "Floating toolbar " .. slot, lines = {} }
      secs[#secs + 1] = sec
    end
  end
  if sec then
    local wanted = {
      "title=" .. S.TOOLBAR_TITLE,
      "icon_0=text_wide", "icon_1=text_wide",
      "item_0=" .. ids.default .. " Default",
      "item_1=" .. ids.mute .. " Mute",
    }
    local same = table.concat(sec.lines, "\n") == table.concat(wanted, "\n")
    if not same then
      sec.lines = wanted
      local bak = text and FLT.backup_file(path)
      FLT.write_file(path, S.build_ini(pre, secs, nl))
      restart = true
      reaper.SetExtState(E, "toolbar_show_pending", "1", true)
      say(("\"ReaFL\" toolbar written to Toolbar %d%s. It opens automatically after the restart."):format(slot, bak and " (reaper-menu.ini backed up)" or ""))
    else
      say(("\"ReaFL\" toolbar already installed as Toolbar %d."):format(slot))
    end
    reaper.SetExtState(E, "toolbar_slot", tostring(slot), true)
    local tb = S.toolbar_cmd(slot)
    if tb then reaper.SetExtState(E, "toolbar_cmd", tostring(tb), true) end
  end
end

---------------------------------------------------------------- 3. __startup.lua
do
  local path = FLT.join(reaper.GetResourcePath(), "Scripts", "__startup.lua")
  local text = FLT.read_file(path)
  if not text then reaper.SetExtState(E, "created_startup", "1", true) end
  -- path of our startup init, relative to the resource path when possible (portable)
  local res = reaper.GetResourcePath():gsub("[/\\]+$", "")
  local target = FLT.join(FLT.lib_dir, "reafl_startup.lua")
  local expr
  local a, b = target:gsub("\\", "/"), res:gsub("\\", "/")
  if a:sub(1, #b):lower() == b:lower() then
    expr = ("reaper.GetResourcePath() .. %q"):format(a:sub(#b + 1))
  else
    expr = ("%q"):format(target)
  end
  local block = table.concat({
    S.START_BEGIN .. " (added by \"ReaFL - Setup\"; remove with \"ReaFL - Uninstall setup\")",
    "do",
    "  local f = " .. expr,
    "  if reaper.file_exists(f) then",
    "    local ok, err = pcall(dofile, f)",
    "    if not ok then reaper.ShowConsoleMsg(\"ReaFL startup error: \" .. tostring(err) .. \"\\n\") end",
    "  end",
    "end",
    S.START_END,
  }, "\n") .. "\n"
  local base = text and S.strip_startup_block(text) or ""
  if base ~= "" and not base:match("\n$") then base = base .. "\n" end
  local new = base .. block
  if new ~= text then
    local bak = text and FLT.backup_file(path)
    FLT.write_file(path, new)
    say("Startup init " .. (text and (text:find(S.START_BEGIN, 1, true) and "updated in" or "appended to") or "added in new") .. " Scripts/__startup.lua" .. (bak and " (backup saved)" or "") .. ".")
  else
    say("Startup init already present in Scripts/__startup.lua.")
  end
end

reaper.SetExtState(E, "setup_done", FLT.VERSION, true)
FLT.activate("default")

local msg = "ReaFL " .. FLT.VERSION .. " setup:\n\n- " .. table.concat(report, "\n- ")
if not FLT.has_js() then
  msg = msg .. "\n\nWARNING: js_ReaScriptAPI is not installed. The Mute tool needs it.\n"
    .. "Install it from ReaPack (ReaTeam Extensions > js_ReaScriptAPI) and restart REAPER."
end
msg = msg .. (restart and "\n\nPlease restart REAPER now to finish setup." or "\n\nNo restart needed.")
reaper.MB(msg, "ReaFL Setup", 0)
FLT.no_undo()
