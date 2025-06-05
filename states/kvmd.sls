/usr/lib/sysusers.d/kvmd.conf:
  file.managed:
    - contents: |
        g kvmd - -
        g kvmd-vnc - -

        u kvmd - "PiKVM - The main daemon" -
        u kvmd-vnc - "PiKVM - VNC to KVMD/Streamer proxy" -
        u kvmd-janus - "PiKVM - Janus WebRTC Gateywa" -

        m kvmd video

        m kvmd-vnc kvmd

        m kvmd-janus kvmd
        m kvmd-janus audio

        m nginx kvmd
        m nginx kvmd-janus

systemd-sysusers /usr/lib/sysusers.d/kvmd.conf:
  cmd.run:
    - onchanges:
      - file: /usr/lib/sysusers.d/kvmd.conf

# packages not needing resolve_capabilities=True install separately to speed things up
kvmd-static-deps:
  pkg.installed:
    - pkgs:
      - libjpeg8-devel
      - libevent-devel
      - libbsd-devel
      - make
      - patch
      - gcc
      - automake
      - autoconf
      - libtool
      - libnice-devel
      - libconfig-devel
      - libsrtp-devel
      - libwebsockets-devel
      - gengetopt
      - alsa-devel
      - glib2-devel
      - speex-devel
      - libopus-devel
      - libjansson-devel

kvmd-deps:
  pkg.installed:
    - resolve_capabilities: True
    - require:
      - pkg: kvmd-static-deps
    - pkgs:
      - openssl-devel
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
      - python3-pip
      - python3-netifaces
      - python3-async-lru
      - python3-build


/var/lib/pikvm-sources:
  file.directory:
    - user: kvmd
    - group: kvmd
    - require:
      - cmd: systemd-sysusers /usr/lib/sysusers.d/kvmd.conf

######################
### janus-gateway 0.14
######################

https://github.com/meetecho/janus-gateway:
  git.latest:
  - target: /var/lib/pikvm-sources/janus-gateway
  - branch: 0.14
  - rev: 99e133bc00cb910186a34b4e2083821cb6c111fc
  - user: kvmd
  - require:
    - file: /var/lib/pikvm-sources

/var/lib/pikvm-sources/janus-gateway:
  file.patch:
    - source: salt://files/janus-gateway-0001-unmute-hack.patch
    - strip: 1

janus-make:
  cmd.run:
    - name: >
        ./autogen.sh &&
        ./configure \
            --sysconfdir=/etc \
            --disable-docs \
            --disable-data-channels \
            --disable-turn-rest-api \
            --disable-all-plugins \
            --disable-all-loggers \
            --disable-all-transports \
            --enable-websockets \
            --disable-sample-event-handler \
            --disable-websockets-event-handler \
            --disable-gelf-event-handler &&
        make
    - cwd: /var/lib/pikvm-sources/janus-gateway
    - runas: kvmd
    - require:
      - git: "https://github.com/meetecho/janus-gateway"
      - file: /var/lib/pikvm-sources/janus-gateway
      - pkg: kvmd-deps
    - unless: test /var/lib/pikvm-sources/janus-gateway/janus -nt /var/lib/pikvm-sources/janus-gateway/.git/index

# install to temp dir, as janus's makefile try to get git hash, and this fails as root from non root-owned .git
janus-make-install:
  cmd.run:
    - name: make install DESTDIR=/var/lib/pikvm-sources/janus-gateway-bin
    - cwd: /var/lib/pikvm-sources/janus-gateway
    - runas: kvmd
    - onchanges:
      - cmd: janus-make

/usr/local/bin/janus:
  file.copy:
    - source: /var/lib/pikvm-sources/janus-gateway-bin/usr/local/bin/janus
    - makedirs: True
    - dir_mode: 755
    - force: true

# file.copy can't recurse...
"rm -rf /usr/local/lib/janus/transports && mkdir -p /usr/local/lib/janus && cp -rd /var/lib/pikvm-sources/janus-gateway-bin/usr/local/lib/janus/transports /usr/local/lib/janus/transports":
  cmd.run:
  - onchanges:
    - cmd: janus-make-install

"rm -rf /usr/local/include/janus && cp -rd /var/lib/pikvm-sources/janus-gateway-bin/usr/local/include/janus /usr/local/include/":
  cmd.run:
  - onchanges:
    - cmd: janus-make-install

/usr/local/share/janus/javascript/janus.js-copy:
  file.copy:
  - name: /usr/local/share/janus/javascript/janus.js
  - source: /var/lib/pikvm-sources/janus-gateway-bin/usr/local/share/janus/javascript/janus.js
  - makedirs: True
  - dir_mode: 755
  - force: true

