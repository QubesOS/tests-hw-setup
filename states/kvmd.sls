/usr/lib/sysusers.d/kvmd.conf:
  file.managed:
    - contents: |
        g kvmd - -
        g kvmd-vnc - -

        u kvmd - "PiKVM - The main daemon" -
        u kvmd-vnc - "PiKVM - VNC to KVMD/Streamer proxy" -

        m kvmd video

        m kvmd-vnc kvmd

systemd-sysusers /usr/lib/sysusers.d/kvmd.conf:
  cmd.run:
    - onchanges:
      - file: /usr/lib/sysusers.d/kvmd.conf

kvmd-deps:
  pkg.installed:
    - resolve_capabilities: True
    - pkgs:
      - libjpeg8-devel
      - libevent-devel
      - libbsd-devel
      - make
      - patch
      - gcc
      - python3-pygments
      - python3-setuptools
      - python3-aiofiles
      - python3-PyYAML
      - python3-aiohttp
      - python3-devel
      - python3-xlib
      - python3-passlib
      - python3-Pillow
      - python3-setproctitle
      - python3-gpiod
      - python3-pyotp
      - python3-dbus_next
      - python3-systemd
      - python3-zstandard
      - python3-psutil
      - python3-pipx

/var/lib/pikvm-sources:
  file.directory:
    - user: kvmd
    - group: kvmd
    - require:
      - cmd: systemd-sysusers /usr/lib/sysusers.d/kvmd.conf

#############
### ustreamer
#############

https://github.com/pikvm/ustreamer:
  git.latest:
    - target: /var/lib/pikvm-sources/ustreamer
    - branch: master
    - rev: f8ed7d7b3bf12d81b73d9c934e8b3d6b66cea24f
    - user: kvmd
    - require:
      - file: /var/lib/pikvm-sources

ustreamer-make:
  cmd.run:
    - name: make
    - cwd: /var/lib/pikvm-sources/ustreamer
    - runas: kvmd
    - require:
      - git: "https://github.com/pikvm/ustreamer"
      - pkg: kvmd-deps

ustreamer-make-install:
  cmd.run:
    - name: make install WITH_PYTHON=1
    - cwd: /var/lib/pikvm-sources/ustreamer
    - runas: root
    - require:
      - cmd: ustreamer-make

# simplify kvmd config, to not require repeating cmdline
/usr/bin/ustreamer:
  file.symlink:
    - target: ../local/bin/ustreamer
    - require:
      - cmd: ustreamer-make-install

########
### kvmd
########

https://github.com/pikvm/kvmd:
  git.latest:
    - target: /var/lib/pikvm-sources/kvmd
    - branch: master
    - rev: f34685d91fc5638668d269808382e9bed2ac97e9
    - user: kvmd
    - require:
      - file: /var/lib/pikvm-sources

/var/lib/pikvm-sources/kvmd:
  file.patch:
    - source: salt://files/kvmd-workarounds.patch
    - strip: 1

kvmd-install:
  cmd.run:
    - name: pipx install --system-site-packages -f .
    - cwd: /var/lib/pikvm-sources/kvmd
    - env:
      - PIPX_HOME: /opt/pipx
      - PIPX_BIN_DIR: /usr/bin
    - runas: root
    - require:
      - git: "https://github.com/pikvm/kvmd"
      - pkg: kvmd-deps

/etc/kvmd:
  file.directory:
    - mode: 755

/var/lib/kvmd/msd:
  file.directory:
    - makedirs: True
    - mode: 755

# there must be _some_ MSD configured in fstab for kvmd-otg to work with MSD
# enabled
/etc/fstab-kvmd:
  file.append:
  - name: /etc/fstab
  - text: |
      /var/lib/kvmd/msd /var/lib/kvmd/msd  ext4  bind,noauto,nodev,nosuid,noexec,ro,errors=remount-ro,data=journal,X-kvmd.otgmsd-user=kvmd  0 0

{% macro copy_kvmd_file(src, dst) -%}
{{dst}}:
  file.copy:
    - source: /var/lib/pikvm-sources/kvmd/{{src}}
    - makedirs: True
    - dir_mode: 755
{% endmacro -%}

