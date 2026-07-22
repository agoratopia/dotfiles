local gh = require('config.pack').gh

-- Run the test under your cursor and see pass/fail inline. Lazy-loaded on
-- first use, same reasoning as dap.lua/diffview.lua/trouble.lua.
local loaded = false

local function ensure_loaded()
  if loaded then return end
  loaded = true

  vim.pack.add {
    gh 'nvim-neotest/nvim-nio',
    gh 'nvim-neotest/neotest',
    gh 'nvim-neotest/neotest-go',
    gh 'nvim-neotest/neotest-python',
    gh 'rouge8/neotest-rust',
  }

  require('neotest').setup {
    adapters = {
      require 'neotest-go',
      require 'neotest-python',
      require 'neotest-rust',
    },
  }
end

local function neotest_cmd(fn)
  return function()
    ensure_loaded()
    fn()
  end
end

vim.keymap.set('n', '<leader>tr', neotest_cmd(function() require('neotest').run.run() end), { desc = '[T]est [R]un nearest' })
vim.keymap.set('n', '<leader>tf', neotest_cmd(function() require('neotest').run.run(vim.fn.expand '%') end), { desc = '[T]est run [F]ile' })
vim.keymap.set('n', '<leader>ts', neotest_cmd(function() require('neotest').summary.toggle() end), { desc = '[T]est [S]ummary' })
vim.keymap.set('n', '<leader>to', neotest_cmd(function() require('neotest').output.open { enter = true } end), { desc = '[T]est [O]utput' })
vim.keymap.set(
  'n',
  '<leader>td',
  neotest_cmd(function()
    -- Ensure nvim-dap (and its adapters/configurations) are loaded before
    -- neotest hands off to the 'dap' strategy.
    require('plugins.dap').load()
    require('neotest').run.run { strategy = 'dap' }
  end),
  { desc = '[T]est [D]ebug nearest' }
)
