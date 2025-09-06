--- === KeyCaster ===
--- A Hammerspoon Spoon to display your last keystrokes on-screen.
---
--- Modes:
---  * "column" (default): stack of boxes on the right edge of the current display. **Each box can contain multiple keystrokes**. A new box is started after a short pause or when a character-limit is reached. Boxes fade over time.
---  * "line": a **single** box on the right edge. Keystrokes append to the right; older ones fade and fall off from the left.
---
--- Other features:
---  * Keeps the latest `maxVisible` entries at a minimum alpha until they fall out of the visible set
---  * Follows the mouse between displays
---  * Start/Stop hotkeys (Ctrl+Alt+Cmd+K / Ctrl+Alt+Cmd+F)
---  * Menubar indicator while active
---
--- Notes:
---  * Listens to keyDown events only; does not display modifier-only transitions
---  * Does not swallow events (your keystrokes still go to the focused app)

local obj = {}
obj.__index = obj

obj.name = "KeyCaster"
obj.version = "0.0.1"
obj.author = "Selim Acerbas"
obj.homepage = "https://www.github.com/selimacerbas/KeyCaster.spoon/"
obj.license = "MIT"
obj.logger = hs.logger.new("KeyCaster", "info")

-- ===============
-- Configuration
-- ===============
obj.config = {
    mode = "column",             -- "column" | "line"
    fadingDuration = 2.0,        -- seconds to go from 1.0 alpha to minAlpha
    maxVisible = 5,              -- keep last N at least minAlpha
    minAlphaWhileVisible = 0.35, -- clamp alpha for items still within maxVisible
    followInterval = 0.40,       -- seconds; reposition to the screen under mouse

    -- Column mode visuals
    box = { w = 260, h = 36, spacing = 8, corner = 10 },
    position = { corner = "bottomRight", x = 20, y = 80 },
    column = {
        maxCharsPerBox = 14,   -- start a new box if current has this many glyphs
        newBoxOnPause  = 0.70, -- seconds of inactivity to start a new box
    },

    -- Line mode visuals
    line = {
        box = { w = 520, h = 36, corner = 10 },
        maxSegments = 60, -- hard cap on segments kept in memory
        gap = 6,          -- px gap between segments
    },

    font = { name = "Menlo", size = 18 }, -- default to Menlo (broadly available)
    colors = {
        bg     = { red = 0, green = 0, blue = 0, alpha = 0.78 },
        text   = { red = 1, green = 1, blue = 1, alpha = 0.98 },
        stroke = { red = 1, green = 1, blue = 1, alpha = 0.15 },
        shadow = { red = 0, green = 0, blue = 0, alpha = 0.6 },
    },
    ignoreAutoRepeat = true,
}

-- Default hotkeys
obj.defaultHotkeys = {
    start = { { "ctrl", "alt", "cmd" }, "K" },
    stop  = { { "ctrl", "alt", "cmd" }, "F" },
}

-- ===============
-- Internal State
-- ===============
obj._items = {}         -- COLUMN mode: newest-first list of boxes {canvas, timer, fadeProgress, lastTouch, text}
obj._currentGroup = nil -- COLUMN mode: the active box accumulating keystrokes
obj._segments = {}      -- LINE mode: left->right list of segments {text, createdAt, fadeProgress, width}
obj._lineCanvas = nil
obj._tap = nil
obj._followTimer = nil
obj._menubar = nil
obj._reverseKeycodes = nil
obj._resolvedFont = nil

