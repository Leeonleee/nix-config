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

    # No lid switch-events: Niri already turns eDP-1 off on lid close when an
    # external monitor is connected. Forcing `niri msg output eDP-1 off` also
    # removed the output while suspended alone, destroying the lock surface so
    # Niri showed its red locked fallback on lid open until the lock screen
    # was recreated.
  };
}
