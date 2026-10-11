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

  # Claude Code ships these as built-in skills; the copies in this tree were
  # ported from its binary for the other agents. Mounting them into
  # ~/.claude/skills would shadow the richer bundled versions (effort memory,
  # --fix status tracking, structured reporting), so Claude Code is excluded
  # for these names.
  claudeBuiltins = [
    "code-review"
    "simplify"
  ];

  mountSkills =
    prefix: names:
    lib.listToAttrs (
      map (name: {
        name = "${prefix}/${name}";
        value.source = ./. + "/${name}";
      }) names
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
      { home.file = mountSkills ".agents/skills" skillNames; }
      (lib.mkIf ai.claude.enable {
        home.file = mountSkills ".claude/skills" (lib.subtractLists claudeBuiltins skillNames);
      })
    ]
  );
}
