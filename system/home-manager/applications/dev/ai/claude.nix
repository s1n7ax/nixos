{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}:
let
  headroom = config.features.development.ai.headroom;
  skills = import ./skills;

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

    # Custom skills, version-controlled here so they're the same on every
    # machine instead of hand-edited under ~/.claude/skills.
    home.file = lib.listToAttrs (
      map (name: {
        name = ".claude/skills/${name}";
        value.source = ./skills/${name};
      }) skills.names
    );
  };
}
