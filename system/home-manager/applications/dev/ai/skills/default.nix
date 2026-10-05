{
  config,
  lib,
  ...
}:
let
  ai = config.features.development.ai;

  # Every subdirectory here with a SKILL.md is a skill. No separate names list.
  skillNames = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (./. + "/${name}/SKILL.md")
    ) (builtins.readDir ./.)
  );

  mountSkills =
    prefix:
    lib.listToAttrs (
      map (name: {
        name = "${prefix}/${name}";
        value.source = ./. + "/${name}";
      }) skillNames
    );
in
{
  # Shared Agent Skills tree. Gated on ai.enable so any agent (or just the AI
  # feature set) gets the same skills under ~/.agents/skills, replacing any
  # hand-installed third-party copies. Claude Code also gets copies under
  # ~/.claude/skills when that agent is enabled.
  config = lib.mkIf ai.enable (
    lib.mkMerge [
      { home.file = mountSkills ".agents/skills"; }
      (lib.mkIf ai.claude.enable { home.file = mountSkills ".claude/skills"; })
    ]
  );
}
