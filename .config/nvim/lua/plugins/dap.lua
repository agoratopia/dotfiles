local gh = require('config.pack').gh

-- Debug Adapter Protocol: breakpoints, step-through, variable inspection.
-- Deferred until the first debug keymap is actually used, since debugging
-- is occasional rather than every-session, and this is 7 plugins worth of load.
local loaded = false

local function load_dap()
  if loaded then return end
  loaded = true

  vim.pack.add {
    gh 'mfussenegger/nvim-dap',
    gh 'rcarriga/nvim-dap-ui',
    gh 'nvim-neotest/nvim-nio',
    gh 'jay-babu/mason-nvim-dap.nvim',
    gh 'leoluz/nvim-dap-go',
    gh 'mfussenegger/nvim-dap-python',
    gh 'theHamsta/nvim-dap-virtual-text',
  }

  local dap = require 'dap'
  local dapui = require 'dapui'

  -- Makes a best-effort attempt to wire up debug adapters for whatever's
  -- ensure_installed below, using mason-installed binaries.
  require('mason-nvim-dap').setup {
    automatic_installation = true,
    handlers = {},
    ensure_installed = {
      'delve', -- Go
      'codelldb', -- Rust
      'debugpy', -- Python
    },
  }

  ---@diagnostic disable-next-line: missing-fields
  dapui.setup {
    icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
    ---@diagnostic disable-next-line: missing-fields
    controls = {
      icons = {
        pause = '⏸',
        play = '▶',
        step_into = '⏎',
        step_over = '⏭',
        step_out = '⏮',
        step_back = 'b',
        run_last = '▶▶',
        terminate = '⏹',
        disconnect = '⏏',
      },
    },
  }

  -- Inline variable values while stepping through code
  require('nvim-dap-virtual-text').setup {}

  dap.listeners.after.event_initialized['dapui_config'] = dapui.open
  dap.listeners.before.event_terminated['dapui_config'] = dapui.close
  dap.listeners.before.event_exited['dapui_config'] = dapui.close

  require('dap-go').setup {
    delve = {
      -- On Windows delve must be run attached or it crashes.
      detached = vim.fn.has 'win32' == 0,
    },
  }

  -- Point at the debugpy mason installs into its own venv (rather than system python3)
  require('dap-python').setup(vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python3')
end

-- Debugging keymaps. Each one triggers the (one-time) load above before
-- delegating to the real dap/dapui function.
local function dapf(fn_name)
  return function()
    load_dap()
    require('dap')[fn_name]()
  end
end

vim.keymap.set('n', '<leader>dc', dapf 'continue', { desc = '[D]ebug: [C]ontinue/Start' })
vim.keymap.set('n', '<leader>di', dapf 'step_into', { desc = '[D]ebug: Step [I]nto' })
vim.keymap.set('n', '<leader>do', dapf 'step_over', { desc = '[D]ebug: Step [O]ver' })
vim.keymap.set('n', '<leader>dO', dapf 'step_out', { desc = '[D]ebug: Step [O]ut' })
vim.keymap.set('n', '<leader>db', dapf 'toggle_breakpoint', { desc = '[D]ebug: Toggle [B]reakpoint' })
vim.keymap.set('n', '<leader>dB', function()
  load_dap()
  require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
end, { desc = '[D]ebug: Conditional [B]reakpoint' })
vim.keymap.set('n', '<leader>dt', dapf 'terminate', { desc = '[D]ebug: [T]erminate' })
vim.keymap.set('n', '<leader>dl', dapf 'run_last', { desc = '[D]ebug: Run [L]ast' })
vim.keymap.set('n', '<leader>du', function()
  load_dap()
  require('dapui').toggle()
end, { desc = '[D]ebug: Toggle [U]I' })
