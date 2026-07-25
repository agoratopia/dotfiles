-- Which environment this Neovim is running in.
--
-- The default (`NVIM_PROFILE` unset) is the full workstation config — every
-- machine that checks this repo out normally, including the Mac.
--
-- `NVIM_PROFILE=server` is the trimmed profile used by the portable bundle
-- (see ~/.config/dotfiles/build-portable.sh), meant for a Linux box reached
-- over SSH. It differs in four ways, each fixing something that actively
-- misbehaves there rather than just saving space:
--
--   * No Mason/treesitter installs at runtime. The bundle ships its own
--     binaries and parsers pre-built; a client's server may have no egress and
--     almost certainly has no C compiler.
--   * No debugger, test-runner or Rust tooling. Those need the project's
--     toolchain resolved locally, which a remote box doesn't have.
--   * No format-on-save. Silently reformatting someone else's config file is a
--     good way to turn a one-line fix into an unreviewable diff.
--   * No session files. Sessions get written into the working directory, and
--     leaving a Session.vim behind in /etc/nginx is not acceptable on a machine
--     that isn't yours.

return {
  server = vim.env.NVIM_PROFILE == 'server',
}
