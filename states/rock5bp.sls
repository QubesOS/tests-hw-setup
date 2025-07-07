/etc/kvmd/override.d/kvmd-override-opi5p.yaml:
  file.managed:
  - source: salt://files/kvmd-override-opi5p.yaml
  - makedirs: True


# TODO: build it and install
/root/rk3588-pwm.dts:
  file.managed:
  - contents: |
      /dts-v1/;
      /plugin/;

      &pwm12 {
          status = "okay";
      };
