# taphopxx

Jump to any Neovim tab with one key: it shows a row of ASCII-art letters
(`a`–`z`) with each tab name; type the letter and go.

Shortcut: **`<Space>e`** (space and "e").

## Installation

### 1. lazy.nvim (installer)

If you don't have the package manager yet, paste this into your
`~/.config/nvim/init.lua`:

```lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
```

### 2. Plugin

In LazyVim, create `~/.config/nvim/lua/plugins/taphopxx.lua`:

```lua
return {
  "DaFi-1/taphopxx",
}
```

Or inside the `require("lazy").setup({...})` call in your `init.lua`:

```lua
{ "DaFi-1/taphopxx" },
```

The `<Space>e` shortcut is registered automatically when the plugin loads
(at Neovim startup).

## Usage

| Key                  | Action                             |
| -------------------- | ---------------------------------- |
| `<Space>e`           | Show the letter row and wait       |
| letter (`a`, `b`, …) | Go to the matching tab             |
| `<Esc>` / `<C-c>`    | Cancel                             |

Labels only cover the first 26 tabs.

## Tab name

Resolved in this order:

1. `vim.t.winhop_name`, if set;
2. name of the active file in the tab;
3. `[sem nome]`.

```lua
vim.t.winhop_name = "my project"
```

## Appearance

The `WinHopLabel`, `WinHopBorder` and `WinHopName` highlight groups are
defined with `default = true`, so just define them in your core colorscheme
to change the colors.
