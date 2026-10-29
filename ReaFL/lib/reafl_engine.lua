-- ReaFL engine: click handling for tools, run as part of a tool's action while
-- that tool is active (it stops by itself when you switch tool).
--
-- REAPER has no mouse-modifier context for a plain right-click on an item, and the
-- item left-click context always selects the item first. So while the mouse is over
-- an item in the arrange view (and Ctrl/Alt/Win aren't held), the engine blocks the
-- arrange window's mouse-button messages with js_ReaScriptAPI and runs the tool's
-- action on the clicked item instead. Anywhere else nothing is blocked, so REAPER
-- behaves normally (menus on empty space, Ctrl+click, etc.).
local FLT = ...   -- core table passed by the caller

return function(tool_name)
  local tool = FLT.tools[tool_name]
  local handlers = tool and tool.engine
  if not handlers or not FLT.has_js() then return end

  local tv = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 1000) -- arrange view
  if not tv then return end

  local buttons = {}
  if handlers.lclick then
    buttons[#buttons + 1] = { action = handlers.lclick, state_bit = 1,
      down = "WM_LBUTTONDOWN", up = "WM_LBUTTONUP", dbl = "WM_LBUTTONDBLCLK" }
  end
  if handlers.rclick then
    buttons[#buttons + 1] = { action = handlers.rclick, state_bit = 2,
      down = "WM_RBUTTONDOWN", up = "WM_RBUTTONUP", dbl = "WM_RBUTTONDBLCLK", extra = "WM_CONTEXTMENU" }
  end
  local names = {}
  for _, b in ipairs(buttons) do
    for _, k in ipairs({ "down", "up", "dbl", "extra" }) do if b[k] then names[#names + 1] = b[k] end end
  end
  local release_list = table.concat(names, ",")
  local intercept_list = table.concat(names, ":block,") .. ":block"

  local intercepting = false
  local function peek(msg)
    local ok, _, t, _, _, x, y = reaper.JS_WindowMessage_Peek(tv, msg)
    if ok then return t, x, y end
  end
  local function set_intercept(on)
    if on == intercepting then return end
    if on then
      -- another script may still hold these messages for a moment; retry next cycle
      if reaper.JS_WindowMessage_InterceptList(tv, intercept_list) ~= 1 then return end
      for _, b in ipairs(buttons) do
        b.t_down, b.t_up, b.t_dbl = peek(b.down), peek(b.up), peek(b.dbl)
        b.holding, b.released_at = false, nil
      end
    else
      reaper.JS_WindowMessage_Release(tv, release_list)
    end
    intercepting = on
  end

  local function run(b, cx, cy)
    local sx, sy = reaper.JS_Window_ClientToScreen(tv, cx, cy)
    local item = reaper.GetItemFromPoint(sx, sy, true) or FLT.item_at_mouse()
    local fn = FLT.actions[b.action]
    if fn and item then fn(item) end
  end

  local function loop()
    if FLT.get_mode() ~= tool_name or not reaper.JS_Window_IsWindow(tv) then return end

    local any_holding = false
    if intercepting then
      for _, b in ipairs(buttons) do
        local t, x, y = peek(b.down)
        if t and t ~= b.t_down then b.t_down, b.holding, b.released_at = t, true, nil; run(b, x, y) end
        -- the 2nd click of a double-click arrives as *DBLCLK: treat it as a click
        -- (FL Studio: double-click with the Mute tool = two toggles = no net change)
        t, x, y = peek(b.dbl)
        if t and t ~= b.t_dbl then b.t_dbl, b.holding, b.released_at = t, true, nil; run(b, x, y) end
        t = peek(b.up)
        if t and t ~= b.t_up then b.t_up, b.holding = t, false end
        if b.holding then  -- safety net if the button-up message never arrives
          if reaper.JS_Mouse_GetState(b.state_bit) ~= 0 then b.released_at = nil
          else
            b.released_at = b.released_at or reaper.time_precise()
            if reaper.time_precise() - b.released_at > 1 then b.holding = false end
          end
        end
        any_holding = any_holding or b.holding
      end
    end

    local x, y = reaper.GetMousePosition()
    local over_item = reaper.JS_Window_FromPoint(x, y) == tv and reaper.GetItemFromPoint(x, y, true) ~= nil
    local mods = reaper.JS_Mouse_GetState(4 | 16 | 32) ~= 0      -- Ctrl / Alt / Win(Cmd) held
    -- keep blocking until a blocked press is released, so REAPER never sees a lone button-up
    set_intercept((over_item and not mods) or any_holding)
    reaper.defer(loop)
  end

  reaper.atexit(function()
    if intercepting and reaper.JS_Window_IsWindow(tv) then reaper.JS_WindowMessage_Release(tv, release_list) end
  end)
  loop()
end
