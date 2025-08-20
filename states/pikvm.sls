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
{%- if 'Raspberry Pi Compute Module 4' in salt['grains.get']('productname') %}
        ExecStart=/usr/bin/gpioset GPIO22=1
        ExecStopPost=/usr/bin/gpioset --toggle=0 GPIO22=0
{%- else %}
        ExecStart=/usr/bin/gpioset GPIO5=1
        ExecStopPost=/usr/bin/gpioset --toggle=0 GPIO5=0
{%- endif %}
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
