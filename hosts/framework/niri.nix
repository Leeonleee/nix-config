{ ... }:

{
  # Framework-specific outputs and lid handling. Keep shared Niri behavior in
  # modules/home/programs/niri.nix.
  programs.niri.settings = {
    outputs = {
      "eDP-1" = {
        scale = 1.5;

        transform = {
          rotation = 0;
          flipped = false;
        };
      };

      "DP-9" = { };

      "DP-10" = {
        position = {
          x = 0;
          y = 0;
        };
      };

      "DP-11" = { };

      "DP-12" = {
        position = {
          x = 0;
          y = 0;
        };
      };

      "DP-19" = {
        position = {
          x = 0;
          y = 0;
        };
      };
    };

    switch-events = {
      lid-close.action.spawn = [
        "niri"
        "msg"
        "output"
        "eDP-1"
        "off"
      ];

      lid-open.action.spawn = [
        "niri"
        "msg"
        "output"
        "eDP-1"
        "on"
      ];
    };
  };
}
