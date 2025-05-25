{ ... }:
{
  programs.ssh = {
    knownHosts = {
      "github.com ssh-rsa" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
      };
      "github.com ssh-ed25519" = {
        hostNames = [ "github.com" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };

      "github.com ecdsa-sha2-nistp256" = {
        hostNames = [ "github.com" ];
        publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
      };

      "192.168.1.110 ssh-rsa" = {
        hostNames = [ "192.168.1.110 " ];
        publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCP9Rp3fYT4inka6kUkaF3QZhvdKsuT92k8w/5VFZPMf/y5iYisLTtCRjGLrS6DueA/bfzHj9TvLR5+maC8X6km//j1niI/20FCqZ8MtBV1pt/ys6TQDXlLNRgSPg50COBOTqiUeT0R0S/Ip6U1uB66H0C4B+lZ4hAc4PUlgZPbxkbqHgQ7pjugeM3c6HWRyZKg4WaTxZcuPc9jZRT+O87AGg+g9Qs/twMiehUgmRXJB0z1y02zTB5zWT2ZcYkq4svTfC4vjKs1PKKsHszeR9G1xqHRPQ96hGGY+7gJNh8GIQ40DJMUzlJsQKtepYAZD8Y8O05hgWNZ/gGKe7cIl0P+pcEQsWhNd3CTwDqMeqCHbZEf67kLPSxY4gtUPIw9A9XSp6YMGhvczcCfNRZ1c20XUNRjxetdOLJuIbBaRrj5dqdyCksqshv136kQiBp4QiutIXi3JOiFuE8nrYH3HLMNfAa3MG44U2vujOUpeOpuCQ0XSxD9G1JLTN0xtKLihN2jDPL8oRJ+7+d1/LlGOW2CeDZAgZlvexAyO8jTP7W/Dtfj6XmtofWB/pvF1ERm3PCINYHg42I461rZXKz7shq1twDZFYOrLVFTny808YVs5pwcAcLgw4c+X2OBbSqPZEBvnytPSfL+SshiWjuDPbV3p4lNzDseHPLo0f32WmxmFQ==";
      };
      "192.168.1.110 ssh-ed25519" = {
        hostNames = [ "192.168.1.110 " ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHAsksMYthB3wMx9p1PQU/WNtVdfVt3dNXIE/CXUKB45";
      };
    };
  };
}
