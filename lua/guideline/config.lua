local M = {}

---@class GuideLine.Options.Ignore
---@field window fun(winid: integer): boolean
---@field buffer fun(bufnr: integer): boolean

---@class GuideLine.Options.Render.Component
---@field padding integer

---@class GuideLine.Options.Render.Buffer : GuideLine.Options.Render.Component
---@field gap integer

---@class GuideLine.Options.Render.Tabpage : GuideLine.Options.Render.Component

---@class GuideLine.Options.Render
---@field bufwin GuideLine.Options.Render.Buffer
---@field tabpage GuideLine.Options.Render.Tabpage

---@class GuideLine.OptionsStrict
---@field ignore GuideLine.Options.Ignore
---@field render GuideLine.Options.Render

---@class GuideLine.Options : GuideLine.OptionsStrict, {}

function M.make_defaults()
  ---@type GuideLine.OptionsStrict
  return {
    ignore = {
      buffer = function(bufnr)
        return vim.fn.bufname(bufnr) == "" and vim.fn.buflisted(bufnr) ~= 1
      end,
      window = function(winid)
        local config = vim.api.nvim_win_get_config(winid)
        return not config.focusable
      end,
    },
    render = {
      bufwin = {
        gap = 1,
        padding = 0,
      },
      tabpage = {
        padding = 0,
      },
    },
  }
end

---@type GuideLine.OptionsStrict
M.opts = M.make_defaults()

---@param opts? GuideLine.Options
function M.setup(opts)
  opts = opts or {}
  M.opts = vim.tbl_deep_extend("force", M.opts, opts)
end

return M
