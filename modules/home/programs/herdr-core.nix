{ inputs, lib, pkgs, ... }:

let
  herdr-core = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-core;
  # hc spawns the core under its own transient unit/agent; this only kicks it
  # off at startup. `restart` starts a stopped core and hands a running one
  # over to a new build after an update, keeping its terminals alive.
  startCore = [
    "${herdr-core}/bin/hc"
    "server"
    "restart"
  ];
in
{
  home.packages = [ herdr-core ];

  systemd.user.services.herdr-core = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Start the herdr-core terminal runtime";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.escapeShellArgs startCore;
    };
    Install.WantedBy = [ "default.target" ];
  };

  launchd.agents.herdr-core = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = startCore;
      RunAtLoad = true;
    };
  };
}