-- ===============
-- Utilities
-- ===============
local function shallowCopy(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end

local function now() return hs.timer.secondsSinceEpoch() end

function obj:_buildReverseKeycodes()
    if self._reverseKeycodes then return end
    self._reverseKeycodes = {}
    for name, code in pairs(hs.keycodes.map) do self._reverseKeycodes[code] = name end
end

-- Best-effort font resolver with fallbacks; avoids runtime canvas errors
function obj:_resolveFont()
    if self._resolvedFont then return self._resolvedFont end
    local candidates = {
        self.config.font.name,
        "Menlo",
        "Monaco",
        "Courier New",
        "SFMono-Regular", -- some systems expose it under this name
    }
    local size = self.config.font.size or 18
    for _, name in ipairs(candidates) do
        local ok = pcall(function()
            -- attempt to create a styledtext; this throws if font is invalid
            hs.styledtext.new("x", { font = { name = name, size = size } })
        end)
        if ok then
            self._resolvedFont = { name = name, size = size }; return self._resolvedFont
        end
    end
    -- last resort: let canvas use default font at given size
    self._resolvedFont = { name = "Menlo", size = size }
    return self._resolvedFont
end

-- Measure text width (px). Prefer hs.drawing.getTextDrawingSize, fallback to estimate
function obj:_measure(text)
    local f = self:_resolveFont()
    local ok, sz = pcall(function()
        return hs.drawing.getTextDrawingSize(text,
            { textFont = (f and f.name) or "Menlo", textSize = (f and f.size) or 18 })
    end)
    if ok and sz and sz.w then return sz.w end
    -- crude fallback: monospace-ish estimate
    local avg = (f.size or 18) * 0.60
    return avg * #tostring(text)
end

local specialsByName = {
    ["return"]        = "↩︎",
    ["enter"]         = "⌤",
    ["escape"]        = "⎋",
    ["tab"]           = "⇥",
    ["space"]         = "␣",
    ["delete"]        = "⌫",
    ["forwarddelete"] = "⌦",
    ["home"]          = "↖",
    ["end"]           = "↘",
    ["pageup"]        = "⇞",
    ["pagedown"]      = "⇟",
    ["left"]          = "←",
    ["right"]         = "→",
    ["up"]            = "↑",
    ["down"]          = "↓",
}

local punctuationByName = {
    ["comma"]        = ",",
    ["period"]       = ".",
    ["slash"]        = "/",
    ["backslash"]    = "\\",
    ["grave"]        = "`",
    ["quote"]        = "'",
    ["semicolon"]    = ";",
    ["minus"]        = "-",
    ["equal"]        = "=",
    ["leftbracket"]  = "[",
    ["rightbracket"] = "]",
}

local function isFunctionKey(name)
    if not name then return false end
    return string.match(name, "^f(%d%d?)$") ~= nil
end

function obj:_currentScreen()
    return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

function obj:_anchor()
    local pos    = self.config.position or { corner = "bottomRight", x = 20, y = 80 }
    local corner = string.lower(pos.corner or "bottomRight")
    local scr    = self:_currentScreen()
    local f      = scr:frame()
    local rightX = f.x + f.w - (pos.x or 20)
    local leftX  = f.x + (pos.x or 20)
    local topY   = f.y + (pos.y or 80)
    local botY   = f.y + f.h - (pos.y or 80)
    local ax, ay
    if corner == "bottomright" then
        ax, ay = rightX, botY
    elseif corner == "topright" then
        ax, ay = rightX, topY
    elseif corner == "topleft" then
        ax, ay = leftX, topY
    elseif corner == "bottomleft" then
        ax, ay = leftX, botY
    else
        ax, ay = rightX, botY
    end
    return ax, ay, corner
end

function obj:_baseFrameForIndex(i, boxW, boxH)
    local ax, ay, corner = self:_anchor()
    local x = (string.find(corner, "right", 1, true) and (ax - boxW)) or ax
    local spacing = self.config.box.spacing or 8
    local y
    if string.find(corner, "bottom", 1, true) then
        y = ay - (boxH + spacing) * (i - 1) - boxH
    else
        y = ay + (boxH + spacing) * (i - 1)
    end
    return { x = x, y = y, w = boxW, h = boxH }
end

-- ===============
-- Menubar
-- ===============
function obj:_ensureMenubar(state)
    if state then
        if not self._menubar then
            self._menubar = hs.menubar.new()
            if self._menubar then
                self._menubar:setTitle("⌨︎")
                self._menubar:setTooltip("KeyCaster: showing keystrokes")
                self._menubar:setMenu({ { title = "Stop KeyCaster", fn = function() self:stop() end }, })
            end
        end
    else
        if self._menubar then
            self._menubar:delete()
            self._menubar = nil
        end
    end
end

-- ===============
-- Label Formatting
-- ===============
function obj:_formatLabel(event)
    self:_buildReverseKeycodes()
    local flags = event:getFlags()
    local mods = "" ..
        (flags.cmd and "⌘" or "") ..
        (flags.alt and "⌥" or "") .. (flags.ctrl and "⌃" or "") .. (flags.shift and "⇧" or "")

    local chars = event:getCharacters(true) or ""
    if #chars == 1 and string.byte(chars) < 32 then chars = "" end

    local keyName = self._reverseKeycodes[event:getKeyCode()]
    local pretty
    if specialsByName[keyName] then
        pretty = specialsByName[keyName]
    elseif punctuationByName[keyName] then
        pretty = punctuationByName[keyName]
    elseif isFunctionKey(keyName) then
        pretty = string.upper(keyName)
    elseif #chars > 0 then
        pretty = chars
    elseif keyName and #keyName == 1 then
        pretty = (flags.shift and string.upper(keyName) or keyName)
    else
        pretty = keyName or "?"
    end

    if pretty == " " then pretty = "␣" end
    return mods .. pretty
end

-- ===============
-- Canvas helpers
-- ===============
function obj:_roundedRectItem()
    local c = self.config
    return {
        type = "rectangle",
        action = "fill",
        fillColor = c.colors.bg,
        roundedRectRadii = { xRadius = c.box.corner or 10, yRadius = c.box.corner or 10 },
        strokeColor = c.colors.stroke,
        strokeWidth = 1,
        shadow = { blurRadius = 8, color = c.colors.shadow, offset = { h = 0, w = 0 } },
    }
end

function obj:_applyBehaviors(cv)
    if cv.behaviorAsLabels then
        cv:behaviorAsLabels({ "canJoinAllSpaces", "ignoresMouseEvents" })
    elseif cv.behavior and hs.canvas and hs.canvas.windowBehaviors then
        cv:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.ignoresMouseEvents)
    end
