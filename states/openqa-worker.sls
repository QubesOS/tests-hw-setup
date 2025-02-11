{% set hostname =  salt['pillar.get']('openqa:worker:hostname', {}) %}
{% set hostid = hostname | replace('hal9', '') | int %}
{% set worker_class =  salt['pillar.get']('openqa:worker:worker_class', '') %}
{% set ip =  salt['grains.get']('ipv4', [])[0] %}
{% set pool = salt['pillar.get']('openqa:worker:pool', 0) %}
{% set hosts = salt['pillar.get']('openqa:worker:hosts', {}) %}
{% set shared_assets = salt['pillar.get']('openqa:worker:shared_assets', False) %}

packman:
  pkgrepo.managed:
    - humanname: Packman repository (openSUSE_Tumbleweed)
    - baseurl: https://ftp.gwdg.de/pub/linux/packman/suse/openSUSE_Tumbleweed
    - gpgkey: https://ftp.gwdg.de/pub/linux/packman/suse/openSUSE_Tumbleweed/repodata/repomd.xml.key
    - gpgcheck: 1
    # FIXME!
    - gpgautoimport: True

# network.system does not support OpenSUSE :/
# (or rather: 'ip' modules is not provided there)
hostnamectl set-hostname {{ hostname }}:
  cmd.run:
    - unless: '[ "$(hostname)" = {{ hostname }} ]'

openqa-worker-pkgs:
  pkg.installed:
    - pkgs:
      - openQA-worker
      - ffmpeg-4
      - nginx
      - vim
      - xorriso
      - mtools
      - pngquant
      {% if shared_assets -%}
      - nfs-client
      {% endif %}

openqa-cmds:
  file.recurse:
    - name: /usr/local/openqa-cmds
    - source: salt://openqa-cmds
    - file_mode: 0755
    - include_pat:
      - openqa-*
      - mount-iso

openqa-cmds-non-exec:
  file.recurse:
    - name: /usr/local/openqa-cmds
    - source: salt://openqa-cmds
    - file_mode: 0644
    - include_pat:
      - 1024x768.txt
      - thor-known-hosts
      - functions

# syslinux pkg is x86-only, extract the single file we need
# extracted from https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz
/usr/local/lib/isolinux/isohdpfx.bin:
  file.managed:
    - source: salt://files/isohdpfx.bin
    - makedirs: True

/etc/sysctl.d/openqa.conf:
  file.managed:
    - contents: |
        fs.pipe-max-size = 4194304

