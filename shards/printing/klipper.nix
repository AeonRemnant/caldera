{ config, ... }:

let
  cfg = config.caldera.printer;
  # Klipper requires multi-line values to have indented continuation lines.
  # The NixOS INI generator doesn't add this indentation, so we prepend it.
  gcode = cmds: builtins.concatStringsSep "\n  " ([ "" ] ++ cmds);
in
{
  services.klipper = {
    enable = true;

    # Mutable config: Nix generates printer.cfg on first boot only.
    # Runtime changes (PID tuning, Z-offset, bed mesh) persist across reboots.
    mutableConfig = true;
    configDir = cfg.configDir;

    # Full printer config as Nix attrset (Ender 3 V3 SE / Creality 4.2.2 board).
    # Sources cross-referenced:
    #   https://github.com/0xD34D/ender3-v3-se-klipper-config
    #   https://github.com/bootuz-dinamon/ender3-v3-se-full-klipper
    #   https://github.com/VeeM/Ender3_V3_SE_Klipper_Config
    settings = {
      mcu = {
        serial = cfg.serial;
        restart_method = "command";
      };

      printer = {
        kinematics = "cartesian";
        max_velocity = 250;
        max_accel = 2500;
        max_z_velocity = 5;
        max_z_accel = 100;
        square_corner_velocity = "5.0";
      };

      # --- Steppers ---

      stepper_x = {
        step_pin = "PC2";
        dir_pin = "!PB9";
        enable_pin = "!PC3";
        microsteps = 16;
        rotation_distance = 40;
        endstop_pin = "~!PA5";
        position_endstop = -6;
        position_min = -6;
        position_max = 230;
        homing_speed = 80;
      };

      stepper_y = {
        step_pin = "PB8";
        dir_pin = "PB7";
        enable_pin = "!PC3";
        microsteps = 16;
        rotation_distance = 40;
        endstop_pin = "~!PA6";
        position_endstop = -14;
        position_min = -14;
        position_max = 230;
        homing_speed = 80;
      };

      stepper_z = {
        step_pin = "PB6";
        dir_pin = "!PB5";
        enable_pin = "!PC3";
        microsteps = 16;
        rotation_distance = 8;
        endstop_pin = "probe:z_virtual_endstop";
        position_min = -3;
        position_max = 250;
        homing_speed = 4;
        second_homing_speed = 1;
        homing_retract_dist = "2.0";
      };

      # --- Extruder (Sprite-style direct drive) ---

      extruder = {
        max_extrude_only_distance = "100.0";
        max_extrude_only_velocity = "50.0";
        max_extrude_only_accel = 1000;
        pressure_advance = "0.04"; # Calibrate: print PA tuning tower
        step_pin = "PB4";
        dir_pin = "PB3";
        enable_pin = "!PC3";
        microsteps = 16;
        rotation_distance = "7.53";
        nozzle_diameter = "0.400";
        filament_diameter = "1.750";
        heater_pin = "PA1";
        sensor_type = "EPCOS 100K B57560G104F";
        sensor_pin = "PC5";
        control = "pid";
        # Run PID_EXTRUDER macro to re-tune
        pid_kp = "27.142";
        pid_ki = "1.371";
        pid_kd = "134.351";
        min_temp = 0;
        max_temp = 260;
      };

      # --- Heated Bed ---

      heater_bed = {
        heater_pin = "PB2";
        sensor_type = "EPCOS 100K B57560G104F";
        sensor_pin = "PC4";
        control = "pid";
        # Run PID_BED macro to re-tune
        pid_kp = "64.440";
        pid_ki = "0.773";
        pid_kd = "1343.571";
        min_temp = 0;
        max_temp = 100;
      };

      # --- Fans ---

      fan = {
        pin = "PA0";
      };

      # --- BLTouch / CRTouch Probe ---

      bltouch = {
        sensor_pin = "^PC14";
        control_pin = "PC13";
        x_offset = -24;
        y_offset = -13;
        z_offset = "2.0"; # Calibrate: run PROBE_CALIBRATE, then SAVE_CONFIG
        speed = 10;
        samples = 2;
        samples_tolerance_retries = 4;
        pin_move_time = "0.4";
        stow_on_each_sample = "False";
        probe_with_touch_mode = "True";
      };

      safe_z_home = {
        home_xy_position = "134,123";
        speed = 50;
        z_hop = 10;
        z_hop_speed = 10;
      };

      # --- Bed Mesh ---
      # mesh_min/max account for probe offset (-24, -13) from nozzle

      bed_mesh = {
        speed = 120;
        horizontal_move_z = 5;
        mesh_min = "30,15";
        mesh_max = "200,210";
        probe_count = "5,5";
        algorithm = "bicubic";
        adaptive_margin = 5;
      };

      # --- Sensors ---

      "temperature_sensor mcu_temp" = {
        sensor_type = "temperature_mcu";
        min_temp = 0;
        max_temp = 100;
      };

      "temperature_sensor host_temp" = {
        sensor_type = "temperature_host";
        min_temp = 10;
        max_temp = 100;
      };

      "filament_switch_sensor filament_sensor" = {
        pause_on_runout = "True";
        switch_pin = "^!PC15";
        runout_gcode = "FILAMENT_RUNOUT";
      };

      # --- Peripherals ---

      "output_pin beeper" = {
        pin = "PB0";
      };

      # --- Features ---

      virtual_sdcard = {
        path = "${cfg.configDir}/gcodes";
        on_error_gcode = "CANCEL_PRINT";
      };

      exclude_object = { };
      respond = { };
      display_status = { };

      pause_resume = {
        recover_velocity = 25;
      };

      idle_timeout = {
        gcode = gcode [
          "M84"
          "TURN_OFF_HEATERS"
        ];
        timeout = 600;
      };

      # --- Macros: Print lifecycle ---

      # Slicer start gcode: START_PRINT EXTRUDER_TEMP={temperature} BED_TEMP={bed_temperature}
      "gcode_macro START_PRINT" = {
        description = "Start print with heating, mesh, and purge line";
        gcode = gcode [
          "{% set BED_TEMP = params.BED_TEMP|default(60)|float %}"
          "{% set EXTRUDER_TEMP = params.EXTRUDER_TEMP|default(190)|float %}"
          "M140 S{BED_TEMP}"
          "G92 E0"
          "G28"
          "BED_MESH_CALIBRATE"
          "M190 S{BED_TEMP}"
          "M109 S{EXTRUDER_TEMP}"
          "G1 Z2.0 F3000"
          "G1 X0.1 Y20 Z0.3 F5000.0"
          "G1 X0.1 Y200.0 Z0.3 F1500.0 E15"
          "G1 X0.4 Y200.0 Z0.3 F5000.0"
          "G1 X0.4 Y20 Z0.3 F1500.0 E30"
          "G92 E0"
          "G1 Z2.0 F3000"
          "G1 X5 Y20 Z0.3 F5000.0"
        ];
      };

      "gcode_macro PRINT_END" = {
        description = "End print, present part, turn off heaters";
        gcode = gcode [
          "G91"
          "G1 E-2 F2700"
          "G1 E-2 Z0.2 F2400"
          "G1 X5 Y5 F3000"
          "G1 Z50"
          "G90"
          "G1 X0 Y220"
          "M106 S0"
          "M104 S0"
          "M140 S0"
          "M84 X Y E"
        ];
      };

      # --- Macros: Pause/Resume/Cancel (Mainsail UI) ---

      "gcode_macro CANCEL_PRINT" = {
        description = "Cancel the running print";
        rename_existing = "CANCEL_PRINT_BASE";
        gcode = gcode [
          "TURN_OFF_HEATERS"
          "M106 S0"
          "G91"
          "G1 Z5"
          "G90"
          "G1 X5 Y220 F6000"
          "M84"
          "CANCEL_PRINT_BASE"
        ];
      };

      "gcode_macro PAUSE" = {
        description = "Pause the running print";
        rename_existing = "PAUSE_BASE";
        gcode = gcode [
          "{% set z = params.Z|default(10)|float %}"
          "{% set e = params.E|default(1.7)|float %}"
          "SAVE_GCODE_STATE NAME=PAUSE_state"
          "PAUSE_BASE"
          "G91"
          "G1 E-{e} F2100"
          "G1 Z{z}"
          "G90"
          "G1 X5 Y220 F6000"
        ];
      };

      "gcode_macro RESUME" = {
        description = "Resume the paused print";
        rename_existing = "RESUME_BASE";
        gcode = gcode [
          "{% set e = params.E|default(1.7)|float %}"
          "G91"
          "G1 E{e} F2100"
          "G90"
          "RESTORE_GCODE_STATE NAME=PAUSE_state MOVE=1"
          "RESUME_BASE"
        ];
      };

      # --- Macros: Filament ---

      "gcode_macro FILAMENT_RUNOUT" = {
        description = "Handle filament runout";
        gcode = gcode [
          "M118 Filament runout detected"
          "PAUSE"
        ];
      };

      "gcode_macro FILAMENT_LOAD" = {
        description = "Load filament";
        gcode = gcode [
          "{% set load = params.L|default(100)|float * 0.5 %}"
          "{% set temp = params.T|default(210)|float %}"
          "SAVE_GCODE_STATE NAME=FILAMENT_LOAD_STATE"
          "LOW_TEMP_CHECK T={temp}"
          "M118 Loading filament"
          "M83"
          "G1 E{load} F1500"
          "G4 P1000"
          "G1 E{load} F200"
          "RESTORE_GCODE_STATE NAME=FILAMENT_LOAD_STATE"
        ];
      };

      "gcode_macro FILAMENT_UNLOAD" = {
        description = "Unload filament";
        gcode = gcode [
          "{% set unload = params.U|default(100)|float %}"
          "{% set temp = params.T|default(200)|float %}"
          "SAVE_GCODE_STATE NAME=FILAMENT_UNLOAD_STATE"
          "LOW_TEMP_CHECK T={temp}"
          "M118 Unloading filament"
          "M83"
          "G1 E2 F200"
          "G1 E-10 F200"
          "G1 E-{unload} F1500"
          "RESTORE_GCODE_STATE NAME=FILAMENT_UNLOAD_STATE"
        ];
      };

      "gcode_macro LOW_TEMP_CHECK" = {
        description = "Ensure extruder is hot enough, heat if not";
        gcode = gcode [
          "{% set temp = params.T|default(200)|float %}"
          "{% if printer.extruder.target > temp %}"
          "  {% set temp = printer.extruder.target %}"
          "{% endif %}"
          "{% if printer.extruder.temperature < temp %}"
          "  M118 Heating to {temp}"
          "  SET_HEATER_TEMPERATURE HEATER=extruder TARGET={temp}"
          "  TEMPERATURE_WAIT SENSOR=extruder MINIMUM={temp}"
          "{% endif %}"
        ];
      };

      # --- Macros: Calibration helpers ---

      "gcode_macro PID_EXTRUDER" = {
        description = "PID tune extruder at 210C";
        gcode = gcode [
          "PID_CALIBRATE HEATER=extruder TARGET=210"
          "SAVE_CONFIG"
        ];
      };

      "gcode_macro PID_BED" = {
        description = "PID tune bed at 60C";
        gcode = gcode [
          "PID_CALIBRATE HEATER=heater_bed TARGET=60"
          "SAVE_CONFIG"
        ];
      };

      "gcode_macro PROBE_CALIBRATE_START" = {
        description = "Start probe Z offset calibration";
        gcode = gcode [
          "G28"
          "PROBE_CALIBRATE"
        ];
      };
    };
  };

  # Klipper needs dialout for serial port access
  users.users.klipper = {
    isSystemUser = true;
    group = "klipper";
    extraGroups = [ "dialout" ];
  };
  users.groups.klipper = { };

  # Ensure gcode upload directory exists and moonraker can find it.
  # Moonraker uploads to <its data dir>/gcodes but klipper reads from configDir/gcodes.
  systemd.tmpfiles.rules = [
    "d ${cfg.configDir} 0755 klipper klipper -"
    "d ${cfg.configDir}/gcodes 0775 klipper klipper -"
    "L+ /var/lib/moonraker/gcodes - - - - ${cfg.configDir}/gcodes"
  ];
}
