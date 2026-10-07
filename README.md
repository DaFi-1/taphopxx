# taphopxx

Pula para qualquer aba do Neovim com uma tecla: mostra uma linha com letras
(`a`–`z`) em ASCII art e o nome de cada aba, você digita a letra e vai.

## Instalação (LazyVim)

No seu `~/.config/nvim/lua/plugins/*.lua`:

```lua
return {
  "USUARIO/taphopxx", -- troque pelo seu repositório
  keys = {
    { "<Space>+", "<cmd>lua require('taphopxx').activate()<cr>", desc = "WinHop: pular para aba" },
  },
}
```

O plugin já registra o atalho `<Space>+` sozinho ao carregar; a chave acima é
opcional (serve só para adiar o carregamento até o primeiro uso).

## Uso

| Tecla   | Ação                                      |
| ------- | ----------------------------------------- |
| `<Space>+` | Abre a linha de letras e espera a tecla |
| letra (`a`, `b`, …) | Vai para a aba correspondente |
| `<Esc>` / `<C-c>` | Cancela                              |

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
