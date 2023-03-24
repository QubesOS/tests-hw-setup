# setup specific to PiKVM v3 HAT

libgpiod-utils:
  pkg.installed: []

/etc/systemd/system/usb-breaker.service:
  file.managed:
    - contents: |
        [Unit]
        Description=USB Breaker enable
        [Service]
        Type=simple
        ExecStart=/usr/bin/gpioset --mode=signal 0 5=1
        ExecStopPost=/usr/bin/gpioset 0 5=0
        [Install]
        WantedBy=multi-user.target

usb-breaker.service:
  service.running:
    - enable: True


/boot/vc-manual/config.txt-pikvm:
  file.append:
    - name: /boot/vc-manual/config.txt
    - text: |
        # Clock
        dtoverlay=i2c-rtc,pcf8563
