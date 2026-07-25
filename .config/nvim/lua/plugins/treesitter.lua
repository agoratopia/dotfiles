local gh = require('config.pack').gh

-- Used to highlight, edit, and navigate code. See `:help nvim-treesitter-intro`
vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

-- Ensure parsers for the languages/formats used regularly are installed.
-- Anything else gets auto-installed on demand below (best-effort — arbitrary
-- config formats like network switch configs may not have a parser at all).
-- The list itself lives in config/parsers.lua, shared with build-portable.sh.
local parsers = require 'config.parsers'
-- The portable bundle builds these parsers ahead of time and ships them, so
-- there is nothing to install at startup. Calling install() there would try to
-- fetch and compile on a box that may have neither network nor a C compiler.
local server_profile = require('config.profile').server
if not server_profile then require('nvim-treesitter').install(parsers) end

---@param buf integer
---@param language string
local function treesitter_try_attach(buf, language)
  if not vim.treesitter.language.add(language) then return end
  vim.treesitter.start(buf, language)

  -- Treesitter-based folds. Buffers open fully unfolded (see foldlevel* in
  -- config/options.lua) rather than collapsed by default.
  vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  vim.wo.foldmethod = 'expr'

  local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
  if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
end

local available_parsers = require('nvim-treesitter').get_available()
vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local buf, filetype = args.buf, args.match

    local language = vim.treesitter.language.get_lang(filetype)
    if not language then return end

    local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

    if vim.tbl_contains(installed_parsers, language) then
      treesitter_try_attach(buf, language)
    elseif not server_profile and vim.tbl_contains(available_parsers, language) then
      -- Compile-on-demand needs a C toolchain, which the server profile can't
      -- assume. There, an unbundled filetype just falls through to whatever
      -- Neovim's own syntax files provide.
      require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
    else
      treesitter_try_attach(buf, language)
    end
  end,
})
