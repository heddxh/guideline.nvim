local api = vim.api
local guideline = require "guideline"
local highlight = require "guideline.highlight"

local augroup = api.nvim_create_augroup("guideline.nvim", {})

highlight.setup()
api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  desc = "Clear guideline.nvim highlights",
  callback = function ()
    highlight.clear()
  end
})
api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  desc = "Update guideline.nvim highlights",
  callback = function()
    highlight.setup()
  end,
})

_G.guideline = guideline
vim.o.tabline = "%!v:lua.guideline()"
