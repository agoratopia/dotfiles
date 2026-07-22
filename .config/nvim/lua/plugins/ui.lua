local gh = require('config.pack').gh

-- Automatically detect and set indentation
vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
require('guess-indent').setup {}

-- Git related signs in the gutter, plus utilities for managing changes
vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
require('gitsigns').setup {
  signs = {
    add = { text = '+' }, ---@diagnostic disable-line: missing-fields
    change = { text = '~' }, ---@diagnostic disable-line: missing-fields
    delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
    topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
    changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
  },
  on_attach = function(bufnr)
    local gitsigns = require 'gitsigns'

    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    -- Navigation
    map('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal { ']c', bang = true }
      else
        gitsigns.nav_hunk 'next'
      end
    end, { desc = 'Jump to next git [c]hange' })

    map('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal { '[c', bang = true }
      else
        gitsigns.nav_hunk 'prev'
      end
    end, { desc = 'Jump to previous git [c]hange' })

    -- Actions
    map('v', '<leader>hs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [s]tage hunk' })
    map('v', '<leader>hr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [r]eset hunk' })
    map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
    map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
    map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
    map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
    map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
    map('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'git preview hunk [i]nline' })
    map('n', '<leader>hb', function() gitsigns.blame_line { full = true } end, { desc = 'git [b]lame line' })
    map('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index' })
    map('n', '<leader>hD', function() gitsigns.diffthis '@' end, { desc = 'git [D]iff against last commit' })
    map('n', '<leader>hQ', function() gitsigns.setqflist 'all' end, { desc = 'git hunk [Q]uickfix list (all files in repo)' })
    map('n', '<leader>hq', gitsigns.setqflist, { desc = 'git hunk [q]uickfix list (all changes in this file)' })

    -- Toggles
    map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
    map('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = '[T]oggle git intra-line [w]ord diff' })

    -- Text object
    map({ 'o', 'x' }, 'ih', gitsigns.select_hunk)
  end,
}

-- Shows pending keybinds
vim.pack.add { gh 'folke/which-key.nvim' }
require('which-key').setup {
  delay = 0,
  icons = { mappings = vim.g.have_nerd_font },
  spec = {
    { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
    { '<leader>t', group = '[T]oggle / [T]est' },
    { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    { '<leader>g', group = '[G]it' },
    { '<leader>d', group = '[D]ebug' },
    { '<leader>x', group = 'Trouble' },
    { 'gr', group = 'LSP Actions', mode = { 'n' } },
  },
}

-- Highlight todo, notes, etc in comments
vim.pack.add { gh 'folke/todo-comments.nvim' }
require('todo-comments').setup { signs = false }

-- [[ mini.nvim ]]
--  A collection of various small independent plugins/modules
vim.pack.add { gh 'nvim-mini/mini.nvim' }

-- Nerd Font is available, so load the icons module for pretty icons in various plugins.
require('mini.icons').setup()
-- Used for backwards compatibility with plugins that require `nvim-web-devicons` (e.g. telescope.nvim)
MiniIcons.mock_nvim_web_devicons()

-- Better Around/Inside textobjects
--  - va)  - [V]isually select [A]round [)]paren
--  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
--  - ci'  - [C]hange [I]nside [']quote
require('mini.ai').setup {
  mappings = {
    around_next = 'aa',
    inside_next = 'ii',
  },
  n_lines = 500,
}

-- Add/delete/replace surroundings (brackets, quotes, etc.)
--  - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
--  - sd'   - [S]urround [D]elete [']quotes
--  - sr)'  - [S]urround [R]eplace [)] [']
require('mini.surround').setup()

-- Simple and easy statusline
local statusline = require 'mini.statusline'
statusline.setup { use_icons = vim.g.have_nerd_font }
---@diagnostic disable-next-line: duplicate-set-field
statusline.section_location = function() return '%2l:%-2v' end

-- Auto-close brackets/quotes
require('mini.pairs').setup()

-- Scope-aware indent guide (highlights the current indent block)
require('mini.indentscope').setup {
  -- No animation, to stay snappy
  draw = { delay = 0, animation = require('mini.indentscope').gen_animation.none() },
}
vim.api.nvim_create_autocmd('FileType', {
  desc = 'Disable indent scope guide in non-code buffers',
  pattern = { 'help', 'dashboard', 'lazy', 'mason', 'oil', 'checkhealth' },
  callback = function() vim.b.miniindentscope_disable = true end,
})

-- Nicer, non-blocking notification popups (replaces plain vim.notify)
require('mini.notify').setup()
vim.notify = require('mini.notify').make_notify()

-- Auto save/restore a per-directory session (only when nvim is opened with
-- no file arguments, e.g. `cd myproject && nvim`, and nothing else is
-- already open). The resulting local Session.vim is kept out of git via
-- the global gitignore.
--
-- NOTE: built-in autoread/autowrite are intentionally off — autoread's
-- VimEnter hook didn't fire reliably, and autowrite only re-saves a
-- session that was already read/written this run (so a brand-new
-- directory never gets bootstrapped). Both are replicated manually below.
require('mini.sessions').setup {
  autoread = false,
  autowrite = false,
}

local function nothing_shown_yet()
  if vim.fn.argc() > 0 then return false end
  if #vim.api.nvim_list_bufs() > 1 then return false end
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= '' then return false end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
  return #lines <= 1 and (lines[1] or '') == ''
end

-- Never drop a Session.vim directly in $HOME itself — that's not a project,
-- and this is exactly the kind of home-directory clutter to avoid.
local function in_a_project_dir() return vim.fn.getcwd() ~= vim.fn.expand '~' end

vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'Restore a local session, if one exists and nothing else is already shown',
  once = true,
  nested = true,
  callback = function()
    local sessions = require('mini.sessions').detected
    if sessions['Session.vim'] and in_a_project_dir() and nothing_shown_yet() then
      pcall(require('mini.sessions').read, 'Session.vim')
    end
  end,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'Always write a local session on quit, if nvim was opened without file args',
  callback = function()
    if vim.fn.argc() == 0 and in_a_project_dir() then pcall(require('mini.sessions').write, 'Session.vim', { force = true }) end
  end,
})

-- Splash screen when opening nvim with no file args. Registered after the
-- session-restore autocmd above so a restored session (which populates real
-- buffers/windows) correctly wins — mini.starter re-checks "is anything
-- already shown" itself at VimEnter time and no-ops if so.
local starter = require 'mini.starter'
local starter_items = {
  { name = 'Find file', action = 'Telescope find_files', section = '' },
  { name = 'Recent files', action = 'Telescope oldfiles', section = '' },
  { name = 'Live grep', action = 'Telescope live_grep', section = '' },
  { name = 'New file', action = 'enew', section = '' },
  { name = 'Quit', action = 'qa', section = '' },
}
if require('mini.sessions').detected['Session.vim'] then
  table.insert(starter_items, 4, {
    name = 'Restore session',
    action = "lua require('mini.sessions').read('Session.vim')",
    section = '',
  })
end
starter.setup {
  evaluate_single = true,
  items = starter_items,
  header = '',
  footer = '',
  content_hooks = {
    starter.gen_hook.adding_bullet(),
    starter.gen_hook.aligning('center', 'center'),
  },
}
