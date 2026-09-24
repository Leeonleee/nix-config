{ config, lib, ... }:

let
  targets = config.desktop.noctalia.sessionTargets;
in
{
  options.desktop.noctalia.sessionTargets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    internal = true;
    description = ''
      Session units of the compositors that selected Noctalia. The service
      starts only with these sessions.
    '';
  };

  config = lib.mkIf (targets != [ ]) {
    programs.noctalia.systemd.enable = true;

    # The upstream unit follows graphical-session.target, which every
    # compositor reaches. Bind it to the selecting sessions only.
    systemd.user.services.noctalia = {
      Unit = {
        PartOf = lib.mkForce targets;
        After = lib.mkForce targets;
        # Requisite needs every listed unit active, so it can only guard
        # against starting outside a session when one compositor selects
        # Noctalia.
        Requisite = lib.mkIf (lib.length targets == 1) targets;
      };
      Service.Slice = "session.slice";
      Install.WantedBy = lib.mkForce targets;
    };
  };
}
