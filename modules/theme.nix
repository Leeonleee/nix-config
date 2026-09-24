{ pkgs, ... }:

{
  stylix = {
    enable = true;
    # catppuccin-frappe
    # gruvbox-dark-medium.yaml
    # black-metal-venom
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-soft.yaml";
    # base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-frappe.yaml";

    polarity = "dark";

    fonts.monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };

    opacity.terminal = 0.9;
  };
}
