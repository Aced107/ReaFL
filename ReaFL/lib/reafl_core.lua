-- ReaFL core: FL Studio-style "tool modes" for REAPER's arrange view.
-- Shared by every "ReaFL - *.lua" action. Not an action itself.
--
-- Model
--  * A tool = optional mouse-modifier overrides + optional click handlers that the
--    background engine (lib/reafl_engine.lua) runs while the tool is active.
--  * Activating a tool first restores the user's own mouse modifiers (snapshot kept
--    in persistent ExtState), then snapshots + applies the new tool's overrides.
--  * Toolbar buttons / shortcuts run the per-tool actions; toggle states mark the
--    active tool so exactly one toolbar button is lit.
--
-- Adding a tool: add an entry to FLT.tools and FLT.order, plus a small
-- "ReaFL - <Name> tool.lua" action (copy "ReaFL - Mute tool.lua").

local FLT = {}
FLT.NAME    = "ReaFL"
FLT.VERSION = "0.1.0"
FLT.SECTION = "ReaFL"            -- ExtState section

local SEP = package.config:sub(1, 1)          -- "\" on Windows, "/" elsewhere
FLT.SEP = SEP

local function norm(p) return (p:gsub("[/\\]", SEP)) end
FLT.norm = norm
function FLT.join(...) return norm(table.concat({ ... }, "/")) end

local src = debug.getinfo(1, "S").source:sub(2)
FLT.lib_dir = src:match("^(.*)[/\\][^/\\]+$")
FLT.dir     = FLT.lib_dir:match("^(.*)[/\\][^/\\]+$")   -- package folder (parent of lib)

FLT.scripts = {
  default   = "ReaFL - Default tool.lua",
  mute      = "ReaFL - Mute tool.lua",
  setup     = "ReaFL - Setup (run once after install).lua",
  uninstall = "ReaFL - Uninstall setup.lua",
}

------------------------------------------------------------------ action ids
local id_cache = {}
-- Numeric command id of one of our actions. AddRemoveReaScript with commit=false
-- returns the existing id (ReaPack registered the script) without touching reaper-kb.ini.
function FLT.cmd(key)
  if id_cache[key] then return id_cache[key] end
  local path = FLT.join(FLT.dir, FLT.scripts[key])
  if not reaper.file_exists(path) then return nil end
  local id = reaper.AddRemoveReaScript(true, 0, path, false)
  if id and id ~= 0 then id_cache[key] = id; return id end
end
-- "_RS..." named command id (stable across sessions; used in toolbars / keymaps)
function FLT.named(key)
  local id = FLT.cmd(key)
  local n = id and reaper.ReverseNamedCommandLookup(id)
  return n and ("_" .. n) or nil
end

------------------------------------------------------------------ tools
FLT.order = { "default", "mute" }
FLT.tools = {
  default = { label = "Default", script = "default", modifiers = {} },
  mute = {
    label = "Mute", script = "mute",
    modifiers = {},              -- no mouse-modifier changes: clicks are handled by the engine
    engine = {
      lclick = "toggle_mute",    -- left click / double-click on an item: toggle that item's mute
      rclick = "delete",         -- right click on an item: delete that item
    },
  },
}

function FLT.has_js() return reaper.JS_WindowMessage_Intercept ~= nil end

------------------------------------------------------------------ state
function FLT.get_mode()
  local m = reaper.GetExtState(FLT.SECTION, "mode")
  return FLT.tools[m] and m or "default"
end

