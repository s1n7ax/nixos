{
  features = {
    network = {
      ssh = {
        enable = true;
        agent.enable = true;
      };
    };

    tools = {
      downloading.enable = true;
    };

    virtualization = {
      docker.enable = true;
    };

    development = {
      llm.enable = true;
      ai = {
        enable = true;
        opencode.enable = true;
        claude.enable = true;
        headroom.enable = true;
      };
      git.enable = true;
      github.enable = true;
      c.enable = true;
      java.enable = true;
      javascript.enable = true;
      lua.enable = true;
      markdown.enable = true;
      nix.enable = true;
      python.enable = true;
      rust.enable = true;
      sh.enable = true;
      toml.enable = true;
      yaml.enable = true;
      database.enable = true;
      web.enable = true;
      ide.enable = true;
      virtualization.enable = true;
    };
  };
}
