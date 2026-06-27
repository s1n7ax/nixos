{
  lib,
  config,
  # pkgs,
  ...
}:
{
  config = lib.mkIf config.features.development.llm.enable {
    # home.packages = with pkgs; [
    # llm-ls
    # ];
  };
}
