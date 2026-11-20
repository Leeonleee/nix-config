{ inputs, ... }:

let
  # The backend rejects requests whose Host header differs from its bind
  # address, so clients must use this exact MagicDNS name.
  tailnetName = "dev-nix.tailf299a9.ts.net";
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
  ];

  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    enable = true;
    gateway.enable = true;

    # Remote Hermes Desktop clients add this as a Remote gateway at
    # http://${tailnetName}:9119 and sign in with username/password.
    backend = {
      mode = "serve";
      host = tailnetName;
      waitFor = "hostname";
      port = 9119;
    };
  };

  # Holds HERMES_DASHBOARD_BASIC_AUTH_{USERNAME,PASSWORD,SECRET} with mode 0600,
  # outside Git and the Nix store. It is not in services.hermes-agent.environmentFiles
  # because those rewrite ~/.hermes/.env on every switch, dropping keys added at runtime.
  systemd.user.services.hermes-backend.Service.EnvironmentFile = "%h/.config/hermes/dashboard-auth.env";
}
