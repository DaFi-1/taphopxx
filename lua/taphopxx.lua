-- lua/taphopxx.lua
local window_hop = {}

local api = vim.api

local labels = {
  "a","b","c","d","e","f","g","h","i","j","k","l",
  "m","n","o","p","q","r","s","t","u","v","w","x",
  "y","z"
}

-- Índice reverso letra -> posição: busca O(1) da tecla digitada
local label_index = {}
local upper_rows = {} -- letra simples em maiúsculas, pronta de fábrica
for i, label in ipairs(labels) do
  label_index[label] = i
  upper_rows[i] = { label:upper() }
end

local ESC = "\27"
local BORDER = 2 -- a borda soma 1 célula de cada lado (largura e altura)
local PAD = 1 -- respiro interno de 1 caractere em relação à borda
local WINHL = "Normal:WinHopLabel,FloatBorder:WinHopBorder"
local HIGH = "[\128-\255]" -- byte alto: nome não é ASCII puro
local UTF8 = "[%z\1-\127\194-\244][\128-\191]*" -- exatamente 1 codepoint UTF-8
local UPPER_W = { 1 } -- toda letra simples ocupa 1 coluna

-- Grupo de destaque próprio (o usuário pode sobrescrever)
local function set_highlights()
  api.nvim_set_hl(0, "WinHopLabel", { fg = "#FFFFFF", bold = true, default = true })
  api.nvim_set_hl(0, "WinHopBorder", { fg = "#FFFFFF", default = true })
  api.nvim_set_hl(0, "WinHopName", { fg = "#FFFFFF", default = true })
end
set_highlights()

-- :colorscheme limpa os grupos, então reaplica depois de trocar o tema
api.nvim_create_autocmd("ColorScheme", {
  group = api.nvim_create_augroup("WinHopHighlights", { clear = true }),
  callback = set_highlights,
})

local ns = api.nvim_create_namespace("winhop")

-- Largura em colunas: sem byte alto, bytes == colunas (não chama o Vim)
local strwidth = api.nvim_strwidth
local function dwidth(s)
  if not s:find(HIGH) then return #s end
  return strwidth(s)
end

local function rep(ch, n)
  if n <= 0 then return "" end
  return string.rep(ch, n)
end

-- Centraliza `s` sabendo a sua largura: O(1), sem recalcular
local function pad(s, dw, width)
  if dw >= width then return s end
  local left = math.floor((width - dw) / 2)
  return rep(" ", left) .. s .. rep(" ", width - dw - left)
end

-- Maior prefixo de `s` que cabe em `max_w` colunas
local function cut(s, max_w)
  if dwidth(s) <= max_w then return s end
  if not s:find(HIGH) then return s:sub(1, max_w) end
  local out = ""
  for ch in s:gmatch(UTF8) do
    if dwidth(out .. ch) > max_w then break end
    out = out .. ch
  end
  return out
end

-- Trunca com reticências; devolve também a largura final (evita recalcular)
local function truncate(s, w, max_w)
  if w <= max_w then return s, w end
  local head = cut(s, max_w - 1)
  return head .. "…", dwidth(head) + 1
end

-- Letras em ASCII art (FIGlet "banner3"): montadas uma única vez para sempre
local letter_cache = {}
local function letter(label)
  local entry = letter_cache[label]
  if not entry then
    local rows = require("taphopxx.font")[label]
    local widths, width = {}, 0
    for i, row in ipairs(rows) do
      widths[i] = dwidth(row)
      if widths[i] > width then width = widths[i] end
    end
    entry = { rows = rows, widths = widths, width = width }
    letter_cache[label] = entry
  end
  return entry
end

-- Nome da aba: t:winhop_name se existir, senão o arquivo ativo, senão um placeholder
local function tab_name(tab)
  local ok, name = pcall(api.nvim_tabpage_get_var, tab, "winhop_name")
  if ok and type(name) == "string" and name ~= "" then return name end
  local win = api.nvim_tabpage_get_win(tab)
  local fname = api.nvim_buf_get_name(api.nvim_win_get_buf(win))
  if fname ~= "" then return vim.fs.basename(fname) end
  return "[sem nome]"
