{ inputs, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  home.file.".config/luacheck/.luacheckrc".text = ''
    stds.nvim = {
      read_globals = { 'jit' },
    }

    std = 'lua51+nvim'

    read_globals = {
      'vim',
    }

    globals = {
      'vim.g',
      'vim.b',
      'vim.w',
      'vim.o',
      'vim.bo',
      'vim.wo',
      'vim.go',
      'vim.env',
      'vim.opt',
    }
  '';
}
