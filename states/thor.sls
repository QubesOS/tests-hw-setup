/etc/ssh/sshd_config.d/thor.conf:
  file.managed:
  - source: salt://thor/ssh.conf

packages:
  pkg.installed:
  - pkgs:
    - autoconf
    - automake
    - build-essential
    - curl
    - etherwake
    - git
    - libtool
    - libusb-dev
    - lighttpd
    - locales
    - make
    - man-db
    - pkg-config
    - python3
    - python3-dev
    - python3-luma.led-matrix
    - python3-rpi.gpio
    - python3-setuptools
    - rsync
    - sudo
    - tcpdump
    - tftpd-hpa
    - tmux
    - usbutils
    - vim


pi:
  user.present:
  - shell: /bin/bash

sispmctl:
  group.present: []


"https://git.code.sf.net/p/sispmctl/git":
  git.detached:
  - rev: 33f1ed263cc9d0878b7c3358717b1c8ab9ef8b8c
  - target: /home/pi/sispmctl-git
  - user: pi
  - require:
    - user: pi

build sispmctl:
  cmd.run:
  - name: |
      set -e
      autoupdate
      ./autogen.sh
      ./configure --enable-webless
      make
      make install DESTDIR=/home/pi/sispmctl-git/install
  - user: pi
  - cwd: /home/pi/sispmctl-git
  - creates: /home/pi/sispmctl-git/install/usr/local/bin/sispmctl
  - require:
    - git: "https://git.code.sf.net/p/sispmctl/git"

/usr/local/bin/sispmctl:
  file.copy:
  - source: /home/pi/sispmctl-git/install/usr/local/bin/sispmctl
  - makedirs: True
  - force: True
  - mode: 0755
  - onchanges:
    - cmd: build sispmctl

/usr/local/lib/libsispmctl.so.0:
  file.symlink:
  - target: libsispmctl.so.0.2.1

/usr/local/lib/libsispmctl.so.0.2.1:
  file.copy:
  - source: /home/pi/sispmctl-git/install/usr/local/lib/libsispmctl.so.0.2.1
  - force: True
  - onchanges:
    - cmd: build sispmctl

/etc/udev/rules.d/60-sispmctl.rules:
  file.copy:
  - source: /home/pi/sispmctl-git/install/usr/local/share/doc/sispmctl/examples/60-sispmctl.rules
  - force: True
  - mode: 0644
  - onchanges:
    - cmd: build sispmctl

/etc/network/interfaces.d/eth0:
  file.managed:
  - contents: |
      auto eth0
      iface eth0 inet static
        address 192.168.190.2/24
        gateway 192.168.190.1
        post-up ip route add 172.16.0.0/16 via 192.168.190.3
        post-up ip route add 192.168.189.0/24 via 192.168.190.3
        pre-down ip route del 172.16.0.0/16 via 192.168.190.3
        pre-down ip route del 192.168.189.0/16 via 192.168.190.3
  - makedirs: True
  - mode: 0644

/etc/hostname:
  file.managed:
  - contents: thor.testnet

/dev/sda1:
  mount.fstab_present:
  - fs_file: /srv
  - fs_vfstype: ext4


/etc/lighttpd/conf-available/50-testboot.conf:
  file.managed:
  - contents: |
      alias.url += ( "/qinstall" => "/srv/tftp/qinstall" )
      alias.url += ( "/rescue/" => "/srv/tftp/rescue/" )
      alias.url += ( "/rescue-qubes/" => "/srv/tftp/rescue-qubes/" )
      alias.url += ( "/boot-qubes/" => "/srv/tftp/boot-qubes/" )
      alias.url += ( "/grub2-efi" => "/srv/tftp/grub2-efi" )
      alias.url += ( "/ipxe" => "/srv/tftp/ipxe" )
      alias.url += ( "/test" => "/srv/tftp/test" )
  - makedirs: True

lighttpd-enable-mod testboot:
  cmd.run:
  - creates: /etc/lighttpd/conf-enabled/50-testboot.conf

lighttpd-enable-mod accesslog:
  cmd.run:
  - creates: /etc/lighttpd/conf-enabled/10-accesslog.conf

lighttpd-disable-mod unconfigured:
  cmd.run:
  - unless: "! test -f /etc/lighttpd/conf-enabled/99-unconfigured.conf"


control:
  user.present: []

/etc/sudoers.d/control:
  file.managed:
  - contents: |
      Defaults env_keep += "SSH_ORIGINAL_COMMAND"
      control ALL=(ALL:ALL) NOPASSWD:/usr/local/bin/testbed-control

/usr/local/bin/testbed-control:
  file.managed:
  - source: salt://thor/testbed-control
  - mode: 755

/srv/tftp/grub2-efi:
  file.recurse:
  - source: salt://thor/grub2-efi


{% set hosts = salt['pillar.get']('boot-hosts') %}
{% for host in hosts %}
{% set hostid = host | replace('hw', '') %}
/srv/tftp/grub2-efi/testbed{{hostid}}-settings:
  file.managed:
  - contents: |
      # GRUB Environment Block
      testbedid={{hostid}}
      {{hosts[host].get("grub-settings", "")|indent(6)}}

"/srv/tftp/grub2-efi/env-{{hosts[host]["mac"]}}-settings":
  file.symlink:
  - target: testbed{{hostid}}-settings

test{{hostid}}:
  user.present: []

/home/test{{hostid}}/boot:
  file.directory: []

/srv/tftp/test{{hostid}}:
  file.directory: []
  mount.fstab_present:
  - fs_file: /home/test{{hostid}}/boot
  - fs_vfstype: auto
  - fs_mntops: bind

/srv/tftp/test{{hostid}}/grub-openqa.cfg:
  file.managed:
  - source: salt://thor/grub-openqa.cfg.jinja
  - template: jinja
  - context:
      hostid: {{hostid}}
      cmdline_xen: "{{hosts[host].get("cmdline-xen", "")}}"
      cmdline_linux: "{{hosts[host].get("cmdline-linux", "")}}"

{% endfor %}

/etc/default/tftpd-hpa:
  file.managed:
  - contents: |
      # /etc/default/tftpd-hpa
      
      TFTP_USERNAME="tftp"
      TFTP_DIRECTORY="/srv/tftp"
      TFTP_ADDRESS=":69"
      TFTP_OPTIONS="--secure --permissive --verbose"


# used for accessing hal* workers, must match gadget:thor_pubkey
/root/.ssh/id_ed25519:
  file.managed:
  - contents_pillar: "thor:ssh-privkey"
  - mode: 600
