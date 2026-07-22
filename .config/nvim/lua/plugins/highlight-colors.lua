local gh = require('config.pack').gh

-- Inline swatches for hex/rgb color values — handy given how much YAML/TOML/
-- config-file editing happens here.
vim.pack.add { gh 'brenoprata10/nvim-highlight-colors' }
require('nvim-highlight-colors').setup {}
