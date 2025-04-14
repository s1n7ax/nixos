{ ... }:
let
  alias = {
    # kubectl
    k = "kubectl";
    kgg = "kubectl get all";
    kg = "kubectl get";
    kd = "kubectl delete";
    kc = "kubectl create";
    ka = "kubectl apply";

    # docker compose
    dd = "docker compose";
    ddu = "docker compose up -d";
    ddd = "docker compose down";
    ddr = "docker compose restart";
    dde = "docker compose exec";
    ddb = "docker compose build";
  };
in
{
  home.shellAliases = alias;
  programs.fish.shellAliases = alias;
}
