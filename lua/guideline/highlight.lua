local api = vim.api
local fn = vim.fn

local M = {}

---@param name string
---@param fg string
local function set_hl(name, fg)
  local info = api.nvim_get_hl(0, { name = "GuideLine", link = false })
  info.fg = api.nvim_get_hl(0, { name = fg, link = false }).fg
  ---@diagnostic disable-next-line: param-type-mismatch
  api.nvim_set_hl(0, name, info)
end

---@param color integer
---@return integer
local function darken(color)
  local factor = 0.7
  local x = color
  local r = math.floor(x / 2 ^ 16)
  color = x - (r * 2 ^ 16)
  local g = math.floor(color / 2 ^ 8)
  local b = math.floor(color - (g * 2 ^ 8))
  return math.floor(
    math.floor(r * factor) * 2 ^ 16
      + math.floor(g * factor) * 2 ^ 8
      + math.floor(b * factor)
  )
end

---@param name string
local function derive_hl_nc(name)
  local info = api.nvim_get_hl(0, { name = name, link = false })
  info.fg = darken(info.fg)
  ---@diagnostic disable-next-line: param-type-mismatch
  api.nvim_set_hl(0, name .. "NC", info)
end

---@param name string
local function derive_hl_sel(name)
  local info = api.nvim_get_hl(0, { name = "GuideLineSel", link = false })
  info.fg = api.nvim_get_hl(0, { name = name, link = false }).fg
  ---@diagnostic disable-next-line: param-type-mismatch
  api.nvim_set_hl(0, name .. "Sel", info)
end

---@param name string
local function derive_hl_nc_sel(name)
  derive_hl_nc(name)
  derive_hl_sel(name)
  derive_hl_sel(name .. "NC")
end

local palette = {
  GuideLineIcon = "Keyword",
  GuideLineLabelHead = "FloatTitle",
  GuideLineLabelTail = "Normal",
  GuideLineCount = "Normal",
  GuideLineModified = "Identifier",
  GuideLineSeparator = "LineNr",
}
for i = 1, 4 do
  local severity = vim.diagnostic.severity[i]:lower():gsub("^%a", string.upper)
  palette["GuideLineDiagnostic" .. severity] = "Diagnostic" .. severity
end

---@param name string
---@return string, string
function M.get_icon_hl(name)
  local ext = fn.fnamemodify(name, ":e")
  local _, devicons = pcall(require, "nvim-web-devicons")
  if not devicons then
    return " ", "GuideLineIcon"
  end
  local icon, hl_dev = devicons.get_icon(name, ext)
  if not icon or not hl_dev then
    return " ", "GuideLineIcon"
  end
  local hl = hl_dev:gsub("^Dev", "GuideLine")
  if next(api.nvim_get_hl(0, { name = hl, link = false })) == nil then
    set_hl(hl, hl_dev)
    derive_hl_nc_sel(hl)
  end
  return icon, hl
end

function M.clear()
  for name in pairs(palette) do
    api.nvim_set_hl(0, name, {})
  end
end

function M.setup()
  api.nvim_set_hl(0, "GuideLineSel", {
    bg = api.nvim_get_hl(0, {
      name = "Normal",
      link = false,
    }).bg,
  })
  api.nvim_set_hl(0, "GuideLine", {
    bg = api.nvim_get_hl(0, {
      name = "NormalFloat",
      link = false,
    }).bg,
    sp = api.nvim_get_hl(0, {
      name = "LineNr",
      link = false,
    }).fg,
    underline = true,
  })

  for name, fg in pairs(palette) do
    set_hl(name, fg)
  end

  for name in pairs(palette) do
    derive_hl_nc_sel(name)
  end

  api.nvim_set_hl(0, "GuideLineFill", {
    bg = api.nvim_get_hl(0, {
      name = "StatusLine",
      link = false,
    }).bg,
    sp = api.nvim_get_hl(0, {
      name = "LineNr",
      link = false,
    }).fg,
    underline = true,
  })
  api.nvim_set_hl(0, "GuideLineSeparatorFill", {
    fg = api.nvim_get_hl(0, {
      name = "GuideLineSeparator",
      link = false,
    }).fg,
    bg = api.nvim_get_hl(0, {
      name = "GuideLineFill",
    }).bg,
    sp = api.nvim_get_hl(0, {
      name = "GuideLineFill",
      link = false,
    }).sp,
    underline = true,
  })
end

return M
