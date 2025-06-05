{% set hostname =  salt['pillar.get']('openqa:worker:hostname', {}) %}
{% set hostid = hostname | replace('hal9', '') | int %}
{% set hdmi4k = salt['pillar.get']('openqa:worker:hdmi4k', False) %}

video-pkgs:
  pkg.installed:
    - resolve_capabilities: True
    - pkgs:
      - v4l-utils
      - socat
      - python3-pyserial

/etc/modules-load.d/gadget.conf:
  file.managed:
    - contents: libcomposite

/usr/local/bin/gadget-control:
  file.managed:
    - mode: 0755
    - source: salt://openqa-cmds/gadget-control

/etc/systemd/system/gadget-control.service:
  file.managed:
    - mode: 0644
    - source: salt://openqa-cmds/gadget-control.service
    - template: jinja
    - context:
        hostid: {{hostid}}
        ps2: {{salt['pillar.get']('gadget:hid', 'usb') == 'ps2'}}
        hdmi4k: {{hdmi4k}}


### "custom" boot mode via emulated USB stick

customboot:
  user.present:
  - usergroup: True
  - password: "*"

/usr/local/bin/customboot-build:
  file.managed:
    - mode: 0755
    - source: salt://files/customboot-build

/home/customboot/grubx64.efi:
  file.managed:
    - source: salt://files/grubx64.efi

/home/customboot/.ssh/authorized_keys:
  file.managed:
    - makedirs: True
    - owner: customboot
    - dir_mode: 0755
    - mode: 0644
    - contents: |
        restrict,command="/usr/local/bin/customboot-build" {{salt['pillar.get']('gadget:thor_pubkey', "")}}

/etc/sudoers.d/customboot:
  file.managed:
    - mode: 0400
    - contents: |
        customboot ALL=(root) NOPASSWD: /usr/bin/systemctl restart gadget-control-custom.service
        customboot ALL=(root) NOPASSWD: /usr/bin/systemctl stop gadget-control-custom.service

/etc/systemd/system/gadget-control-custom.service:
  file.managed:
    - mode: 0644
    - source: salt://openqa-cmds/gadget-control-custom.service
    - template: jinja
    - context:
        hostid: {{hostid}}
        ps2: {{salt['pillar.get']('gadget:hid', 'usb') == 'ps2'}}
