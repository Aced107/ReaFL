-- ReaFL setup helpers shared by "ReaFL - Setup" and "ReaFL - Uninstall setup".
local FLT = ...
local S = {}

S.KEYS = {                        -- Main section, no modifier keys
  { vk = 49, label = "1", tool = "default" },
  { vk = 84, label = "T", tool = "mute" },
}
S.START_BEGIN = "-- >>> ReaFL startup"
S.START_END   = "-- <<< ReaFL startup"
S.TOOLBAR_TITLE = "ReaFL"

function S.res(name) return FLT.join(reaper.GetResourcePath(), name) end

function S.shortcut_active(cmd, label)
  if not cmd then return false end
  for i = 0, reaper.CountActionShortcuts(0, cmd) - 1 do
    local _, d = reaper.GetActionShortcutDesc(0, cmd, i)
    if d and d:upper() == label:upper() then return true end
  end
  return false
end

-- "Toolbar: Open/close toolbar N" command id, found by name (ids differ between ranges)
function S.toolbar_cmd(n)
  local want = "Toolbar: Open/close toolbar " .. n
  local i = 0
  while true do
    local id, name = reaper.kbd_enumerateActions(reaper.SectionFromUniqueID(0), i)
    if not id or id == 0 then return nil end
    if name == want then return id end
    i = i + 1
  end
end

-- reaper-menu.ini sections: list of {name=, lines={...}} plus preamble lines
function S.parse_ini(s)
  local lines, nl = FLT.lines(s or "")
  local pre, secs, cur = {}, {}, nil
  for _, l in ipairs(lines) do
    local name = l:match("^%[(.-)%]%s*$")
    if name then cur = { name = name, lines = {} }; secs[#secs + 1] = cur
    elseif cur then cur.lines[#cur.lines + 1] = l
    else pre[#pre + 1] = l end
  end
  return pre, secs, nl
end
function S.build_ini(pre, secs, nl)
  local out = {}
  for _, l in ipairs(pre) do out[#out + 1] = l end
  for _, sec in ipairs(secs) do
    out[#out + 1] = "[" .. sec.name .. "]"
    for _, l in ipairs(sec.lines) do out[#out + 1] = l end
  end
  return table.concat(out, nl) .. (#out > 0 and nl or "")
end
function S.is_reafl_toolbar(sec)
  if not sec.name:match("^Floating toolbar %d+$") then return false end
  for _, l in ipairs(sec.lines) do if l == "title=" .. S.TOOLBAR_TITLE then return true end end
  return false
end

-- Parse "KEY flags key cmd section" lines
function S.parse_key(line)
  local flags, key, cmd, sec = line:match("^KEY%s+(%d+)%s+(%d+)%s+(%S+)%s+(%d+)")
  if flags then return tonumber(flags), tonumber(key), cmd, tonumber(sec) end
end

-- remove the guarded block from a startup file's text
function S.strip_startup_block(s)
  local b = s:find(S.START_BEGIN, 1, true)
  if not b then return s, false end
  local e1, e2 = s:find(S.START_END, b, true)
  if not e1 then return s, false end
  local after = s:sub(e2 + 1):gsub("^\r?\n", "")
  local before = s:sub(1, b - 1)
  return before .. after, true
end

return S
