{ inputs, pkgsUnstable, ... }:
{
  programs.herdr = {
    enable = true;
    package = pkgsUnstable.herdr;

    settings = {
      theme = {
        name = "catppuccin";
        auto_switch = true;
        dark_name = "catppuccin";
        light_name = "catppuccin-latte";
      };
      terminal = {

      };
      update = {

      };
      keys = {
        prefix = "ctrl+s";

        # Prefix-mode actions
        help = "prefix+?";
        settings = "prefix+s";
        detach = "prefix+q";
        reload_config = "prefix+shift+r";
        open_notification_target = "prefix+o";
        workspace_picker = "prefix+w";
        goto = "prefix+g";
        new_workspace = "prefix+shift+n";
        new_worktree = "prefix+shift+g";

        rename_workspace = "prefix+shift+w";
        close_workspace = "prefix+shift+d";
        remote_image_paste = "ctrl+v";
        new_tab = "prefix+c";
        rename_tab = "prefix+shift+t";
        previous_tab = "prefix+p";
        next_tab = "prefix+n";
        switch_tab = "prefix+1..9";
        switch_workspace = "";
        close_tab = "prefix+shift+x";
        rename_pane = "prefix+shift+p";
        edit_scrollback = "prefix+e";
        focus_pane_left = "prefix+h";
        focus_pane_down = "prefix+j";
        focus_pane_up = "prefix+k";
        focus_pane_right = "prefix+l";
        cycle_pane_next = "prefix+tab";
        cycle_pane_previous = "prefix+shift+tab";
        split_vertical = "prefix+v";
        split_horizontal = "prefix+minus";
        close_pane = "prefix+x";
        zoom = "prefix+z";
        resize_mode = "prefix+r";
        toggle_sidebar = "prefix+b";

        navigate_workspace_up = "up";
        navigate_workspace_down = "down";
        navigate_pane_left = "h";
        navigate_pane_down = "j";
        navigate_pane_up = "k";
        navigate_pane_right = "l";
      };
      ui = {
        
        sidebar_width = 26;

        sidebar_min_width = 18;

        sidebar_max_width = 36;

        sidebar_collapsed_mode = "compact";

        mobile_width_threshold = 64;

        mouse_capture = true;

        copy_on_select = true;

        agent_panel_sort = "spaces";

        toast = {
          delivery = "system";
          delay_seconds = 1;

          clipboard = {
            enabled = true;
            position = "bottom-center";
          };
        };
      };
      
      session = {
        resume_agents_on_restore = true;
      };
      experimental = {
        pane_history = false;
      };
    };
  };

  # xdg.configFile."herdr/config.toml".source = ./config.toml;
}