workers-global:
  file.managed:
    - name: /etc/openqa/workers.ini
    - contents: |
        [global]
        HOST = {% for host in hosts %}https://{{host}} {% endfor %}
        #HOST = http://nemezis.lan:81
        WORKER_HOSTNAME = {{ hostname }}
        AUTOINST_URL_HOSTNAME = {{ hostname }}.testnet
        {% if not shared_assets -%}
        CACHEDIRECTORY = /var/lib/openqa/cache
        CACHELIMIT = 12
        CACHEWORKERS = 1
        {% endif -%}
        USE_PNGQUANT = 1
        UPLOAD_CHUNK_SIZE = 10000000
        # force x86_64, even though worker itself is arm64
        ARCH = x86_64
        WORKER_CLASS = {{ worker_class }}
        DEFAULT_CLICK_SLEEP = 0.05
        DEFAULT_DCLICK_SLEEP = 0.05
        GENERAL_HW_CMD_DIR = /usr/local/openqa-cmds
        GENERAL_HW_POWERON_CMD = openqa-poweron
        GENERAL_HW_POWEROFF_CMD = openqa-poweroff
        GENERAL_HW_EJECT_CMD = openqa-eject
        GENERAL_HW_FLASH_CMD = openqa-flash
        GENERAL_HW_FLASH_ARGS = --hostid={{ hostid }}
        GENERAL_HW_IMAGE_CMD = openqa-store-asset
        GENERAL_HW_IMAGE_ARGS = --hostid={{ hostid }}
        {% if salt['pillar.get']('openqa:worker:ustreamer', False) -%}
        GENERAL_HW_VIDEO_STREAM_URL = ustreamer:///dev/video0?fps=2
        {% else -%}
        GENERAL_HW_VIDEO_STREAM_URL = /dev/video0?fps=2
        {% endif -%}
        GENERAL_HW_EDID = file=/usr/local/openqa-cmds/1024x768.txt
        GENERAL_HW_INPUT_CMD = openqa-input
        GENERAL_HW_SOL_CMD = openqa-serial
        GENERAL_HW_SOL_ARGS = --hostid={{ hostid }}
        {% if shared_assets -%}
        SYNC_ASSETS_HOOK = ssh -o UserKnownHostsFile=/usr/local/openqa-cmds/thor-known-hosts openqa-share@thor.testnet
        {% endif -%}
{%- if salt['pillar.get']('hostapd:wpa_passphrase') %}
        WIFI_PASSWORD = {{ salt['pillar.get']('hostapd:wpa_passphrase') }}
        WIFI_NAME = {{ salt['pillar.get']('hostapd:ap_name') }}
{% endif %}
{%- if salt['pillar.get']('openqa:worker:serial_xen_opts', '') %}
        SERIAL_XEN_OPTS = {{ salt['pillar.get']('openqa:worker:serial_xen_opts', '') }}
{% endif %}
{% if not shared_assets -%}
{%- for host in hosts %}
        [https://{{host}}]
        TESTPOOLSERVER = rsync://{{host}}/openqa-tests
{% endfor %}
{% endif %}


{% for host in hosts %}
{% set ip = salt['pillar.get']('openqa:hosts:' + host + ':ip', '') %}
{% set key = salt['pillar.get']('openqa:hosts:' + host + ':key', '') %}
{% set secret = salt['pillar.get']('openqa:hosts:' + host + ':secret', '') %}

{% if ip %}
{{host}}:
  host.present:
    - ip: {{ip}}
{% endif %}

client-{{host}}:
  file.append:
    - name: /etc/openqa/client.conf
    - require:
      - pkg: openqa-worker-pkgs
    - text: |
        [{{host}}]
        key = {{key}}
        secret = {{secret}}
{% endfor %}

openqa-worker.target:
  service.enabled: []

openqa-worker@{{ hostid }}:
  service.running:
    - enable: True

# mask default openqa-worker@1 to avoid conflicts
{% if hostid != 1 %}
openqa-worker@1:
  service.masked: []
{% endif %}

{% if not shared_assets %}
/var/lib/openqa/share/factory:
  file.directory:
    - user: _openqa-worker
    - group: root
    - mode: 755
    - makedirs: True

/var/lib/openqa/share/tests:
  file.directory:
    - user: _openqa-worker
    - group: root
    - mode: 755
    - makedirs: True

openqa-worker-cacheservice:
  service.running:
    - enable: True

openqa-worker-cacheservice-minion:
  service.running:
    - enable: True
    - require:
      - service: openqa-worker-cacheservice
{% endif %}

/srv/www/htdocs/qinstall/iso:
  file.directory:
    - makedirs: True

/srv/www/htdocs/qinstall/ks.cfg:
  file.managed:
    - source: salt://files/ks.cfg.jinja
    - template: jinja

/etc/sudoers.d/openqa_realhw:
  file.managed:
    - contents: |
        _openqa-worker ALL=(root) NOPASSWD: /usr/local/bin/gadget-control
        _openqa-worker ALL=(root) NOPASSWD: /bin/systemctl start gadget-control.service, /bin/systemctl stop gadget-control.service
        _openqa-worker ALL=(root) NOPASSWD: /usr/local/bin/power-press
        _openqa-worker ALL=(root) NOPASSWD: /usr/local/openqa-cmds/mount-iso
        service-control ALL=(root) NOPASSWD: /bin/systemctl start openqa-worker.target, /bin/systemctl stop openqa-worker.target
        service-control ALL=(root) NOPASSWD: /bin/systemctl start openqa-worker.target openqa-worker-cacheservice-minion.service
        service-control ALL=(root) NOPASSWD: /bin/systemctl start openqa-worker-cacheservice.service, /bin/systemctl start openqa-worker-cacheservice-minion.service
        service-control ALL=(root) NOPASSWD: /usr/sbin/ether-wake

/etc/openqa/hw-control.conf-openqa:
  ini.options_present:
    - name: /etc/openqa/hw-control.conf
    - separator: '='
    - sections:
        disk: {{salt['pillar.get']('openqa:worker:disk_config') | yaml}}
        console:
          serial: {{salt['pillar.get']('openqa:worker:serial', 'tcp')}}
          serial_speed: {{salt['pillar.get']('openqa:worker:serial_speed', '115200')}}

openqa-worker-user:
  user.present:
    - name: _openqa-worker
    - groups:
      - video
    - require:
      # don't create the user if packages install failed
      - pkg: openqa-worker-pkgs
    - remove_groups: False
    - createhome: False

/etc/systemd/system/openqa-worker-ssh-agent.service:
  file.managed:
    - source: salt://files/openqa-worker-ssh-agent.service

/etc/systemd/system/openqa-worker@.service.d/agent.conf:
  file.managed:
    - source: salt://files/openqa-worker_agent.conf
    - makedirs: True

/etc/systemd/system/openqa-worker@.service.d/time-sync.conf:
  file.managed:
    - contents: |
        [Unit]
        After=time-sync.target
    - makedirs: True

/etc/systemd/system/openqa-worker@.service.d/claim-sut.conf:
  file.managed:
    - contents: |
        [Service]
        ExecStart=
        ExecStart=/usr/share/openqa/script/worker --isotovideo /usr/local/bin/openqa-claim-wrap --instance %i
    - makedirs: True

/usr/local/bin/openqa-claim-wrap:
  file.managed:
    - source: salt://files/openqa-claim-wrap
    - mode: 0755

systemctl daemon-reload:
  cmd.run:
    - onchanges:
      - file: /etc/systemd/system/openqa-worker-ssh-agent.service
      - file: /etc/systemd/system/openqa-worker@.service.d/agent.conf
      - file: /etc/systemd/system/openqa-worker@.service.d/claim-sut.conf

/usr/local/openqa-cmds/test-control:
  file.managed:
    - mode: '0600'
    - owner: _openqa-worker
    - contents_pillar: openqa:worker:ssh_key

openqa-worker-ssh-agent.service:
  service.running:
    - enable: True
    - require:
      - file: /usr/local/openqa-cmds/test-control

nginx:
  service.running:
    - enable: True

service-control-user:
  user.present:
    - name: service-control
    - remove_groups: False
    - createhome: True

/home/service-control/.ssh/authorized_keys:
  file.managed:
    - makedirs: True
    - owner: service-control
    - dir_mode: 0755
    - mode: 0644
    - contents: |
        restrict {{salt['pillar.get']('gadget:thor_pubkey', "")}}

/etc/systemd/system/hdmi-init-edid.service:
  file.managed:
    - contents: |
        [Unit]
        Description=EDID loader for TC358743
        Wants=dev-video0.device
        After=dev-video0.device systemd-modules-load.service
        
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/v4l2-ctl --device=/dev/video0 --set-edid=file=/usr/local/openqa-cmds/1024x768.txt --fix-edid-checksums --info-edid
        ExecStop=/usr/bin/v4l2-ctl --device=/dev/video0 --clear-edid
        RemainAfterExit=true
        
        [Install]
        WantedBy=multi-user.target

hdmi-init-edid.service:
  service.running:
    - enable: True
    - require:
      - file: /etc/systemd/system/hdmi-init-edid.service

{% if shared_assets %}
/var/lib/openqa/share:
  mount.mounted:
  - device: "thor.testnet:/srv/openqa-share"
  - opts: "ro"
  - persist: True
  - fstype: nfs4
{% endif %}

#FIXME: order openqa after time sync?
