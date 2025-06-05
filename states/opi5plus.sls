# Device-specific quirks for OrangePi 5+

# Workaround for USB 3.0 ports; it's fixed in 6.15-rc7 already, but not on 6.12
/etc/systemd/system/usb3-workaround.service:
  file.managed:
  - contents: |
      [Service]
      Type=oneshot
      ExecStart=/bin/sh -c 'echo fc400000.usb > /sys/bus/platform/drivers/dwc3/unbind'
      ExecStart=/bin/sh -c 'echo fc400000.usb > /sys/bus/platform/drivers/dwc3/bind'
      [Install]
      WantedBy=multi-user.target

usb3-workaround.service:
  service.enabled: []

/etc/kvmd/override.d/kvmd-override-opi5p.yaml:
  file.managed:
  - source: salt://files/kvmd-override-opi5p.yaml
  - makedirs: True
