{ config, pkgs, ... }:
{
  programs.obs-studio = {
    enable = config.package.screen-capture.enable;
    plugins = [ pkgs.obs-studio-plugins.obs-source-record ];
  };

  home.file = {
    ".config/obs-studio/basic/profiles/s1n7ax_gen".source = ./profiles/s1n7ax_gen;
    ".config/obs-studio/basic/scenes/s1n7ax_scene_gen.json".source = ./scenes/s1n7ax_scene.json;
  };
}