-- saved original modifiers: "ctx|mod|action;;ctx|mod|action"
local function load_saved()
  local s, out = reaper.GetExtState(FLT.SECTION, "saved_modifiers"), {}
  for entry in s:gmatch("[^;]+") do
    local ctx, mod, act = entry:match("^([^|]+)|(%-?%d+)|(.*)$")
    if ctx then out[#out + 1] = { ctx = ctx, mod = tonumber(mod), action = act } end
  end
  return out
end
local function store_saved(list)
  local t = {}
  for _, e in ipairs(list) do t[#t + 1] = e.ctx .. "|" .. e.mod .. "|" .. e.action end
  if #t == 0 then reaper.DeleteExtState(FLT.SECTION, "saved_modifiers", true)
  else reaper.SetExtState(FLT.SECTION, "saved_modifiers", table.concat(t, ";;"), true) end
end

-- Put the user's own modifiers back: reset the slot to factory default and only write an
-- explicit value if theirs differed, so reaper-mouse.ini ends up exactly as before.
function FLT.restore_modifiers()
  for _, e in ipairs(load_saved()) do
    reaper.SetMouseModifier(e.ctx, e.mod, "-1")
    if reaper.GetMouseModifier(e.ctx, e.mod) ~= e.action then
      reaper.SetMouseModifier(e.ctx, e.mod, e.action)
    end
  end
  store_saved({})
end

local function apply_modifiers(tool)
  local saved = {}
  for _, m in ipairs(tool.modifiers or {}) do
    saved[#saved + 1] = { ctx = m.ctx, mod = m.mod, action = reaper.GetMouseModifier(m.ctx, m.mod) }
  end
  store_saved(saved)                                   -- persist before changing anything
  for _, m in ipairs(tool.modifiers or {}) do
    local a = type(m.action) == "function" and m.action() or m.action
    if a then reaper.SetMouseModifier(m.ctx, m.mod, a) end
  end
end

function FLT.update_toggle_states(mode)
  for _, name in ipairs(FLT.order) do
    local id = FLT.cmd(FLT.tools[name].script)
    if id then
      reaper.SetToggleCommandState(0, id, name == mode and 1 or 0)
      reaper.RefreshToolbar2(0, id)
    end
  end
end

-- Switch tool. Returns false if the tool can't run (e.g. js_ReaScriptAPI missing).
function FLT.activate(name)
  local tool = FLT.tools[name]
  if not tool then return false end
  if tool.engine and not FLT.has_js() then
    reaper.MB("The " .. tool.label .. " tool needs the js_ReaScriptAPI extension.\n\n"
      .. "Install it with Extensions > ReaPack > Browse packages > \"js_ReaScriptAPI\" "
      .. "(ReaTeam Extensions repository), then restart REAPER.", FLT.NAME, 0)
    name, tool = "default", FLT.tools.default
  end
  FLT.restore_modifiers()
  apply_modifiers(tool)
  reaper.SetExtState(FLT.SECTION, "mode", name, true)
  FLT.update_toggle_states(name)
  return name
end

------------------------------------------------------------------ item operations
function FLT.item_at_mouse()
  local x, y = reaper.GetMousePosition()
  return (reaper.GetItemFromPoint(x, y, true))
end

function FLT.toggle_item_mute(item)
  if not item or not reaper.ValidatePtr(item, "MediaItem*") then return false end
  reaper.Undo_BeginBlock()
  local m = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
  reaper.SetMediaItemInfo_Value(item, "B_MUTE", m == 1 and 0 or 1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(m == 1 and "ReaFL: Unmute item" or "ReaFL: Mute item", 4)
  return true
end

function FLT.delete_item(item)
  if not item or not reaper.ValidatePtr(item, "MediaItem*") then return false end
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("ReaFL: Delete item", 4)
  return true
end

FLT.actions = { toggle_mute = FLT.toggle_item_mute, delete = FLT.delete_item }

function FLT.no_undo() reaper.defer(function() end) end   -- no "ReaScript: Run" undo point

function FLT.set_action_options(flags)
  if reaper.set_action_options then reaper.set_action_options(flags) end  -- REAPER 7.03+
end

------------------------------------------------------------------ file helpers (setup)
function FLT.read_file(path)
  local f = io.open(path, "rb"); if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end
function FLT.write_file(path, s)
  local f = io.open(path, "wb"); if not f then return false end
  f:write(s); f:close(); return true
end
function FLT.backup_file(path)
  local s = FLT.read_file(path); if not s then return nil end
  local dir = FLT.join(reaper.GetResourcePath(), "ReaFL_backups")
  reaper.RecursiveCreateDirectory(dir, 0)
  local name = path:match("([^/\\]+)$")
  local dest = FLT.join(dir, name .. "." .. os.date("%Y%m%d-%H%M%S") .. ".bak")
  FLT.write_file(dest, s)
  return dest
end
-- split keeping the file's own newline style
function FLT.lines(s)
  local nl = s:find("\r\n", 1, true) and "\r\n" or "\n"
  local t = {}
  for line in (s .. "\n"):gmatch("(.-)\r?\n") do t[#t + 1] = line end
  if t[#t] == "" then t[#t] = nil end
  return t, nl
end

return FLT