end

-- ===============
-- COLUMN MODE
-- ===============
local function _newColumnItem(frame, text, font, colors)
    local c = hs.canvas.new(frame)
    c:level(hs.canvas.windowLevels.overlay)
    -- background shape is index 1
    c[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = colors.bg,
        roundedRectRadii = { xRadius = 10, yRadius = 10 },
        strokeColor = colors.stroke,
        strokeWidth = 1,
        shadow = { blurRadius = 8, color = { red = 0, green = 0, blue = 0, alpha = 0.6 }, offset = { h = 0, w = 0 } },
    }
    c[2] = {
        type = "text",
        text = text,
        textSize = font.size,
        textFont = (font and font.name) or "Menlo",
        textAlignment = "left",
        frame = { x = 12, y = 6, w = frame.w - 24, h = frame.h - 12 },
        textColor = colors.text,
    }
    return c
end

function obj:_renderColumnPositions()
    local box = self.config.box
    for i, item in ipairs(self._items) do
        if item.canvas then
            item.canvas:frame(self:_baseFrameForIndex(i, box.w, box.h))
        end
    end
end

function obj:_columnPush(label)
    local t = now()
    local c = self.config
    local font = self:_resolveFont()

    local function startNewBox()
        local cv = _newColumnItem({ x = 0, y = 0, w = c.box.w, h = c.box.h }, label, font, c.colors)
        self:_applyBehaviors(cv)
        local item = { canvas = cv, fadeProgress = 0, lastTouch = t, text = label }
        table.insert(self._items, 1, item)
        cv:show()
        self:_renderColumnPositions()
        self._currentGroup = item

        -- fade timer per item
        local step = 0.03
        item.timer = hs.timer.doEvery(step, function()
            item.fadeProgress = item.fadeProgress + (step / c.fadingDuration)
            -- dynamic index lookup
            local idx
            for i, it in ipairs(self._items) do
                if it == item then
                    idx = i
                    break
                end
            end
            if not idx then
                if item.timer then item.timer:stop() end
                return
            end
            local minA = (idx <= c.maxVisible) and c.minAlphaWhileVisible or 0.0
            local a = math.max(1.0 - item.fadeProgress, minA)
            if item.canvas then item.canvas:alpha(a) end
            if item.fadeProgress >= 1.0 and idx > c.maxVisible then
                -- remove fully faded
                if item.timer then item.timer:stop() end
                if item.canvas then item.canvas:delete() end
                for i, it in ipairs(self._items) do
                    if it == item then
                        table.remove(self._items, i)
                        break
                    end
                end
                self:_renderColumnPositions()
            end
        end)
    end

    -- decide whether to append to current group or start new
    local g = self._currentGroup
    local needNew = true
    if g and g.canvas then
        local paused = (t - (g.lastTouch or 0)) >= c.column.newBoxOnPause
        local long   = (utf8.len(g.text or "") or #tostring(g.text or "")) >= c.column.maxCharsPerBox
        needNew      = paused or long
    end

    if needNew or (not g) then
        startNewBox()
    else
        -- append to existing
        g.text = g.text .. " " .. label
        g.lastTouch = t
        g.canvas[2].text = g.text
        g.canvas:show()
    end

    -- cap boxed history
    local hardCap = c.maxVisible + 30
    while #self._items > hardCap do
        local rm = table.remove(self._items)
        if rm.timer then rm.timer:stop() end
        if rm.canvas then rm.canvas:delete() end
    end
end

-- ===============
-- LINE MODE
-- ===============
function obj:_ensureLineCanvas()
    if self._lineCanvas then return self._lineCanvas end
    local L = self.config.line
    local cv = hs.canvas.new({ x = 0, y = 0, w = L.box.w, h = L.box.h })
    cv:level(hs.canvas.windowLevels.overlay)
    -- background at index 1
    cv[1] = {
        type = "rectangle",
        action = "fill",
        fillColor = self.config.colors.bg,
        roundedRectRadii = { xRadius = L.box.corner or 10, yRadius = L.box.corner or 10 },
        strokeColor = self.config.colors.stroke,
        strokeWidth = 1,
        shadow = { blurRadius = 8, color = self.config.colors.shadow, offset = { h = 0, w = 0 } },
    }
    self:_applyBehaviors(cv)
    self._lineCanvas = cv
    cv:show()
    return cv
end

function obj:_layoutLine()
    local L = self.config.line
    local font = self:_resolveFont()
    local marginX = 12
    local baselineY = 6

    -- build from right to left
    local totalW = marginX
    -- clear existing text elements (keep index 1 for bg)
    for i = #self._lineCanvas, 2, -1 do self._lineCanvas[i] = nil end

    local n = #self._segments
    local visibleCount = 0
    for i = n, 1, -1 do
        local seg = self._segments[i]
        local aFloor = (i > n - self.config.maxVisible) and self.config.minAlphaWhileVisible or 0.0
        local alpha = math.max(1.0 - seg.fadeProgress, aFloor)
        if alpha <= 0.001 then goto continue end

        local w = seg.width or self:_measure(seg.text)
        seg.width = w
        local xRight = L.box.w - marginX - totalW
        local x = xRight - w
        if x < marginX then
            -- no more room; stop drawing older segments
            break
        end

        table.insert(self._lineCanvas, {
            type = "text",
            text = seg.text,
            textSize = font.size,
            textFont = (font and font.name) or "Menlo",
            textAlignment = "left",
            frame = { x = x, y = baselineY, w = w, h = L.box.h - 12 },
            textColor = { red = self.config.colors.text.red, green = self.config.colors.text.green, blue = self.config.colors.text.blue, alpha = alpha },
        })

        totalW = totalW + w + L.gap
        visibleCount = visibleCount + 1
        ::continue::
    end

    -- position the single line canvas on the active display
    local ax, ay, corner = self:_anchor()
    local x = (string.find(corner, "right", 1, true) and (ax - L.box.w)) or ax
    local y = (string.find(corner, "bottom", 1, true) and (ay - L.box.h)) or ay
    self._lineCanvas:frame({ x = x, y = y, w = L.box.w, h = L.box.h })
end

function obj:_tickLine()
    local step = 0.03
    if not self._lineTimer then
        self._lineTimer = hs.timer.doEvery(step, function()
            local changed = false
            for _, seg in ipairs(self._segments) do
                seg.fadeProgress = seg.fadeProgress + (step / self.config.fadingDuration)
                if seg.fadeProgress >= 1.0 then changed = true end
            end
            -- drop fully faded from the left
            while #self._segments > 0 and self._segments[1].fadeProgress >= 1.0 do
                table.remove(self._segments, 1)
                changed = true
            end
            if changed and self._lineCanvas then self:_layoutLine() end
        end)
    end
end

function obj:_linePush(label)
    self:_ensureLineCanvas()
    local seg = { text = label, createdAt = now(), fadeProgress = 0 }
    table.insert(self._segments, seg)
    -- keep memory bounded
    local L = self.config.line
    while #self._segments > L.maxSegments do table.remove(self._segments, 1) end
    self:_layoutLine()
end

-- ===============
-- Event handling
-- ===============
function obj:_handleKey(e)
    if self.config.ignoreAutoRepeat then
        local isRepeat = e:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat)
        if isRepeat and isRepeat ~= 0 then return false end
    end
    local label = self:_formatLabel(e)
    if self.config.mode == "line" then
        self:_linePush(label)
    else
        self:_columnPush(label)
    end
    -- Reposition to current screen on every keystroke
    if self.config.mode == "column" then
        self:_renderColumnPositions()
    else
        self:_layoutLine()
    end
    return false -- don't swallow the event
