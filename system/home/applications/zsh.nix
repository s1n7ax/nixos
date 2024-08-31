{ ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    oh-my-zsh.enable = true;
    sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1"; # no cursor fix for wayland
      EDITOR = "nvim";
      TERM = "alacritty";
    };
    localVariables = {
      PATH = "/home/s1n7ax/.cargo/bin:$PATH";
    };

    syntaxHighlighting.enable = true;
    initExtra = ''
      # this disables the <c-s> terminal freeze
      stty -ixon

      bindkey "^n" vi-backward-word
      bindkey "^e" vi-forward-word
      bindkey "^w" vi-backward-kill-word
      bindkey "^a" beginning-of-line
      bindkey "^o" end-of-line
      bindkey "^l" clear-screen
    '';
    shellAliases = {
      n = "nvim";
      nv = "neovide";
      f = "vifm";
      lg = "lazygit";
      ld = "lazydocker";
      yt = "yt-dlp";
      h = "Hyprland";
      rm = "trash";
      npm = "pnpm";

      # rust alternatives
      cat = "bat";
      ls = "eza -lg";
      l = "eza -lg";
      ll = "eza -lg";
      find = "fd";
      grep = "rg";

      # git
      g = "git";
      ga = "git add";
      gl = "git log --oneline";
      gla = "git log";
      gst = "git status";
      gp = "git pull";
      gP = "git push";
      gc = "git commit -m";
      gch = "git checkout";
      gb = "git branch";
      gd = "git diff";

      # devcontainer
      dc = "devcontainer --workspace-folder .";
      dcu = ''
        devcontainer up \
          --workspace-folder .
          --mount 'type=bind,source=/home/s1n7ax/.config/nvim,target=/root/.config/nvim' \
      '';

      dcr = ''
        devcontainer up \
          --workspace-folder . \
          --mount 'type=bind,source=/home/s1n7ax/.config/nvim,target=/root/.config/nvim' \
          --remove-existing-container
      '';
      dcn = "devcontainer exec --workspace-folder . nvim";
      dcs = "devcontainer exec --workspace-folder . bash";

      # docker compose
      dd = "docker compose";
      ddu = "docker compose up";
      ddd = "docker compose down";

      # edit
      nh = "run-command-at 'nvim' ~/.config/home-manager; ";
      nn = "run-command-at 'nvim' ~/.config/nvim;";
      no = "run-command-at 'nvim' ~/Notes;";
      np = "run-command-at 'nvim' $(project-menu)";

      # lazygit
      lh = "run-command-at 'lazygit' ~/.config/home-manager";
      ln = "run-command-at 'lazygit' ~/.config/nvim";
      la = "run-command-at 'lazygit' ~/.config/astronvim";
      lo = "run-command-at 'lazygit' ~/Notes";
      lp = "run-command-at 'lazygit' (project-menu)";

      # locations
      cd = "z";
      cdw = "cd ~/Workspace";
      cdn = "cd /etc/nixos";

      # home manager
      hm = "cd ~/Workspace/home-manager && nix flake update && home-manager --impure switch --refresh --flake ./#desktop";

      # nixos
      nixos = "cd ~/Workspace/nixos && git diff --quiet && git diff --cached --quiet && sudo nix flake update && sudo nixos-rebuild switch --upgrade --flake ./#desktop";

      nixos-clean = "nix-collect-garbage  --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
    };
  };
}
