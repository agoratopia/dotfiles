local gh = require('config.pack').gh

-- Pretty diagnostics/quickfix/todo panel. Lazy-loaded on first use, same
-- reasoning as dap.lua/diffview.lua.
local loaded = false

local function ensure_loaded()
  if loaded then return end
  loaded = true
  vim.pack.add { gh 'folke/trouble.nvim' }
  require('trouble').setup {}
end

local function toggle(cmd)
  return function()
    ensure_loaded()
    vim.cmd(cmd)
  end
end

vim.keymap.set('n', '<leader>xx', toggle 'Trouble diagnostics toggle', { desc = 'Diagnostics (Trouble)' })
vim.keymap.set('n', '<leader>xX', toggle 'Trouble diagnostics toggle filter.buf=0', { desc = 'Buffer Diagnostics (Trouble)' })
vim.keymap.set('n', '<leader>xl', toggle 'Trouble loclist toggle', { desc = 'Location List (Trouble)' })
vim.keymap.set('n', '<leader>xq', toggle 'Trouble qflist toggle', { desc = 'Quickfix List (Trouble)' })
vim.keymap.set('n', '<leader>xt', toggle 'Trouble todo toggle', { desc = 'Todo (Trouble)' })
