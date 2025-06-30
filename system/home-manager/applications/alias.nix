{ ... }:
let
  alias = {
    # kubectl
    k = "kubectl";
    kgg = "kubectl get all";
    kg = "kubectl get";
    kd = "kubectl delete";
    kc = "kubectl create";
    ka = "kubectl apply";

    # docker compose
    dd = "docker compose";
    ddu = "docker compose up -d";
    ddd = "docker compose down";
    ddr = "docker compose restart";
    dde = "docker compose exec";
    ddb = "docker compose build";

    n = "nvim";
    nv = "neovide";
    f = "yazi";
    lg = "lazygit";
    ld = "lazydocker";
    yt = "yt-dlp";
    h = "Hyprland";
    rm = "trash";
    p = "pnpm";
    px = "pnpm dlx";

    # rust alternatives
    cat = "bat";
    ls = "eza -lg";
    l = "eza -lg";
    ll = "eza -lg";
    find = "fd";
    grep = "rg";

    # git
    g = "git";
    gcl = "git clone";
    gf = "git fetch origin";
    ga = "git add";
    gl = "git log --oneline";
    gla = "git log";
    gst = "git status";
    gs = "git switch";
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
        --workspace-folder . \
        --mount 'type=bind,source=/home/s1n7ax/.config/nvim,target=/root/.config/nvim'
    '';

    dcr = ''
      devcontainer up \
        --workspace-folder . \
        --mount 'type=bind,source=/home/s1n7ax/.config/nvim,target=/root/.config/nvim' \
        --remove-existing-container
    '';
    dcn = "devcontainer exec --workspace-folder . nvim";
    dcs = "devcontainer exec --workspace-folder . bash";

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
    nixos = "cd ~/Workspace/nixos && sudo nix flake update && sudo nixos-rebuild switch --upgrade --flake ./#desktop";
    nixos-clean = "sudo nix-collect-garbage  --delete-old";
  };
in
{
  home.shellAliases = alias;
  programs.fish.shellAliases = alias;
}
