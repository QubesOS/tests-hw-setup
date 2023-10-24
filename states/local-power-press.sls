/usr/local/bin/power-press:
  file.managed:
    - source: salt://files/power-press
    - mode: '0755'

# RPi.GPIO isn't packaged...
power-press-pkgs:
  pkg.installed:
    - resolve_capabilities: True
    - pkgs:
      - python3-pip
      - python3-devel
      - gcc

RPi.GPIO:
  pip.installed:
    - extra_args:
      - "--break-system-packages"
    - require:
      - pkg: power-press-pkgs

/etc/openqa/hw-control.conf-buttons:
  ini.options_present:
    - name: /etc/openqa/hw-control.conf
    - separator: '='
    - sections:
        buttons: {{salt['pillar.get']('buttons') | yaml}}
        system_state: {{salt['pillar.get']('system_state', {}) | yaml}}

control:
  user.present:
  - usergroup: True
  - password: "*"

/home/control/.ssh/authorized_keys:
  file.managed:
    - makedirs: True
    - owner: control
    - dir_mode: 0755
    - mode: 0644
    - contents: |
        restrict,command="sudo /usr/local/bin/power-press ssh" {{salt['pillar.get']('gadget:thor_pubkey', "")}}

/etc/sudoers.d/control:
  file.managed:
    - mode: 0400
    - contents: |
        Defaults:control env_keep+=SSH_ORIGINAL_COMMAND
        control ALL=(root) NOPASSWD: /usr/local/bin/power-press
