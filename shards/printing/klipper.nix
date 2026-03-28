{ config, ... }:

let
  cfg = config.caldera.printer;
in
{
  services.klipper = {
    enable = true;

    # Mutable config: Nix generates printer.cfg on first boot only.
    # Runtime changes (PID tuning, Z-offset, bed mesh) persist across reboots.
    mutableConfig = true;
    configDir = cfg.configDir;

    # Full printer config as Nix attrset (Ender 3 V3 SE).
    # After first boot, edit /var/lib/klipper/printer.cfg directly or via Mainsail.
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
      };

      stepper_x = {
        step_pin = "PC2";
        dir_pin = "!PB9";
        enable_pin = "!PC3";
        microsteps = 16;
        rotation_distance = 40;
        endstop_pin = "!PA5";
        position_endstop = -6;
        position_min = -6;
        position_max = 230;
        homing_speed = 50;
      };

      stepper_y = {
        step_pin = "PB8";
        dir_pin = "PB7";
        enable_pin = "!PC3";
        microsteps = 16;
        rotation_distance = 40;
        endstop_pin = "!PA6";
        position_endstop = -14;
        position_min = -14;
        position_max = 230;
        homing_speed = 50;
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

      extruder = {
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
        min_temp = 0;
        max_temp = 260;
        # Run PID_CALIBRATE HEATER=extruder TARGET=200 to tune
        control = "pid";
        pid_kp = "27.142";
        pid_ki = "1.371";
        pid_kd = "134.351";
      };

      heater_bed = {
        heater_pin = "PB2";
        sensor_type = "EPCOS 100K B57560G104F";
        sensor_pin = "PC4";
        min_temp = 0;
        max_temp = 100;
        # Run PID_CALIBRATE HEATER=heater_bed TARGET=60 to tune
        control = "pid";
        pid_kp = "64.440";
        pid_ki = "0.773";
        pid_kd = "1343.571";
      };

      fan = {
        pin = "PA0";
      };

      bltouch = {
        sensor_pin = "^PC14";
        control_pin = "PC13";
        x_offset = -24;
        y_offset = -13;
        speed = 5;
        lift_speed = 20;
        samples = 2;
        sample_retract_dist = 3;
        samples_tolerance_retry = 3;
      };

      safe_z_home = {
        home_xy_position = "134,123";
        speed = 50;
        z_hop = 10;
        z_hop_speed = 5;
      };

      bed_mesh = {
        speed = 150;
        horizontal_move_z = 5;
        mesh_min = "10,10";
        mesh_max = "200,210";
        probe_count = "5,5";
        algorithm = "bicubic";
        fade_start = 1;
        fade_end = 10;
        fade_target = 0;
      };

      virtual_sdcard = {
        path = "${cfg.configDir}/gcodes";
      };

      pause_resume = { };
    };
  };

  # Ensure gcode upload directory exists
  systemd.tmpfiles.rules = [
    "d ${cfg.configDir}/gcodes 0755 klipper klipper -"
  ];
}
