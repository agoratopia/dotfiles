local gh = require('config.pack').gh

-- Renders headers/code-blocks/tables/checkboxes inline while editing markdown.
-- Deferred until the first markdown buffer opens so it costs nothing otherwise.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  once = true,
  callback = function()
    vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' }
    require('render-markdown').setup {}
  end,
})
