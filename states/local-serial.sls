# depends on gadget.sls which sets dtoverlay=uart5

console:
  user.present:
   - password: "*"

/home/console/.ssh/authorized_keys:
  file.managed:
    - makedirs: True
    - user: console
    - dir_mode: 0700
    - mode: 0644
    - contents: |
        {{salt['pillar.get']('gadget:thor_pubkey', "")}}

/etc/udev/rules.d/90-console-access.rules:
  file.managed:
    - contents: |
        KERNEL=="ttyAMA1", OWNER="console", GROUP="_openqa-worker"
        KERNEL=="ttyAMA4", OWNER="console", GROUP="_openqa-worker"
        KERNEL=="ttyAMA5", OWNER="console", GROUP="_openqa-worker"
        KERNEL=="ttyUSB0", OWNER="console", GROUP="_openqa-worker"

boot-menu-pkgs:
  pkg.installed:
    - resolve_capabilities: True
    - pkgs:
      - picocom
      - python3-pexpect
      - python3-pyserial

/usr/local/bin/connect-serial-console:
  file.managed:
    - source: salt://files/connect-serial-console
    - mode: 0755

{% if salt['pillar.get']('boot-menu-interact') %}
/usr/local/bin/boot-menu-interact:
  file.managed:
    - source: salt://files/{{ grains['id'] }}-boot-menu-interact
    - mode: 0755
{% endif %}