{{ copy_kvmd_file("configs/kvmd/main/v2-hdmi-rpi4.yaml", "/etc/kvmd/main.yaml") }}
{{ copy_kvmd_file("configs/kvmd/logging.yaml", "/etc/kvmd/logging.yaml") }}
{{ copy_kvmd_file("configs/kvmd/auth.yaml", "/etc/kvmd/auth.yaml") }}
{{ copy_kvmd_file("configs/kvmd/meta.yaml", "/etc/kvmd/meta.yaml") }}
{{ copy_kvmd_file("configs/kvmd/ipmipasswd", "/etc/kvmd/ipmipasswd") }}
{{ copy_kvmd_file("configs/kvmd/vncpasswd", "/etc/kvmd/vncpasswd") }}
{{ copy_kvmd_file("configs/kvmd/htpasswd", "/etc/kvmd/htpasswd") }}
{{ copy_kvmd_file("configs/os/udev/v2-hdmi-rpi4.rules", "/etc/udev/rules.d/98-kvmd.rules") }}
{{ copy_kvmd_file("configs/os/services/kvmd.service", "/etc/systemd/system/kvmd.service") }}
{{ copy_kvmd_file("configs/os/services/kvmd-vnc.service", "/etc/systemd/system/kvmd-vnc.service") }}
{{ copy_kvmd_file("configs/os/services/kvmd-otg.service", "/etc/systemd/system/kvmd-otg.service") }}

# restore "video" group to allow openqa access, kvmd is a member of the group anyway
/etc/udev/rules.d/99-kvmd-fixup.rules:
  file.managed:
    - contents: |
        KERNEL=="video[0-9]*", KERNELS=="fe801000.csi|fe801000.csi1", GROUP="video"
        KERNEL=="ttyACM[0-9]*", ENV{ID_VENDOR_ID}=="1209", ENV{ID_MODEL_ID}=="eda3", GROUP="kvmd", SYMLINK+="kvmd-hid-bridge"

# handle rename
/etc/udev/rules.d/99-kvmd.rules:
  file.absent: []

/etc/kvmd/override.yaml:
  file.managed:
    - source: salt://files/kvmd-override.yaml

/etc/kvmd/override.d:
  file.directory: []

{% if salt['pillar.get']('gadget:hid', "usb") == "ps2" %}
/etc/kvmd/override.d/hid-ps2.yaml:
  file.managed:
  - require:
    - file: /etc/kvmd/override.d
  - contents: |
      kvmd:
        hid:
          type: serial
          device: /dev/kvmd-hid-bridge
          reset_pin: -1
      otg:
        devices:
          hid:
            keyboard:
              start: false
            mouse:
              start: false
{% else %}
/etc/kvmd/override.d/hid-ps2.yaml:
  file.absent: []
{% endif %}

/usr/share/kvmd/extras:
  file.directory:
   - makedirs: True

cp -r /var/lib/pikvm-sources/kvmd/contrib/keymaps /usr/share/kvmd/:
  cmd.run:
    - creates: /usr/share/kvmd/keymaps
    - require:
      - file: /usr/share/kvmd/extras

/etc/tmpfiles.d/kvmd.conf:
  file.managed:
    - contents: |
        D       /run/kvmd   0775    kvmd   kvmd    -
        D       /tmp/kvmd   0775    kvmd   kvmd    -

/usr/local/bin/vcgencmd:
  file.copy:
    - source: /var/lib/pikvm-sources/kvmd/testenv/fakes/vcgencmd
    - mode: 0755

/etc/sudoers.d/kvmd:
  file.managed:
    - contents: |
        service-control ALL=(root) NOPASSWD: /bin/systemctl start kvmd-otg.service kvmd.service kvmd-vnc.service
        service-control ALL=(root) NOPASSWD: /bin/systemctl stop kvmd-otg.service kvmd.service kvmd-vnc.service
        kvmd ALL=(root) NOPASSWD: /usr/bin/kvmd-helper-otgmsd-remount

