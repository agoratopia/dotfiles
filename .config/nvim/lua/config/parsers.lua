-- Treesitter parsers to keep installed.
--
-- A plain data module because two things need this list: plugins/treesitter.lua
-- installs it at startup on a workstation, and build-portable.sh compiles it
-- ahead of time for the server bundle (where there is no C toolchain to build
-- parsers on demand). Keeping one copy means the bundle can't drift from the
-- config it was built from.

return {
  'bash',
  'c',
  'diff',
  'dockerfile',
  'gitcommit',
  'gitignore',
  'go',
  'gomod',
  'gosum',
  'gowork',
  'html',
  'json', -- also covers jsonc: vim.treesitter.language.get_lang('jsonc') resolves to 'json'
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'python',
  'query',
  'rust',
  'toml',
  'vim',
  'vimdoc',
  'yaml',
}
