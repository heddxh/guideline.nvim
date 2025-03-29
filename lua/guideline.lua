local api = vim.api
local fn = vim.fn

local config = require "guideline.config"
local highlight = require "guideline.highlight"

---@param hl string
---@param s string
---@param current? boolean Default to true
---@param select? boolean Default to true
local function hl_string(hl, s, current, select)
  current = current == nil or current == true
  select = select == nil or select == true
  return s == "" and s
    or ("%%#%s%s%s#%s"):format(
      hl,
      current and "" or "NC",
      select and "Sel" or "",
      s
    )
end

---@param components string[]
---@param sep? string
local function render_components(components, sep)
  sep = sep and sep:gsub("%%", "%%%%")
  return ("%s"):rep(#components, sep):format(unpack(components))
end

---@class GuideLine.Buffer
---@field bufnr integer
---@field name string
---@field label string
---@field modified boolean
---@field level_diagnostics table<1|2|3|4, vim.Diagnostic[]>
local Buffer = {}

---@param bufnr integer
---@return GuideLine.Buffer
function Buffer.new(bufnr)
  ---@type GuideLine.Buffer
  local self = setmetatable({}, Buffer)

  self.bufnr = bufnr
  self.name = api.nvim_buf_get_name(bufnr)
  self.label = self.name == "" and "[No Name]"
    or fn.fnamemodify(self.name, ":t")
  self.modified = vim.bo[bufnr].modified

  self.level_diagnostics = {}
  for i = 1, 4 do
    self.level_diagnostics[i] = vim.diagnostic.get(bufnr, { severity = i })
  end

  return self
end

---A `BufWin` is a `buffer` that is displayed
---by windows with `winids`
---in one specific `tabpage`
---
---@class GuideLine.BufWin
---@field buffer GuideLine.Buffer
---@field winids integer[]
---
---Any of the window is the current window in `self.tabpage`
---@field current boolean
---
---Minimum window number
---@field winnr integer
---
---@field tabpage GuideLine.Tabpage
local BufWin = {}

---@return GuideLine.BufWin
function BufWin.new(buffer, winids, tabpage)
  ---@type GuideLine.BufWin
  local self = setmetatable({}, { __index = BufWin })
  self.tabpage = tabpage
  self.buffer = buffer
  self.winids = winids
  return self
end

---@return string
function BufWin:render()
  local buffer = self.buffer
  local winids = self.winids
  local current = self.current
  local select = self.tabpage.current

  local components = {}

  local icon, hl = highlight.get_icon_hl(buffer.name)
  components[#components + 1] = hl_string(hl, icon, current, select)

  local path = fn.split(buffer.label, "/")
  local head = #path == 1 and ""
    or hl_string(
      "GuideLineLabelHead",
      table.concat(path, "/", 1, #path - 1) .. "/",
      current,
      select
    )
  local tail = hl_string("GuideLineLabelTail", path[#path], current, select)
  components[#components + 1] = head .. tail

  if #winids > 1 then
    local count =
      hl_string("GuideLineCount", ("× %d"):format(#winids), current, select)
    components[#components + 1] = count
  end

  if buffer.modified then
    local modified = hl_string("GuideLineModified", "[+]", current, select)
    components[#components + 1] = modified
  end

  local diagnostic_components = {}
  for i = 1, 4 do
    local n = #buffer.level_diagnostics[i]
    if n ~= 0 then
      local signs = (vim.diagnostic.config() or {}).signs
      local text = type(signs) == "table" and signs.text[i]
        or vim.diagnostic.severity[i]:sub(1, 1)
      diagnostic_components[#diagnostic_components + 1] = hl_string(
        ("GuideLineDiagnostic%s"):format(
          vim.diagnostic.severity[i]:lower():gsub("^%a", string.upper)
        ),
        ("%s%d"):format(text, n),
        current,
        select
      )
    end
  end
  local rendered_diagnostics = render_components(diagnostic_components, " ")
  if rendered_diagnostics ~= "" then
    components[#components + 1] = rendered_diagnostics
  end

  local gap = config.opts.render.bufwin.gap
  local padding = config.opts.render.bufwin.padding
  return (" "):rep(padding)
    .. render_components(components, (" "):rep(gap))
    .. (" "):rep(padding)
end

---@class GuideLine.Tabpage
---@field tabid integer
---@field bufnr_bufwins table<integer, GuideLine.BufWin?>
---
---Is current tabpage
---@field current boolean
---
---@field guideline GuideLine
local Tabpage = {}

---@param guideline GuideLine
---@param tabid integer
---@return GuideLine.Tabpage
function Tabpage.new(tabid, guideline)
  ---@type GuideLine.Tabpage
  local self = setmetatable({}, { __index = Tabpage })
  self.guideline = guideline
  self.tabid = tabid
  self.current = tabid == api.nvim_get_current_tabpage()

  self.bufnr_bufwins = {}
  local bufnr_bufwin = self.bufnr_bufwins
  for _, winid in ipairs(api.nvim_tabpage_list_wins(tabid)) do
    if not config.opts.ignore.window(winid) then
      local bufnr = api.nvim_win_get_buf(winid)
      if not config.opts.ignore.buffer(bufnr) then
        local buffer = self.guideline.bufnr_buffer[bufnr]
        if not buffer then
          buffer = Buffer.new(bufnr)
          self.guideline.bufnr_buffer[bufnr] = buffer
        end

        local bufwin = bufnr_bufwin[bufnr]
        if bufwin then
          bufwin.winids[#bufwin.winids + 1] = winid
        else
          bufwin = BufWin.new(buffer, { winid }, self)
          bufnr_bufwin[bufnr] = bufwin
        end
        bufwin.current = bufwin.current
          or api.nvim_tabpage_get_win(tabid) == winid
        bufwin.winnr =
          math.min(bufwin.winnr or math.huge, api.nvim_win_get_number(winid))
      end
    end
  end

  return self
end

---@return string
function Tabpage:render()
  local tabid = self.tabid
  local select = tabid == api.nvim_get_current_tabpage()

  -- Insert bufwins, order by `winnr`
  local bufwin_components = {}
  local winnr_bufwins = {}
  for _, bufwin in pairs(self.bufnr_bufwins) do
    winnr_bufwins[bufwin.winnr] = bufwin
  end
  local bufwins = {}
  for i = 1, fn.tabpagewinnr(api.nvim_tabpage_get_number(tabid), "$") do
    local bufwin = winnr_bufwins[i]
    if bufwin then
      bufwins[#bufwins + 1] = bufwin
      local rendered_bufwin = bufwin:render()
      if rendered_bufwin ~= "" then
        bufwin_components[#bufwin_components + 1] = rendered_bufwin
      end
    end
  end
  local rendered_bufwins = render_components(bufwin_components, " ")

  -- Render empty only when there are no other tabs
  if rendered_bufwins == "" and #api.nvim_list_tabpages() == 1 then
    return ""
  end

  local padding = config.opts.render.tabpage.padding
  return render_components {
    select and "%#GuideLineSel#" or "%#GuideLine#",
    ("%%%dT"):format(api.nvim_tabpage_get_number(tabid)),
    hl_string(
      "GuideLineSeparator",
      api.nvim_tabpage_get_number(tabid) == 1 and "▎" or "▏",
      nil,
      select
    ),
    (" "):rep(padding),
    rendered_bufwins,
    (" "):rep(padding),
    hl_string("GuideLineSeparator", "▕", nil, select),
    "%T",
  }
end

---@class GuideLine
---@field bufnr_buffer table<integer, GuideLine.Buffer?>
---@field tabid_tabpage table<integer, GuideLine.Tabpage?>
local GuideLine = {}

---@return GuideLine
function GuideLine.new()
  ---@type GuideLine
  local self = setmetatable({}, { __index = GuideLine })
  self.bufnr_buffer = {}

  self.tabid_tabpage = {}
  local tabid_tabpage = self.tabid_tabpage
  for _, tabid in ipairs(api.nvim_list_tabpages()) do
    tabid_tabpage[tabid] = Tabpage.new(tabid, self)
  end

  return self
end

---@param t string[][]
---@return string[][]
local function shortest_unique_suffixes(t)
  local root = { count = 0, children = {} }

  for _, path in ipairs(t) do
    local node = root
    for i = #path, 1, -1 do
      local segment = path[i]
      local child = node.children[segment]
      if not child then
        child = { count = 0, children = {} }
        node.children[segment] = child
      end
      child.count = child.count + 1
      node = child
    end
  end

  local labels = {}
  for index, path in ipairs(t) do
    local node = root
    local start = 1
    for i = #path, 1, -1 do
      node = node.children[path[i]]
      start = i
      if node.count == 1 then
        break
      end
    end
    labels[index] = { unpack(path, start) }
  end

  return labels
end

---Deduplicate buffer labels
function GuideLine:deduplicate()
  ---@type table<string, GuideLine.Buffer[]?>
  local label_buffers = {}
  for _, buffer in pairs(self.bufnr_buffer) do
    local buffers = label_buffers[buffer.label]
    if buffers then
      buffers[#buffers + 1] = buffer
    else
      label_buffers[buffer.label] = { buffer }
    end
  end
  for label, buffers in pairs(label_buffers) do
    if label ~= "[No Name]" and #buffers > 1 then
      ---@type string[][]
      local paths = {}
      for _, buffer in ipairs(buffers) do
        paths[#paths + 1] = vim.split(buffer.name, "/", {
          plain = true,
          trimempty = true,
        })
      end
      local labels = shortest_unique_suffixes(paths)
      for i, buffer in ipairs(buffers) do
        buffer.label = table.concat(labels[i], "/")
      end
    end
  end
end

function GuideLine:render()
  local components = {}

  self:deduplicate()

  -- Insert tabpages, order by `tabnr`
  local tabpage_components = {}
  for tabid, tabpage in pairs(self.tabid_tabpage) do
    tabpage_components[api.nvim_tabpage_get_number(tabid)] = tabpage:render()
  end
  local rendered_tabpages = render_components(tabpage_components)
  if rendered_tabpages ~= "" then
    components[#components + 1] = rendered_tabpages
    components[#components + 1] = "%#GuideLineSeparatorFill#▏"
  end
  components[#components + 1] = "%#GuideLineFill#"

  return render_components(components)
end

GuideLine.setup = config.setup

return setmetatable(GuideLine, {
  __call = function()
    return GuideLine.new():render()
  end,
})
