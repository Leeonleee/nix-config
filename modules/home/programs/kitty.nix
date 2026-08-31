{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };

    settings = {
      # Catppuccin Frappé
      foreground = "#c6d0f5";
      background = "#303446";

      selection_foreground = "#303446";
      selection_background = "#f2d5cf";

      cursor = "#f2d5cf";
      cursor_text_color = "#303446";

      url_color = "#f2d5cf";

      active_border_color = "#babbf1";
      inactive_border_color = "#737994";
      bell_border_color = "#e5c890";

      wayland_titlebar_color = "system";
      macos_titlebar_color = "system";

      active_tab_foreground = "#232634";
      active_tab_background = "#ca9ee6";
      inactive_tab_foreground = "#c6d0f5";
      inactive_tab_background = "#292c3c";
      tab_bar_background = "#232634";

      mark1_foreground = "#303446";
      mark1_background = "#babbf1";
      mark2_foreground = "#303446";
      mark2_background = "#ca9ee6";
      mark3_foreground = "#303446";
      mark3_background = "#85c1dc";

      color0 = "#51576d";
      color8 = "#626880";

      color1 = "#e78284";
      color9 = "#e78284";

      color2 = "#a6d189";
      color10 = "#a6d189";

      color3 = "#e5c890";
      color11 = "#e5c890";

      color4 = "#8caaee";
      color12 = "#8caaee";

      color5 = "#f4b8e4";
      color13 = "#f4b8e4";

      color6 = "#81c8be";
      color14 = "#81c8be";

      color7 = "#b5bfe2";
      color15 = "#a5adce";


      update_check_interval = 0;
    };

    keybindings = {
      "alt+1" = "goto_tab 1";
      "alt+2" = "goto_tab 2";
      "alt+3" = "goto_tab 3";
      "alt+4" = "goto_tab 4";
      "alt+5" = "goto_tab 5";
      "alt+6" = "goto_tab 6";
      "alt+7" = "goto_tab 7";
      "alt+8" = "goto_tab 8";
      "alt+9" = "goto_tab 9";
      "alt+0" = "goto_tab 10";
    };
  };
}
