
rpi-pkgs:
  pkg.installed:
    - pkgs:
      - raspberrypi-firmware-extra-pi4

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

/etc/systemd/system/drop-caches.service:
  file.managed:
  - contents: |
      [Service]
      ExecStart=/bin/sh -c 'echo 3 > /proc/sys/vm/drop_caches'
      Type=oneshot

/etc/systemd/system/drop-caches.timer:
  file.managed:
  - contents: |
      [Timer]
      OnCalendar=daily

      [Install]
      WantedBy=timers.target

drop-caches.timer:
  service.running:
  - enable: True

#TODO:
# - kernel
