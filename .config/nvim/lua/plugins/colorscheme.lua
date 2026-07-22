local gh = require('config.pack').gh

vim.pack.add { gh 'rebelot/kanagawa.nvim' }
---@diagnostic disable-next-line: missing-fields
require('kanagawa').setup {}

-- Other variants: kanagawa-wave (default/mid-contrast), kanagawa-lotus (light)
vim.cmd.colorscheme 'kanagawa-dragon'
