{% set hostname =  salt['pillar.get']('openqa:worker:hostname', {}) %}
{% set hostid = hostname | replace('hal9', '') | int %}

video-pkgs:
  pkg.installed:
    - resolve_capabilities: True
    - pkgs:
      - raspberrypi-firmware-extra-pi4
      - v4l-utils
      - socat
      - python3-pyserial

/etc/fstab:
  file.replace:
    - pattern: '/boot/efi'
    - repl: '/boot/vc-manual'

move-boot:
  cmd.run:
    - name: 'umount /boot/efi && mkdir /boot/vc-manual && mount /boot/vc-manual'
    - creates: /boot/vc-manual
    - require:
      - file: /etc/fstab

/boot/vc-manual/config.txt:
  file.replace:
    - pattern: '^#?gpu_mem=.*'
    - repl: gpu_mem=128
    - require:
      - cmd: move-boot

/boot/vc-manual/config.txt-startx:
  file.append:
    - name: /boot/vc-manual/config.txt
    - text: start_x=1
    - require:
      - cmd: move-boot

/boot/vc-manual/extraconfig.txt:
  file.managed:
    - contents: |
        dtoverlay=dwc2,dr_mode=peripheral
        dtoverlay=tc358743
        dtoverlay=disable-bt
        dtoverlay={{ salt['pillar.get']('uart', 'uart5') }}
        kernel=kernel8.img
        initramfs initrd.img followkernel
        cmdline=cmdline-linux.txt
    - mode: '0755'
    - require:
      - cmd: move-boot

/boot/vc-manual/cmdline-linux.txt:
  file.managed:
    - contents: |
        root=/dev/mmcblk0p3 loglevel=3 splash=silent plymouth.enable=0 console=ttyAMA0,115200n8 net.ifnames=0 cma=128M
    - require:
      - cmd: move-boot


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

#TODO:
# - kernel
