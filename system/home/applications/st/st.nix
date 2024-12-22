{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (st.overrideAttrs (oldAttrs: rec {
      # ligatures dependency
      buildInputs = oldAttrs.buildInputs ++ [ harfbuzz ];

      patches = [
        # ligatures patch
        (fetchpatch {
          url = "https://st.suckless.org/patches/ligatures/0.9.2/st-ligatures-20240427-0.9.2.diff";
          hash = "sha256-kFmGCrsqiphY1uiRCX/Gz4yOdlLxIIHBlsM1pvW5TTA=";
        })
      ];
      # version controlled config file
      configFile = writeText "config.def.h" (builtins.readFile ./config.h);
      postPatch = oldAttrs.postPatch + ''cp ${configFile} config.def.h'';
    }))
  ];

}
