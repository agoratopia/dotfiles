local gh = require('config.pack').gh

-- Edit the filesystem like a normal buffer instead of a persistent sidebar tree.
-- `-` opens the parent directory, mirroring vim-vinegar's convention.
vim.pack.add { gh 'stevearc/oil.nvim' }
require('oil').setup {}

vim.keymap.set('n', '-', '<cmd>Oil<CR>', { desc = 'Open parent directory' })
