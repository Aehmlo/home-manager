{
  config,
  lib,
  pkgs,
  ...
}:
let

  cfg = config.services.flameshot;

  iniFormat = pkgs.formats.ini { };

  iniFile = iniFormat.generate "flameshot.ini" cfg.settings;

in
{
  meta.maintainers = [ lib.maintainers.hamhut1066 ];

  options.services.flameshot = {
    enable = lib.mkEnableOption "Flameshot";

    package = lib.mkPackageOption pkgs "flameshot" { };

    settings = lib.mkOption {
      inherit (iniFormat) type;
      default = { };
      example = {
        General = {
          disabledTrayIcon = true;
          showStartupLaunchMessage = false;
        };
      };
      description = ''
        Configuration to use for Flameshot. See
        <https://github.com/flameshot-org/flameshot/blob/master/flameshot.example.ini>
        for available options.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "services.flameshot" pkgs lib.platforms.linux)
    ];

    home.packages = [ cfg.package ];

    xdg.configFile = lib.mkIf (cfg.settings != { }) {
      "flameshot/flameshot.ini".source = iniFile;
    };

    systemd.user.services.flameshot = {
      Unit = {
        Description = "Flameshot screenshot tool";
        Requires = [ "tray.target" ];
        After = [
          "graphical-session.target"
          "tray.target"
        ];
        PartOf = [ "graphical-session.target" ];
        X-Restart-Triggers = lib.mkIf (cfg.settings != { }) [ "${iniFile}" ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Service = {
        Environment = [ "PATH=${config.home.profileDirectory}/bin" ];
        ExecStart = "${cfg.package}/bin/flameshot";
        Restart = "on-abort";

        # Sandboxing.
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateUsers = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
      };
    };
  };
}
