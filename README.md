# taphopxx

Pula para qualquer aba do Neovim com uma tecla: mostra uma linha com letras
(`a`–`z`) em ASCII art e o nome de cada aba, você digita a letra e vai.

Atalho: **`<Space>+`** (espaço e mais).

## Instalação

### 1. lazy.nvim (instalador)

Se você ainda não tem o gerenciador de pacotes, cole no seu
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

No LazyVim, crie `~/.config/nvim/lua/plugins/taphopxx.lua`:

```lua
return {
  "DaFi-1/taphopxx",
}
```

Ou, no `require("lazy").setup({...})` do `init.lua`:

```lua
{ "DaFi-1/taphopxx" },
```

O atalho `<Space>+` é registrado sozinho quando o plugin carrega (no início do
Neovim).

## Uso

| Tecla              | Ação                                |
| ------------------ | ----------------------------------- |
| `<Space>+`         | Abre a linha de letras e espera     |
| letra (`a`, `b`, …) | Vai para a aba correspondente      |
| `<Esc>` / `<C-c>`  | Cancela                             |

Só existem rótulos para as 26 primeiras abas.

## Nome da aba

A ordem é:

1. `vim.t.winhop_name`, se definido;
2. nome do arquivo ativo da aba;
3. `[sem nome]`.

```lua
vim.t.winhop_name = "meu projeto"
```

## Aparência

Os grupos `WinHopLabel`, `WinHopBorder` e `WinHopName` são definidos com
`default = true`, então basta defini-los no seu core colorscheme para mudar as
cores.
