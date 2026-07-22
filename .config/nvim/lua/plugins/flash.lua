local gh = require('config.pack').gh

-- Jump anywhere on screen: `s` + 2 characters. Also works across windows/splits.
-- NOTE: this takes over the normal-mode `s` (substitute char) and `S` (substitute
-- line) commands — use `cl`/`cc` for those instead, per flash.nvim's own convention.
vim.pack.add { gh 'folke/flash.nvim' }
require('flash').setup {}

vim.keymap.set({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash' })
vim.keymap.set({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, { desc = 'Flash Treesitter' })
vim.keymap.set('o', 'r', function() require('flash').remote() end, { desc = 'Remote Flash' })
vim.keymap.set({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, { desc = 'Treesitter Search' })
vim.keymap.set('c', '<C-s>', function() require('flash').toggle() end, { desc = 'Toggle Flash Search' })
