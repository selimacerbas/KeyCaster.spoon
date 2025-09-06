
# KeyCaster.spoon

![Demo](docs/demo.gif)

Display your recent keystrokes on screen — perfect for screen recording, live demos, and tutorials.

KeyCaster shows a tasteful overlay that **follows the monitor under your mouse**, with a menubar indicator while active. It supports two display modes, smooth fading, and a fully configurable position.

> ⚠️ Privacy: KeyCaster only *visualizes* keystrokes in real time. It does **not** store, send, or log what you type.

---

## Features

* **Two modes**

  * **Column** (default): stacked boxes; each box accumulates multiple keystrokes until a pause or char limit.
  * **Line**: a single box; new keys append on the right, oldest fade from the left.
* **Follows the active display** (the one under your mouse).
* **Configurable position** (any corner + margins).
* **Configurable fade** and visibility rules (keep the newest N at minimum opacity).
* **Menubar indicator** while active.
* **Start/Stop hotkeys** (default ⌃⌥⌘K / ⌃⌥⌘F).
* Friendly glyphs for special keys (↩︎ ⎋ ⌫ arrows, etc.) and modifiers (⌘⌥⌃⇧).

---

## Requirements

* [Hammerspoon](https://www.hammerspoon.org/) (tested on recent versions)
* macOS with Accessibility permissions granted to Hammerspoon

Grant permissions: `System Settings → Privacy & Security → Accessibility → enable Hammerspoon`.

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

Add to your `~/.hammerspoon/init.lua`:

```lua
if hs.loadSpoon("KeyCaster") then
  spoon.KeyCaster
    :configure({
      -- defaults shown; customize as you like
      mode = "column", -- "column" | "line"
      position = { corner = "bottomRight", x = 20, y = 80 },
      fadingDuration = 2.0,
      maxVisible = 5,
      minAlphaWhileVisible = 0.35,
      followInterval = 0.40,
      font = { name = "Menlo", size = 18 },
      colors = {
        bg    = { red=0, green=0, blue=0, alpha=0.78 },
        text  = { red=1, green=1, blue=1, alpha=0.98 },
        stroke= { red=1, green=1, blue=1, alpha=0.15 },
        shadow= { red=0, green=0, blue=0, alpha=0.6 },
      },
      -- Column mode visuals
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
      -- column/line specifics (see reference below)
    })
    :bindHotkeys(spoon.KeyCaster.defaultHotkeys)
end
```

Reload Hammerspoon. Start/stop with:

* **Start**: ⌃⌥⌘K
* **Stop**:  ⌃⌥⌘F

You’ll see a **⌨︎** in the menubar while KeyCaster is active.

---

## Configuration Reference

> Call `spoon.KeyCaster:configure({...})` with any of the options below.

### Core

| Key                    | Type    | Default         | Description                                                                             |
| ---------------------- | ------- | --------------- | --------------------------------------------------------------------------------------- |
| `mode`                 | string  | `"column"`      | `"column"` or `"line"` display mode.                                                    |
| `position.corner`      | string  | `"bottomRight"` | One of `"bottomRight"`, `"topRight"`, `"topLeft"`, `"bottomLeft"`.                      |
| `position.x`           | number  | `20`            | Horizontal inset (px) from the chosen left/right edge.                                  |
| `position.y`           | number  | `80`            | Vertical inset (px) from the chosen top/bottom edge.                                    |
| `fadingDuration`       | number  | `2.0`           | Seconds for a segment/box to fade from 1.0 alpha to 0 (or `minAlphaWhileVisible`).      |
| `maxVisible`           | integer | `5`             | The newest N segments/boxes won’t fade below `minAlphaWhileVisible` until they age out. |
| `minAlphaWhileVisible` | number  | `0.35`          | Minimum opacity while an item is among the newest `maxVisible`.                         |
| `followInterval`       | number  | `0.40`          | How often (seconds) the overlay repositions to the display under your mouse.            |
| `ignoreAutoRepeat`     | boolean | `true`          | Ignore key autorepeat events.                                                           |

### Appearance

| Key             | Type   | Default        | Description                                                                             |
| --------------- | ------ | -------------- | --------------------------------------------------------------------------------------- |
| `font.name`     | string | `"Menlo"`      | Font name. If missing/not installed, the Spoon resolves to an available monospace font. |
| `font.size`     | number | `18`           | Font size (pt).                                                                         |
| `colors.bg`     | rgba   | `{0,0,0,0.78}` | Background color of the box.                                                            |
| `colors.text`   | rgba   | `{1,1,1,0.98}` | Text color.                                                                             |
| `colors.stroke` | rgba   | `{1,1,1,0.15}` | Border color.                                                                           |
| `colors.shadow` | rgba   | `{0,0,0,0.6}`  | Drop shadow color.                                                                      |

### Column Mode

| Key                     | Type    | Default | Description                                                |
| ----------------------- | ------- | ------- | ---------------------------------------------------------- |
| `box.w`                 | number  | `260`   | Box width (px).                                            |
| `box.h`                 | number  | `36`    | Box height (px).                                           |
| `box.spacing`           | number  | `8`     | Vertical spacing between stacked boxes (px).               |
| `box.corner`            | number  | `10`    | Corner radius (px).                                        |
| `column.maxCharsPerBox` | integer | `14`    | Start a new box after this many glyphs in the current box. |
| `column.newBoxOnPause`  | number  | `0.70`  | Start a new box after this many seconds of inactivity.     |

### Line Mode

| Key                | Type    | Default | Description                            |
| ------------------ | ------- | ------- | -------------------------------------- |
| `line.box.w`       | number  | `520`   | Box width (px).                        |
| `line.box.h`       | number  | `36`    | Box height (px).                       |
| `line.box.corner`  | number  | `10`    | Corner radius (px).                    |
| `line.maxSegments` | integer | `60`    | Max number of segments kept in memory. |
| `line.gap`         | number  | `6`     | Horizontal gap (px) between segments.  |

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

### 1) Column mode, bottom-right (default)

```lua
spoon.KeyCaster:configure({
  mode = "column",
  position = { corner = "bottomRight", x = 20, y = 80 },
})
```

### 2) Column mode, top-right, denser boxes

```lua
spoon.KeyCaster:configure({
  mode = "column",
  position = { corner = "topRight", x = 20, y = 40 },
  box = { w = 300, h = 34, spacing = 6, corner = 8 },
  column = { maxCharsPerBox = 18, newBoxOnPause = 0.5 },
})
```

### 3) Line mode, top-left, wide bar

```lua
spoon.KeyCaster:configure({
  mode = "line",
  position = { corner = "topLeft", x = 24, y = 24 },
  line = { box = { w = 640, h = 40, corner = 10 }, maxSegments = 100, gap = 8 },
})
```

### 4) Theming

```lua
spoon.KeyCaster:configure({
  colors = {
    bg    = { red=0.10, green=0.10, blue=0.12, alpha=0.85 },
    text  = { red=0.96, green=0.96, blue=0.96, alpha=1.00 },
    stroke= { red=1.00, green=1.00, blue=1.00, alpha=0.12 },
    shadow= { red=0.00, green=0.00, blue=0.00, alpha=0.65 },
  },
  font = { name = "Menlo", size = 20 },
})
```

### 5) Ignore auto-repeat (default on) / change fade speed

```lua
spoon.KeyCaster:configure({
  ignoreAutoRepeat = true,
  fadingDuration = 1.6,
})
```

---

## Troubleshooting

* **Nothing appears**

  * Check Accessibility permission for Hammerspoon.
  * Ensure the Spoon folder is `~/.hammerspoon/Spoons/KeyCaster.spoon/` and the file is named `init.lua`.
  * Look for console errors in Hammerspoon (⌘\` to open Console).

* **Font errors** (`hs.canvas:textFont must be a string`)

  * Set `font.name` to an installed font, e.g. `"Menlo"`.
  * The Spoon auto-resolves fonts and falls back to Menlo.

* **Overlay on wrong display**

  * The overlay follows the monitor under your **mouse**. Move the mouse to the desired display.

* **Too many boxes**

  * Lower `maxVisible`, or shorten `fadingDuration`, or decrease `column.maxCharsPerBox`.

---

## Development

### Local dev

* Edit `~/.hammerspoon/Spoons/KeyCaster.spoon/init.lua` and reload Hammerspoon.
* The code avoids swallowing events and wraps the event tap in `pcall` to prevent stuck input if errors occur.

### Project layout

```
KeyCaster.spoon/
├── init.lua      -- Spoon implementation
└── README.md     -- This file
```

### Contributing

* PRs welcome! Please keep coding style close to upstream Hammerspoon Spoons.
* Add/update examples and the configuration reference for new options.
* Test both **column** and **line** modes, single and multi-display setups.


## Demo GIF

A demo GIF is referenced at `docs/demo.gif`. See **docs/DEMO\_GUIDE.md** to record and optimize one. Aim for < 2 MB so it loads fast on GitHub.

## License

MIT License — see `LICENSE`.

---

## Credits

Built on the awesome [Hammerspoon](https://www.hammerspoon.org/) ecosystem. Thanks to the community for ideas and prior art around keystroke viewers.
