{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.features.development.ai.enable {
    programs.mcp = {
      enable = true;
      servers = {
        svelte = {
          command = "npx";
          args = [
            "-y"
            "@sveltejs/mcp"
          ];
        };
        nextjs = {
          command = "npx";
          args = [
            "-y"
            "next-devtools-mcp@latest"
          ];
        };
        tailwindcss = {
          command = "npx";
          args = [
            "-y"
            "tailwindcss-mcp-server"
          ];
        };
        chakra-ui = {
          command = "npx";
          args = [
            "-y"
            "@chakra-ui/react-mcp"
          ];
        };
        context7 = {
          command = "npx";
          args = [
            "-y"
            "@upstash/context7-mcp"
          ];
        };
      };
    };
  };
}
