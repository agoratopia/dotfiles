local gh = require('config.pack').gh

-- Buffer tab bar. Hidden entirely when only one buffer is open.
-- NOTE: takes over normal-mode <S-h>/<S-l> (previously top/bottom-of-screen
-- jumps) for prev/next buffer, matching LazyVim's convention.
vim.pack.add { gh 'akinsho/bufferline.nvim' }
require('bufferline').setup {
  options = {
    always_show_bufferline = false,
    diagnostics = 'nvim_lsp',
    show_buffer_close_icons = false,
    show_close_icon = false,
  },
}

vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<CR>', { desc = 'Prev buffer' })
vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<CR>', { desc = 'Next buffer' })
