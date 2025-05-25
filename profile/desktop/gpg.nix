{ ... }:
{
  programs.gnupg.agent.settings = {
    # expires after 15 min
    default-cache-ttl = 900000;
  };
}