/usr/local/share/janus/javascript/adapter.js:
  file.managed:
  - source: "https://webrtc.github.io/adapter/adapter-latest.js"
  - source_hash: 6128cd1d524521d93c9b7601ec80063aa50bb35bd420964fa5984c13df31b542

/usr/local/share/janus/javascript/janus.js-prepend:
  file.prepend:
  - name: /usr/local/share/janus/javascript/janus.js
  - text: "import \"./adapter.js\""
  - require:
    - file: /usr/local/share/janus/javascript/janus.js-copy

/usr/local/share/janus/javascript/janus.js-export:
  file.replace:
  - name: /usr/local/share/janus/javascript/janus.js
  - pattern: "^function Janus\\("
  - repl: "export function Janus("
  - require:
    - file: /usr/local/share/janus/javascript/janus.js-copy

#############
### ustreamer
#############

https://github.com/pikvm/ustreamer:
  git.latest:
    - target: /var/lib/pikvm-sources/ustreamer
    - branch: master
    - rev: c848756d53626d2ba462a698777c6f4e32bf100c
    - user: kvmd
    - force_reset: true
    - require:
      - file: /var/lib/pikvm-sources

/var/lib/pikvm-sources/ustreamer:
  file.patch:
    - source: salt://files/ustreamer-4k.patch
    - strip: 1

# incremental ustreamer builds usually fail...
ustreamer-clean:
  cmd.run:
  - name: git clean -f -x -d
  - cwd: /var/lib/pikvm-sources/ustreamer
  - runas: kvmd
  - onchanges:
    - git: "https://github.com/pikvm/ustreamer"

ustreamer-make:
  cmd.run:
    - name: "rm -rf src/build python/build python/ustreamer.egg-info && make WITH_PYTHON=1 WITH_JANUS=1"
    - cwd: /var/lib/pikvm-sources/ustreamer
    - env:
      - CFLAGS: "-I/usr/local/include/janus"
    - runas: kvmd
    - require:
      - git: "https://github.com/pikvm/ustreamer"
      - pkg: kvmd-deps
      - file: /var/lib/pikvm-sources/ustreamer
      - cmd: ustreamer-clean
    - unless: test /var/lib/pikvm-sources/ustreamer/ustreamer -nt /var/lib/pikvm-sources/ustreamer/.git/index

ustreamer-make-install:
  cmd.run:
    - name: make install WITH_PYTHON=1 WITH_JANUS=1
    - cwd: /var/lib/pikvm-sources/ustreamer
    - runas: root
    - onchanges:
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
    - rev: 16a1dbd9ed3ec176a06a331964c337842471f857  # v4.71
    - force_reset: true
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
    - onchanges:
      - git: "https://github.com/pikvm/kvmd"

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
    - force: True
{% endmacro -%}

{{ copy_kvmd_file("configs/kvmd/main/v2-hdmi-rpi4.yaml", "/etc/kvmd/main.yaml") }}
{{ copy_kvmd_file("configs/kvmd/logging.yaml", "/etc/kvmd/logging.yaml") }}
{{ copy_kvmd_file("configs/kvmd/auth.yaml", "/etc/kvmd/auth.yaml") }}
{{ copy_kvmd_file("configs/kvmd/ipmipasswd", "/etc/kvmd/ipmipasswd") }}
{{ copy_kvmd_file("configs/kvmd/vncpasswd", "/etc/kvmd/vncpasswd") }}
{{ copy_kvmd_file("configs/kvmd/htpasswd", "/etc/kvmd/htpasswd") }}
{{ copy_kvmd_file("configs/os/udev/v2-hdmi-rpi4.rules", "/etc/udev/rules.d/98-kvmd.rules") }}
{{ copy_kvmd_file("configs/os/services/kvmd.service", "/etc/systemd/system/kvmd.service") }}
{{ copy_kvmd_file("configs/os/services/kvmd-vnc.service", "/etc/systemd/system/kvmd-vnc.service") }}
{{ copy_kvmd_file("configs/os/services/kvmd-otg.service", "/etc/systemd/system/kvmd-otg.service") }}
{{ copy_kvmd_file("configs/os/services/kvmd-janus-static.service", "/etc/systemd/system/kvmd-janus-static.service") }}

/etc/kvmd/meta.yaml:
  file.managed:
  - contents: |
      server:
        host: {{grains['id']}}
      kvm: {}

