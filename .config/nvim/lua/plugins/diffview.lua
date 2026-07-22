local gh = require('config.pack').gh

-- Full-file/full-diff review views on top of gitsigns' hunk-level tooling.
-- Deferred until first use, same reasoning as dap.lua.
local loaded = false

local function ensure_loaded()
  if loaded then return end
  loaded = true
  vim.pack.add { gh 'sindrets/diffview.nvim' }
  require('diffview').setup {}
end

vim.keymap.set('n', '<leader>gd', function()
  ensure_loaded()
  vim.cmd.DiffviewOpen()
end, { desc = '[G]it [D]iff view (working tree vs HEAD)' })

vim.keymap.set('n', '<leader>gh', function()
  ensure_loaded()
  vim.cmd.DiffviewFileHistory()
end, { desc = '[G]it file [H]istory' })

vim.keymap.set('n', '<leader>gq', function()
  ensure_loaded()
  vim.cmd.DiffviewClose()
end, { desc = '[G]it diff view close' })
