{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (st.overrideAttrs (oldAttrs: rec {
      # ligatures dependency
      buildInputs = oldAttrs.buildInputs ++ [ harfbuzz ];

      patches = [
        # ligatures patch
        (fetchpatch {
          url = "https://st.suckless.org/patches/scrollback/st-scrollback-ringbuffer-0.9.2.diff";
          hash = "sha256-/AoHajojVUAAqF4iKbN1lGM6h9PhZxCbMfAS2PRvbDE=";
        })
        (fetchpatch {
          url = "https://st.suckless.org/patches/ligatures/0.9.2/st-ligatures-scrollback-ringbuffer-20240427-0.9.2.diff";
          hash = "sha256-E25LQ27JsKFm8yRRIpGVABJCzRnCpYo0bUdmfwo1DfU=";
        })
      ];
      # version controlled config file
      configFile = writeText "config.def.h" (builtins.readFile ./config.h);
      postPatch = oldAttrs.postPatch + ''cp ${configFile} config.def.h'';
    }))
  ];

}
