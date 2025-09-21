# KeyCaster.spoon

![Demo](docs/demo.gif)

Display your recent keystrokes on screen — perfect for screen recording, live demos, and tutorials.

KeyCaster shows a tasteful overlay that **follows the monitor under your mouse**, with a **“KC” menubar icon** while active. It supports two display modes, a drag-anywhere anchor, and pixel-accurate, word-safe grouping so labels never break awkwardly.

> ⚠️ Privacy: KeyCaster only *visualizes* keystrokes in real time. It does **not** store, send, or log what you type.

---

> You might like these tools as well; [CursorScope](https://www.github.com/selimacerbas/CursorScope.spoon) [FocusMode](https://www.github.com/selimacerbas/FocusMode.spoon) 

---

## What’s new

* **Drag to move** (⌘⌥ + left-drag) — place the overlay anywhere on screen.
* **Deterministic across displays** — position stays in the *same relative spot* when you move to another monitor.
* **Menubar menu (KC)** — switch **Column / Line** from the menu; Start/Stop entry included.
* **Column mode**: pixel-measured fill (no early wraps), **hard grouping** (labels aren’t split), configurable `groupJoiner`.
* **Line mode**: default **overflow** behavior (no time fade; old segments drop only when off-box), optional `joiner`.
* Friendly glyphs for special keys (↩︎ ⎋ ⌫ arrows, F-keys) and modifiers (⌘⌥⌃⇧).

---

## Requirements

* [Hammerspoon](https://www.hammerspoon.org/) (recent versions)
* macOS with Accessibility permissions granted to Hammerspoon
  → `System Settings → Privacy & Security → Accessibility → enable Hammerspoon`.

---

## Installation

### Option A — Clone into your Spoons directory

```bash
mkdir -p ~/.hammerspoon/Spoons
cd ~/.hammerspoon/Spoons
# Replace the URL below with your repo URL once you publish it
git clone https://github.com/YOURNAME/KeyCaster.spoon KeyCaster.spoon
```

### Option B — Manual

Create the folder and copy `init.lua` into it:

```bash
mkdir -p ~/.hammerspoon/Spoons/KeyCaster.spoon
# Put init.lua here → ~/.hammerspoon/Spoons/KeyCaster.spoon/init.lua
```

Reload Hammerspoon after installation.

---

## Quick Start

Add to `~/.hammerspoon/init.lua`:

```lua
if hs.loadSpoon("KeyCaster") then
  spoon.KeyCaster
    :configure({
      -- Core
      mode = "column",               -- "column" | "line"
      fadingDuration = 2.0,
      maxVisible = 5,
      minAlphaWhileVisible = 0.35,
      followInterval = 0.40,
      ignoreAutoRepeat = true,

      -- Free placement (drag with ⌘⌥ to move)
      positionFree = { x = 20, y = 80 },  -- top-left anchor (px)

      -- Appearance
      font = { name = "Menlo", size = 18 },
      colors = {
        bg     = { red=0, green=0, blue=0, alpha=0.78 },
        text   = { red=1, green=1, blue=1, alpha=0.98 },
        stroke = { red=1, green=1, blue=1, alpha=0.15 },
        shadow = { red=0, green=0, blue=0, alpha=0.6 },
      },

      -- Column mode
      box = { w = 260, h = 36, spacing = 8, corner = 10 },
      column = {
        newBoxOnPause = 0.70,
        fillMode      = "measure",  -- pixel-based packing
        fillFactor    = 0.96,       -- new box when measured width > 96% of usable width
        hardGrouping  = true,       -- never split labels across boxes
        groupJoiner   = "",         -- "" for tight (e.g. ⌘C), " " or " " for spacing
        -- maxCharsPerBox is used only if you set fillMode="chars"
      },

      -- Line mode
      line = {
        box = { w = 520, h = 36, corner = 10 },
        maxSegments = 60,
        gap = 6,
        fadeMode = "overflow",      -- "overflow" = no time fade; trim when off-box, or "time"
        joiner = nil,                -- nil = reuse column.groupJoiner; "" or " " to override
      },

      -- Optional safety & filters
      respectSecureInput = true,    -- suppress while macOS secure input is active
      appFilter = nil,              -- e.g., { mode="deny", bundleIDs={"com.agilebits.onepassword7"} }
      showModifierOnly = false,     -- if true, show pure modifier chords (e.g., ⌘⇧)
      showMouse = { enabled = false, radius = 14, fade = 0.6, strokeAlpha = 0.35 }, -- click ripples
    })
    :bindHotkeys(spoon.KeyCaster.defaultHotkeys)
    :start() -- optional: start immediately
end
```

**Hotkeys**

* **Start**: ⌃⌥⌘K
* **Stop**:  ⌃⌥⌘F

You’ll see **KC** in the menubar while KeyCaster is active. Click it to switch **Column/Line** or to **Stop**.

---

## Usage Tips

* **Move the overlay**: hold **⌘⌥** and drag the box. The stack grows **down** if the anchor is in the top half, or **up** if it’s in the bottom half.
* **Multi-display**: the anchor is stored **normalized**, so it appears in the **same relative spot** when you move between monitors.
* **Grouping**:

  * Column mode uses **pixel-measured** packing and **hard grouping** so labels aren’t split.
  * Set `column.groupJoiner = " "` for a spaced look, or `" "` (thin space) for subtle separation.
  * Line mode prefixes `joiner` before every segment except the first (defaults to `column.groupJoiner`).

---

## Configuration Reference

> Call `spoon.KeyCaster:configure({...})` with any of the options below.

### Core

| Key                    | Type    | Default    | Description                                                                |
| ---------------------- | ------- | ---------- | -------------------------------------------------------------------------- |
| `mode`                 | string  | `"column"` | `"column"` or `"line"`.                                                    |
| `positionFree.x/y`     | number  | `20/80`    | Free placement anchor (px). Drag with ⌘⌥ to update.                        |
| `fadingDuration`       | number  | `2.0`      | Seconds to fade items (used when time-based fading is active).             |
| `maxVisible`           | integer | `5`        | Newest N items won’t fade below `minAlphaWhileVisible` until they age out. |
| `minAlphaWhileVisible` | number  | `0.35`     | Minimum opacity for items in the newest `maxVisible`.                      |
| `followInterval`       | number  | `0.40`     | How often (s) to re-lay out on the display under the mouse.                |
| `ignoreAutoRepeat`     | boolean | `true`     | Ignore key autorepeat events.                                              |

### Appearance

| Key             | Type   | Default        | Description                                                         |
| --------------- | ------ | -------------- | ------------------------------------------------------------------- |
| `font.name`     | string | `"Menlo"`      | Font name. The Spoon resolves to an available monospace if missing. |
| `font.size`     | number | `18`           | Font size (pt).                                                     |
| `colors.bg`     | rgba   | `{0,0,0,0.78}` | Background color.                                                   |
| `colors.text`   | rgba   | `{1,1,1,0.98}` | Text color.                                                         |
| `colors.stroke` | rgba   | `{1,1,1,0.15}` | Border color.                                                       |
| `colors.shadow` | rgba   | `{0,0,0,0.6}`  | Drop shadow color.                                                  |

### Column Mode

| Key                     | Type    | Default     | Description                                                                |
| ----------------------- | ------- | ----------- | -------------------------------------------------------------------------- |
| `box.w/h/spacing`       | number  | `260/36/8`  | Box width/height; vertical spacing (px).                                   |
| `box.corner`            | number  | `10`        | Corner radius (px).                                                        |
| `column.fillMode`       | string  | `"measure"` | `"measure"` uses pixel width; `"chars"` uses `maxCharsPerBox`.             |
| `column.fillFactor`     | number  | `0.96`      | Start a new box when measured width exceeds this fraction of usable width. |
| `column.newBoxOnPause`  | number  | `0.70`      | Start a new box after this many seconds of inactivity.                     |
| `column.hardGrouping`   | boolean | `true`      | Do not split labels across boxes.                                          |
| `column.groupJoiner`    | string  | `""`        | Joiner between labels when appending: `""`, `" "`, or `" "`.               |
| `column.maxCharsPerBox` | int     | `14`        | Only used when `fillMode="chars"`.                                         |

### Line Mode

| Key                | Type        | Default      | Description                                                                              |
| ------------------ | ----------- | ------------ | ---------------------------------------------------------------------------------------- |
| `line.box.w/h`     | number      | `520/36`     | Box width/height (px).                                                                   |
| `line.box.corner`  | number      | `10`         | Corner radius (px).                                                                      |
| `line.maxSegments` | integer     | `60`         | Max segments kept in memory.                                                             |
| `line.gap`         | number      | `6`          | Horizontal gap (px) between segments.                                                    |
| `line.fadeMode`    | string      | `"overflow"` | `"overflow"` (no time fade; drop when off-box) or `"time"` (fades by `fadingDuration`).  |
| `line.joiner`      | string\|nil | `nil`        | Prefix joiner before every segment except the first. `nil` → reuse `column.groupJoiner`. |

### Safety & Filters

| Key                  | Type       | Default | Description                                                         |
| -------------------- | ---------- | ------- | ------------------------------------------------------------------- |
| `respectSecureInput` | boolean    | `true`  | Suppress output when macOS *Secure Keyboard Entry* is active.       |
| `appFilter`          | table\|nil | `nil`   | e.g., `{ mode="deny", bundleIDs={"com.agilebits.onepassword7"} }`.  |
| `showModifierOnly`   | boolean    | `false` | If `true`, show pure modifier chords (e.g., ⌘⇧) when pressed alone. |
| `showMouse`          | table      | see QS  | Click ripples: `{ enabled, radius, fade, strokeAlpha }`.            |

### Hotkeys

```lua
-- Defaults
spoon.KeyCaster.defaultHotkeys = {
  start = { {"ctrl","alt","cmd"}, "K" },
  stop  = { {"ctrl","alt","cmd"}, "F" },
}

-- Use defaults
spoon.KeyCaster:bindHotkeys(spoon.KeyCaster.defaultHotkeys)

-- Or customize
spoon.KeyCaster:bindHotkeys({
  start = { {"ctrl","alt","cmd"}, "K" },
  stop  = { {"ctrl","alt","cmd"}, "F" },
})
```

---

## Examples

### 1) Column mode with tight grouping (default)

```lua
spoon.KeyCaster:configure({
  mode = "column",
  column = { groupJoiner = "", fillMode = "measure", fillFactor = 0.96 },
})
```

### 2) Column mode with a thin space joiner

```lua
spoon.KeyCaster:configure({
  mode = "column",
  column = { groupJoiner = " " }, -- U+2009 THIN SPACE
})
```

### 3) Line mode, spaced segments, no gap

```lua
spoon.KeyCaster:configure({
  mode = "line",
  line = { joiner = " ", gap = 0, fadeMode = "overflow" },
})
```

### 4) Time-fade line mode

```lua
spoon.KeyCaster:configure({
  mode = "line",
  line = { fadeMode = "time" },  -- uses fadingDuration
  fadingDuration = 1.6,
})
```

---

## Troubleshooting

* **Nothing appears**

  * Check Accessibility permission for Hammerspoon.
  * Ensure the Spoon path is `~/.hammerspoon/Spoons/KeyCaster.spoon/init.lua`.
  * Check Hammerspoon Console (⌘\`) for errors.

* **Menubar icon missing**

  * The **KC** icon shows **while active**. Start with ⌃⌥⌘K or `spoon.KeyCaster:start()`.

* **Overlay on wrong display**

  * The overlay follows the display under your **mouse**. Move the mouse to the target display.

* **Font errors**

  * Set `font.name` to an installed font (e.g., `"Menlo"`). The Spoon falls back gracefully.

---

## Contributing

PRs welcome!
Please update examples and the configuration table when adding features, and test both modes across single/multi-display setups.

## License

MIT License — see `LICENSE`.

---

## Credits

Built on the awesome [Hammerspoon](https://www.hammerspoon.org/) ecosystem. Thanks to the community for ideas and prior art around keystroke viewers.