end

-- Nomes e larguras resolvidos 1x por ativação (chamada de API é o que custa)
local function collect(tabs)
  local items = {}
  for i, tab in ipairs(tabs) do
    local name = tab_name(tab)
    items[i] = { label = labels[i], name = name, w = dwidth(name), lw = letter(labels[i]).width }
  end
  return items
end

-- Escada de layout: do mais generoso ao mais enxuto
local FIT = {
  { big = true,  gap = 2, cap = 20 },
  { big = true,  gap = 1, cap = 12 },
  { big = false, gap = 2, cap = 16 },
  { big = false, gap = 1, cap = 8 },
  { big = false, gap = 1, cap = 5 },
  { big = false, gap = 1, cap = 4 },
  { big = false, gap = 0, cap = 3 },
  { big = false, gap = 0, cap = 2 },
}

-- Largura total só somando: nenhum buffer é montado para descartar depois
local function total_width(items, cfg)
  local width = 0
  for _, it in ipairs(items) do
    local lw = cfg.big and it.lw or 1
    local nw = it.w < cfg.cap and it.w or cfg.cap
    local cw = lw > nw and lw or nw
    width = width + cw
  end
  return width + cfg.gap * (#items - 1)
end

-- Escolhe o layout que cabe na tela; O(t abas * 6 configs) em aritmética pura
local function pick_cfg(items, avail_w, avail_h)
  -- letra (N linhas) + 1 linha de espaçamento + nome + 1 de topo + 1 de base
  local big_h = #letter("a").rows + 2 + 2 * PAD
  local compact_h = 1 + 2 + 2 * PAD
  for _, cfg in ipairs(FIT) do
    local h = (cfg.big and big_h or compact_h) + BORDER
    if h <= avail_h and total_width(items, cfg) + 2 * PAD + BORDER <= avail_w then
      return cfg
    end
  end
  return FIT[#FIT] -- nada coube: build_view recorta para o tamanho da tela
end

-- Monta a linha final: letra em cima, nome da aba embaixo, um bloco por aba
local function build_view(items, cfg, avail_w, avail_h)
  local cols, gap = {}, cfg.gap
  local width = 0
  for i, it in ipairs(items) do
    local rows, widths, lw
    if cfg.big then
      local let = letter(it.label)
      rows, widths, lw = let.rows, let.widths, let.width
    else
      rows, widths, lw = upper_rows[i], UPPER_W, 1
    end
    local name, nw = truncate(it.name, it.w, cfg.cap)
    local cw = lw > nw and lw or nw
    cols[#cols + 1] = { rows = rows, widths = widths, name = name, nw = nw, width = cw }
    width = width + cw
  end
  width = width + gap * (#cols - 1)
  local rows_n = #cols[1].rows

  -- conteúdo: linhas da letra, 1 linha em branco, linha com o nome da aba
  local sep = rep(" ", gap)
  local content = {}
  for r = 1, rows_n do
    local parts = {}
    for _, col in ipairs(cols) do
      parts[#parts + 1] = pad(col.rows[r], col.widths[r], col.width)
    end
    content[r] = table.concat(parts, sep)
  end
  local name_parts = {}
  for _, col in ipairs(cols) do
    name_parts[#name_parts + 1] = pad(col.name, col.nw, col.width)
  end
  content[rows_n + 1] = rep(" ", width) -- espaçamento de 1 linha letra/nome
  content[rows_n + 2] = table.concat(name_parts, sep)

  -- respiro de 1 caractere em relação à borda (topo, base e laterais)
  local padded_w = width + 2 * PAD
  local lines = { rep(" ", padded_w) } -- topo
  for i = 1, rows_n + 2 do
    lines[i + 1] = rep(" ", PAD) .. content[i] .. rep(" ", PAD)
  end
  lines[rows_n + 4] = rep(" ", padded_w) -- base

  local max_w = math.max(1, math.min(padded_w, avail_w))
  local height = math.max(1, math.min(rows_n + 4, avail_h))
  local need_cut = padded_w > max_w
  while #lines > height do
    table.remove(lines, 1) -- preserva a linha do nome se faltar espaço em altura
  end
  for i, line in ipairs(lines) do
    lines[i] = need_cut and cut(line, max_w) or line
  end
  return { lines = lines, width = max_w, height = height }
end

-- Buffer e float reaproveitados entre ativações; recriados se alguém os apagar
local state = {}

local function ensure_buf(lines)
  if not (state.buf and api.nvim_buf_is_valid(state.buf)) then
    state.buf = api.nvim_create_buf(false, true)
  end
  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  -- Nome da aba sem negrito (a letra continua em WinHopLabel)
  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  api.nvim_buf_add_highlight(state.buf, ns, "WinHopName", #lines - 1, 0, -1)
end

-- Devolve o float se ele já estiver na aba atual; senão fecha o que sobrou
local function live_float(tab)
  local f = state.float
  if not f or not api.nvim_win_is_valid(f) then return nil end
  if api.nvim_win_get_tabpage(f) == tab then return f end
  pcall(api.nvim_win_close, f, true)
  return nil
end

-- Mostra a linha de etiquetas centralizada na tela
local function show_float(view, avail_w, avail_h)
  local float = live_float(api.nvim_get_current_tabpage())
  state.float = float

  local cfg = {
    relative = "editor",
    row = math.max(0, math.floor((avail_h - view.height - BORDER) / 2)),
    col = math.max(0, math.floor((avail_w - view.width - BORDER) / 2)),
    width = view.width,
    height = view.height,
    hide = false,
  }

  if float then
    api.nvim_win_set_config(float, cfg) -- caminho comum: só reposiciona
    return float
  end

  cfg.style = "minimal"
  cfg.border = "rounded"
  cfg.focusable = false
  cfg.noautocmd = true
  cfg.zindex = 250
  float = api.nvim_open_win(state.buf, false, cfg)
  vim.wo[float].winhl = WINHL
  state.float = float
  return float
end

-- Esconde o float em vez de destruí-lo, mantendo o custo de reabrir constante
local function hide_float()
  local f = state.float
  if f and api.nvim_win_is_valid(f) then
    pcall(api.nvim_win_set_config, f, { hide = true })
  end
end

local function prompt(tabs)
  local avail_w = vim.o.columns - 1
  local avail_h = vim.o.lines - vim.o.cmdheight - 1
  local items = collect(tabs)
  local view = build_view(items, pick_cfg(items, avail_w, avail_h), avail_w, avail_h)
  ensure_buf(view.lines)

  local ok, key = pcall(function()
    show_float(view, avail_w, avail_h)
    -- Garante que as letras aparecem antes de esperar a tecla
    vim.cmd.redraw()
    -- <C-c> lança erro aqui; o pcall externo trata como cancelamento
    return vim.fn.getcharstr()
  end)
  hide_float()
  if ok then return key end
end

function window_hop.activate()
  local tabs = api.nvim_list_tabpages()
  if #tabs < 2 then return end -- uma aba só: não há para onde pular

  if #tabs > #labels then
    vim.notify("WinHop: só as " .. #labels .. " primeiras abas têm rótulo", vim.log.levels.WARN)
    local capped = {}
    for i = 1, #labels do capped[i] = tabs[i] end
    tabs = capped
  end

  local key = prompt(tabs)
  if not key or key == ESC then return end -- <C-c> ou <Esc> cancelam

  local idx = label_index[key:lower()]
  local tab = idx and tabs[idx]
  if not tab or not api.nvim_tabpage_is_valid(tab) then
    vim.notify("Letra inválida ❗", vim.log.levels.WARN)
    return
  end
  local jumped, err = pcall(api.nvim_set_current_tabpage, tab)
  if not jumped then
    vim.notify(err, vim.log.levels.WARN)
  end
end

-- setup permite ativar via keymap apenas quando o usuário quiser
function window_hop.setup()
  vim.keymap.set("n", "<Space>e", window_hop.activate, {
    silent = true,
    desc = "WinHop: pular para aba",
  })
end

return window_hop
