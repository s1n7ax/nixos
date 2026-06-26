{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  ...
}:
let
  f = config.features;
in
{
  # Single source of truth for every plain `home.packages` list. Each group is
  # gated by the same `features.*.enable` flag its module used, so profiles still
  # only pull the packages their enabled features ask for. Packages that are
  # locally-built derivations (claude-code wrapper, hyprland voice-indicator,
  # patched st, shell scripts) stay in their own modules.
  home.packages =
    # cli
    lib.optionals f.cli.utilities.enable (
      with pkgs;
      [
        pass

        # file managers
        thunar
        tumbler
        vifm

        # audio controls
        #pavucontrol
        wiremix
        easyeffects

        # downloaders
        axel
        yt-dlp

        # compress de-compress
        p7zip
        unzip

        # sync
        rclone
        sshfs

        # image
        ffmpeg_6-full
        nsxiv
        kdePackages.gwenview

        # other
        wl-clipboard
        trash-cli
        appimage-run
        xdg-utils
        tldr

        # networking
        dig
        traceroute
      ]
    )
    ++ lib.optionals f.cli.rustAlternatives.enable (
      with pkgs;
      [
        bat
        difftastic
        ripgrep
        fd
        sd
        ripgrep
        starship
        xh
        dua
      ]
    )

    # fonts
    ++ lib.optionals f.fonts.enable (
      with pkgs;
      [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
        # use nerd.fonts.<font_name> where font_name is any one of the fonts name from
        # https://www.nerdfonts.com/font-downloads
        nerd-fonts.fira-code
        nerd-fonts.monaspace
        nerd-fonts.iosevka
        maple-mono.NF
      ]
    )

    # browsers
    ++ lib.optionals f.web.enable (with pkgs; [ chromium ])

    # terminal
    ++ lib.optionals f.terminal.alacritty.enable (with pkgs; [ alacritty-theme ])

    # multimedia
    ++ lib.optionals f.multimedia.enable (
      with pkgs;
      [
        digikam
        gimp
        handbrake
        # kdePackages.kdenlive
      ]
    )
    ++ lib.optionals f.multimedia.video.enable (with pkgs; [ vlc ])
    ++ lib.optionals f.multimedia.mobile.enable (with pkgs; [ waydroid ])
    ++ lib.optionals f.multimedia.gaming.enable (with pkgs; [ steam ])

    # presentation
    ++ lib.optionals f.presentation.enable (
      with pkgs;
      [
        marp-cli
        presenterm
      ]
    )

    # productivity / video production
    ++ lib.optionals f.productivity.video-production.camera.enable (
      with pkgs;
      [
        gphoto2
        darktable
      ]
    )
    ++ lib.optionals f.productivity.video-production.screen-capture.enable (
      with pkgs;
      [
        grim
        slurp
      ]
    )

    # hardware
    ++ lib.optionals f.hardware.bluetooth.enable (with pkgs; [ bluetui ])

    # network
    ++ lib.optionals f.network.monitoring.enable (
      with pkgs;
      [
        vnstat
        speedtest-cli
      ]
    )

    # development
    ++ lib.optionals f.development.c.enable (
      with pkgs;
      [
        gcc
        gnumake
      ]
    )
    ++ lib.optionals f.development.github.enable (with pkgs; [ gh ])
    ++ lib.optionals f.development.virtualization.enable (
      with pkgs;
      [
        devcontainer
        lazydocker
        dockerfile-language-server
        docker-compose-language-service
        hadolint
      ]
    )
    ++ lib.optionals f.development.java.enable (
      with pkgs;
      [
        jdk21
        gradle
      ]
    )
    ++ lib.optionals f.development.javascript.enable (
      with pkgs;
      [
        deno
        nodejs_22
        pnpm
        yarn
        emmet-language-server
        vscode-langservers-extracted
        tailwindcss-language-server
        prettierd
        prettier
        biome
        typescript
        eslint_d
        typescript-language-server
        supabase-cli
        pkgs-unstable.typescript-go
        pkgs-unstable.svelte-language-server
        vtsls
      ]
    )
    ++ lib.optionals f.development.lua.enable (
      with pkgs;
      [
        stylua
        lua-language-server
        luajitPackages.luacheck
      ]
    )
    ++ lib.optionals f.development.markdown.enable (
      with pkgs;
      [
        cbfmt
        marksman
        markdownlint-cli
        markdownlint-cli2
        python312Packages.mdformat
      ]
    )
    ++ lib.optionals f.development.nix.enable (
      with pkgs;
      [
        nixpkgs-fmt
        nil
        nixfmt
      ]
    )
    ++ lib.optionals f.development.python.enable (
      with pkgs;
      [
        (python3.withPackages (py-packages: with py-packages; [ pip ]))
        isort
        ruff
        black
        virtualenv
        python313Packages.python-lsp-server
      ]
    )
    ++ lib.optionals f.development.rust.enable (
      with pkgs;
      [
        cargo
        cargo-leptos
        cargo-generate
        rust-analyzer
        stylance-cli
      ]
    )
    ++ lib.optionals f.development.sh.enable (
      with pkgs;
      [
        bash-language-server
        shellcheck
        shfmt
        fish-lsp
      ]
    )
    ++ lib.optionals f.development.toml.enable (with pkgs; [ taplo ])
    ++ lib.optionals f.development.yaml.enable (with pkgs; [ yaml-language-server ])
    ++ lib.optionals f.development.database.enable (
      with pkgs;
      [
        pgformatter
        postgresql
        sqlite
        sqlfluff
      ]
    )
    ++ lib.optionals f.development.web.enable (
      with pkgs;
      [
        jq
        httpie
        bruno
        dart-sass
      ]
    )
    ++ lib.optionals f.development.ide.enable (with pkgs; [ vscode ])
    ++ lib.optionals f.development.ci.enable (with pkgs; [ act ])
    ++ lib.optionals f.development.ai.enable (with pkgs; [ mcp-nixos ]);
}
