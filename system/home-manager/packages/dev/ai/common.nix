{ ... }:
{
  mcpServers = {
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

  rules = ''
    # AGENTS.md

    ## MCP

    - Use Context7 MCP when we don't have a dedicated MCP but I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

    # Working relationship

    - No sycophancy.
    - Be direct, matter-of-fact, and concise.
    - Be critical; challenge my reasoning.
    - Don't include timeline estimates in plans.
    - Minimal explanations. Senior engineer context assumed.
  '';

}
