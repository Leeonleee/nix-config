{ inputs, pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  imports = [
    ../programs/taildrop.nix
    ../programs/voxtype.nix
    ../programs/vicinae.nix
    ../programs/web-apps.nix
  ];

  services.trayscale.enable = true;

  # Use `tailscale status` to find names; nicknamed devices appear first.
  services.dolphin-taildrop.nicknames = {
    # "phone-magicdns-name" = "My phone";
    # "ipad-magicdns-name" = "My iPad";
  };

  home.packages = with pkgs; [
    kdePackages.kate
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
  ];
}
