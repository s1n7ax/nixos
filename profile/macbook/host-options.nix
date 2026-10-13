{
  # macOS host feature set. Mirrors the Linux dev-vm toolchain, minus everything
  # that needs a Linux kernel or a Wayland session. The common/*.nix option files
  # are deliberately not imported: they target Linux profiles and enable xdg,
  # utilities and the secrets module, none of which apply here.
  settings.font.size = 26;

  features = {
    desktop.aerospace.enable = true;

    terminal.kitty.enable = true;

    shell = {
      fish.enable = true;
    };

    editor.neovim.enable = true;

    development = {
      llm.enable = true;
      ai = {
        enable = true;
        cursor.enable = true;
        opencode.enable = false;
        claude.enable = false;
        # pi's Cursor provider reuses the Cursor login already on this machine.
        pi = {
          enable = true;
          cursor.enable = true;
          cursor.package = "npm:@rahularya01/pi-cursor@1.4.39";
        };
        headroom.enable = false;
        mcp = {
          nixos.enable = true;
          playwright.enable = true;
          context7.enable = true;
          svelte.enable = true;
          nextjs.enable = true;
          tailwindcss.enable = true;
          chakra-ui.enable = true;
          jira.enable = true;
          home-assistant.enable = false;
        };
      };
      git.enable = true;
      github.enable = true;
      c.enable = true;
      java.enable = true;
      javascript.enable = true;
      jsonnet.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      python.enable = true;
      rust.enable = true;
      sh.enable = true;
      toml.enable = true;
      yaml.enable = true;
      database.enable = true;
      web.enable = true;
      # ide.enable pulls in vscode, which has no aarch64-darwin build here.
      ide.enable = false;
      virtualization.enable = true;
    };

    virtualization = {
      docker.enable = true;
    };

    cli = {
      eza.enable = true;
      lazygit.enable = true;
      scripts.enable = true;
      starship.enable = true;
      zoxide.enable = true;
      direnv.enable = true;
      fzf.enable = true;
      yazi.enable = true;
      vifm.enable = true;
      htop.enable = true;
      alias.enable = true;
      pet.enable = true;
      rustAlternatives.enable = true;
    };

    fonts.enable = true;
  };
}