end

-- ===============
-- Public API
-- ===============
function obj:start()
    if self._tap then return self end
    self:_buildReverseKeycodes()
    self:_resolveFont()

    self._tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
        local ok, err = pcall(function() self:_handleKey(e) end)
        if not ok then self.logger.e("KeyCaster error: " .. tostring(err)) end
        return false
    end)
    self._tap:start()

    self:_ensureMenubar(true)
    self._followTimer = hs.timer.doEvery(self.config.followInterval, function()
        if self.config.mode == "column" then self:_renderColumnPositions() else self:_layoutLine() end
    end)
    if self.config.mode == "line" then
        self:_ensureLineCanvas(); self:_tickLine()
    end

    self.logger.i("KeyCaster started")
    return self
end

function obj:stop()
    if self._tap then
        self._tap:stop()
        self._tap = nil
    end
    if self._followTimer then
        self._followTimer:stop()
        self._followTimer = nil
    end
    self:_ensureMenubar(false)

    -- COLUMN cleanup
    for i = #self._items, 1, -1 do
        local it = self._items[i]; if it.timer then it.timer:stop() end; if it.canvas then it.canvas:delete() end; table
            .remove(self._items, i)
    end
    self._items = {}
    self._currentGroup = nil

    -- LINE cleanup
    if self._lineTimer then
        self._lineTimer:stop(); self._lineTimer = nil
    end
    if self._lineCanvas then
        self._lineCanvas:delete(); self._lineCanvas = nil
    end
    self._segments = {}

    self.logger.i("KeyCaster stopped")
    return self
end

function obj:bindHotkeys(mapping)
    local spec = mapping or self.defaultHotkeys
    if spec.start then hs.hotkey.bind(spec.start[1], spec.start[2], function() self:start() end) end
    if spec.stop then hs.hotkey.bind(spec.stop[1], spec.stop[2], function() self:stop() end) end
    return self
end

function obj:configure(tbl)
    if type(tbl) ~= "table" then return self end
    local merged = shallowCopy(self.config)
    for k, v in pairs(tbl) do merged[k] = v end
    self.config = merged
    -- normalize some derived bits
    self._resolvedFont = nil -- force re-resolve if font changed
    if self._tap then        -- live adjustments
        if self.config.mode == "line" then
            self:_ensureLineCanvas(); self:_layoutLine()
        else
            self:_renderColumnPositions()
        end
    end
    return self
end

return obj
