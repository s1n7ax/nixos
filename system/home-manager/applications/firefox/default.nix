{
  config,
  ...
}:
{
  imports = [
    ./profiles/s1n7ax
    ./profiles/s1n7ax/bookmarks/cool-websites.nix
    ./profiles/s1n7ax/bookmarks/docker.nix
    ./profiles/s1n7ax/bookmarks/github.nix
    ./profiles/s1n7ax/bookmarks/important-articals.nix
    ./profiles/s1n7ax/bookmarks/learning.nix
    ./profiles/s1n7ax/bookmarks/my-repos.nix
    ./profiles/s1n7ax/bookmarks/neovim.nix
    ./profiles/s1n7ax/bookmarks/nixos.nix
    ./profiles/s1n7ax/bookmarks/other.nix
    ./profiles/s1n7ax/bookmarks/quick-access.nix
    ./profiles/s1n7ax/bookmarks/self-hosted.nix
    ./profiles/s1n7ax/bookmarks/to-read.nix
    ./profiles/s1n7ax/bookmarks/toolbar.nix

    ./profiles/work
    ./profiles/work/bookmarks/toolbar.nix

    ./extensions.nix
    # about:config changes
    ./librewolf/config.nix
  ];

  programs.firefox = {
    enable = config.features.web.enable;

    # ---- POLICIES ----
    # Check about:policies#documentation for options.
    policies = {
      AutofillCreditCardEnabled = false;
      BackgroundAppUpdate = false;
      AppAutoUpdate = false;
      DisableAppUpdate = false;
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;
      OfferToSaveLoginsDefault = false;
      SearchSuggestEnabled = false;
      DisableMasterPasswordCreation = false;
      DisablePasswordReveal = true;
      DisableTelemetry = true;
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://mozilla.cloudflare-dns.com";
      };
      DisableFirefoxStudies = true;
      DisableSecurityBypass = {
        InvalidCertificate = true;
        SafeBrowsing = true;
      };
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
      };
      FirefoxHome = {
        Search = false;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
        Locked = true;
      };
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        ImproveSuggest = false;
        Locked = false;
      };
      Homepage = {
        Locked = true;
        StartPage = "previous-session";
      };
      HttpAllowlist = [ "192.168.1.111" ];
      HttpsOnlyMode = "force_enabled";
      HardwareAcceleration = true;
      DisablePocket = true;
      DisableFirefoxAccounts = true;
      DisableAccounts = true;
      DisableFirefoxScreenshots = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DontCheckDefaultBrowser = true;
      DisplayBookmarksToolbar = "always"; # alternatives: "always" or "newtab"
      DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
      SearchBar = "unified"; # alternative: "separate"
      # NOTE: cannot make NoDefaultBookmarks true due to following issue
      # https://github.com/nix-community/home-manager/issues/5821
      NoDefaultBookmarks = false;
    };
  };
}