/usr/share/kvmd/platform:
  file.managed:
  - contents: |
      PIKVM_MODEL=v3
      PIKVM_VIDEO=hdmi
      PIKVM_BOARD=rpi4

/etc/systemd/system/kvmd-janus-static.service.d/paths.conf:
  file.managed:
  - contents: |
      [Service]
      ExecStart=
      ExecStart=/usr/local/bin/janus --disable-colors --plugins-folder=/usr/local/lib/ustreamer/janus --configs-folder=/etc/kvmd/janus
  - makedirs: True
  - mode: 644

/etc/systemd/system/kvmd-janus-static.service.d/deps.conf:
  file.managed:
  - contents: |
      [Unit]
      PartOf=kvmd.service
  - makedirs: True
  - mode: 644

/etc/systemd/system/kvmd.service.d/janus.conf:
  file.managed:
  - contents: |
      [Unit]
      Wants=kvmd-janus-static.service
  - makedirs: True
  - mode: 644

/etc/systemd/system/kvmd-otg.service.d/cleanup.conf:
  file.managed:
  - contents: |
      [Service]
      # cleanup after possibly unclean previous stop, otherwise start fails
      ExecStartPre=-find /sys/kernel/config/usb_gadget/kvmd -delete
      ExecStartPre=-rm -rf /run/kvmd/otg
  - makedirs: True
  - mode: 644

/etc/kvmd/janus:
  file.symlink:
  - target: /var/lib/pikvm-sources/kvmd/configs/janus

/etc/kvmd/nginx:
  file.symlink:
  - target: /var/lib/pikvm-sources/kvmd/configs/nginx

/etc/nginx/conf.d/kvmd.ctx-http.conf:
  file.symlink:
  - target: /etc/kvmd/nginx/kvmd.ctx-http.conf

/etc/nginx/conf.d/janus.ctx-http.conf:
  file.copy:
  - source: /var/lib/pikvm-sources/kvmd/extras/janus/nginx.ctx-http.conf
  - force: true

/etc/nginx/vhosts.d/kvmd.conf:
  file.managed:
  - contents: |
      server {
          listen 80;
          server_name {{grains['id']}}.testnet {{grains['id']}};
          location /qinstall {
              alias /srv/www/htdocs/qinstall;
              auth_request off;
          }
          location /gitlab-ci {
              alias /srv/www/htdocs/gitlab-ci;
              auth_request off;
          }
          include /etc/kvmd/nginx/kvmd.ctx-server.conf;
          location /janus/ws {
              rewrite ^/janus/ws$ / break;
              rewrite ^/janus/ws\?(.*)$ /?$1 break;
              proxy_pass http://janus-ws;
              include /etc/kvmd/nginx/loc-proxy.conf;
              include /etc/kvmd/nginx/loc-websocket.conf;
          }

          location = /share/js/kvm/janus.js {
              alias /usr/local/share/janus/javascript/janus.js;
              include /etc/kvmd/nginx/loc-nocache.conf;
          }

          location = /share/js/kvm/adapter.js {
              alias /usr/local/share/janus/javascript/adapter.js;
              include /etc/kvmd/nginx/loc-nocache.conf;
          }
      }

# restore "video" group to allow openqa access, kvmd is a member of the group anyway
/etc/udev/rules.d/99-kvmd-fixup.rules:
  file.managed:
    - contents: |
        KERNEL=="video[0-9]*", KERNELS=="fe801000.csi|fe801000.csi1", GROUP="video"
        # Orange Pi 5+
        KERNEL=="video[0-9]*", ENV{ID_PATH}=="platform-fdee0000.hdmi_receiver", SYMLINK+="kvmd-video"
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

/usr/share/kvmd/extras/janus-static/manifest.yaml:
  file.copy:
  - source: /var/lib/pikvm-sources/kvmd/extras/janus-static/manifest.yaml
  - makedirs: True
  - mode: 0755
  - force: true

/usr/share/kvmd/web:
  file.symlink:
  - target: /var/lib/pikvm-sources/kvmd/web

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
    - force: true

/etc/sudoers.d/kvmd:
  file.managed:
    - contents: |
        service-control ALL=(root) NOPASSWD: /bin/systemctl start kvmd-otg.service kvmd.service kvmd-vnc.service
        service-control ALL=(root) NOPASSWD: /bin/systemctl stop kvmd-otg.service kvmd.service kvmd-vnc.service
        kvmd ALL=(root) NOPASSWD: /usr/bin/kvmd-helper-otgmsd-remount

