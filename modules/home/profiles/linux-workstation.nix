{ inputs, pkgs, ... }:

{
  # Linux workstation applications, imported only by graphical Linux hosts.
  imports = [
    ../programs/taildrop.nix
    ../programs/voxtype.nix
    ../programs/vicinae.nix
    ../programs/web-apps.nix
    ../programs/windows-vm.nix
  ];

  services.trayscale.enable = true;

  # Windows VM display scale in percent; null follows the focused monitor.
  programs.windows-vm.scale = 175;

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
