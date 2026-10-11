{
  config,
  lib,
  ...
}:
let
  ai = config.features.development.ai;

  # Every subdirectory (or symlink to one) here with a SKILL.md is a skill,
  # following the Agent Skills spec. No separate names list.
  skillNames = builtins.attrNames (
    lib.filterAttrs (name: type: type != "regular" && builtins.pathExists (./. + "/${name}/SKILL.md")) (
      builtins.readDir ./.
    )
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
  # Shared Agent Skills tree. Gated on ai.enable so any agent that reads
  # ~/.agents/skills (Pi, Cursor CLI, OpenCode) gets the same skills. Claude
  # Code only reads ~/.claude/skills, so it gets links there too when that
  # agent is enabled. On activation, home-manager moves a hand-installed skill
  # of the same name aside to <name>.hm-backup (backupFileExtension) in the
  # same directory, where agents still load it; delete it once reviewed.
  config = lib.mkIf ai.enable (
    lib.mkMerge [
      { home.file = mountSkills ".agents/skills"; }
      (lib.mkIf ai.claude.enable { home.file = mountSkills ".claude/skills"; })
    ]
  );
}
