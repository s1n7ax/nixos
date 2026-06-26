{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  headroom = config.features.development.ai.headroom;

  claudeCode =
    if headroom.enable then
      pkgs.symlinkJoin {
        name = "claude-code-headroom";
        paths = [ pkgs-unstable.claude-code ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/claude \
            --set ANTHROPIC_BASE_URL "http://127.0.0.1:${toString headroom.port}"
        '';
      }
    else
      pkgs-unstable.claude-code;
in
{
  config = lib.mkIf config.features.development.ai.claude.enable {
    home.packages = [ claudeCode ];
  };
}
