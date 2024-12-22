{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (st.overrideAttrs (oldAttrs: rec {
      # ligatures dependency
      buildInputs = oldAttrs.buildInputs ++ [ harfbuzz ];
      patches = [
        # ligatures patch
        (fetchpatch {
          url = "https://st.suckless.org/patches/ligatures/0.8.3/st-ligatures-20200430-0.8.3.diff";
          sha256 = "67b668c77677bfcaff42031e2656ce9cf173275e1dfd6f72587e8e8726298f09";
        })
      ];
      # version controlled config file
      configFile = writeText "config.def.h" (builtins.readFile ./config.h);
      postPatch = oldAttrs.postPatch ++ ''cp ${configFile} config.def.h'';
    }))
  ];

}
