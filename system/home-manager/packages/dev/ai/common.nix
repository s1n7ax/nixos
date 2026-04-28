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

  skills = {
    task = ./skills/task.md;
    pull-request = ./skills/pull-request.md;
    errors = ./skills/errors.md;
    logging = ./skills/logging.md;
    single-line-code-comments = ./skills/single-line-code-comments.md;
    override-hm-module = ./skills/override-hm-module.md;
    todo-comments = ./skills/todo-comments.md;
    git-commits = ./skills/git-commits.md;
    home-manager-options = ./skills/home-manager-options.md;
    nvim-headless-test = ./skills/nvim-headless-test.md;
  };
}
