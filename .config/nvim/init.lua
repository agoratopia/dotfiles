require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.pack'

local profile = require 'config.profile'

require 'plugins.colorscheme'
require 'plugins.ui'
require 'plugins.oil'
require 'plugins.telescope'
require 'plugins.lsp'
require 'plugins.format'
require 'plugins.completion'
require 'plugins.treesitter'
require 'plugins.markdown'
require 'plugins.diffview'
require 'plugins.flash'
require 'plugins.trouble'
require 'plugins.bufferline'
require 'plugins.highlight-colors'

-- Language toolchains that only make sense where the project itself is built.
-- dap and neotest are already deferred until first use, so this isn't about
-- startup cost — it's that their keymaps would otherwise exist on a remote box
-- and try to pull down plugins that aren't in the bundle.
if not profile.server then
  require 'plugins.rustaceanvim'
  require 'plugins.dap'
  require 'plugins.neotest'
end

-- vim: ts=2 sts=2 sw=2 et
