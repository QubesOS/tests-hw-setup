hostapd_pkgs:
  pkg.installed:
    - pkgs:
      - hostapd
      - iw
      - wireless-tools


NetworkManager:
  pkg.removed: []


wicked:
  pkg.installed: []
  service.running:
  - enable: True

hostapd_service:
  service.running:
    - name: hostapd.service
    - enable: True

/etc/hostapd.conf:
  file.managed:
    - source: salt://files/hostapd.conf.jinja
    - template: jinja
    - context:
        ap_name: {{ salt['pillar.get']('hostapd:ap_name') }}
        wpa_passphrase: {{ salt['pillar.get']('hostapd:wpa_passphrase') }}
    - watch_in:
      - service: hostapd_service


dnsmasq:
  pkg.installed

/etc/dnsmasq.d/wlan0.conf:
  file.managed:
    - contents: |
        #dhcp-host={{ salt['pillar.get']('hostapd:client_mac') }},{{ salt['pillar.get']('hostapd:client_ip', '192.168.0.100' ) }}
        dhcp-range=192.168.0.100,192.168.0.100,2m
        listen-address=192.168.0.1
        bind-interfaces
    - watch_in:
      - service: dnsmasq_service

/etc/sysconfig/network/ifcfg-wlan0:
  file.managed:
    - contents: |
        IPADDR=192.168.0.1/24
        NETMASK=255.255.255.0
        BOOTPROTO=static
        STARTMODE='onboot'

# network.managed doesn't bring the interface either
'ifup wlan0':
  cmd.run:
  - onchanges:
    - file: /etc/sysconfig/network/ifcfg-wlan0
  - require:
    - pkg: wicked

/etc/systemd/system/dnsmasq.service.d/30_order.conf:
  file.managed:
    - contents: |
        [Unit]
        After=hostapd.service
        [Service]
        Restart=always
        RestartSec=3s
    - makedirs: True

dnsmasq_service:
  service.running:
    - name: dnsmasq.service
    - enable: True
    - require:
      - cmd: ifup wlan0

# needed for /etc/init.d/boot.local
systemd-sysvcompat:
  pkg.installed: []

/etc/init.d/boot.local:
  file.managed:
    - contents: |
        #!/bin/sh

        iptables -A POSTROUTING -t nat -o eth0 -s 192.168.0.0/24 -j MASQUERADE
        echo 1 > /proc/sys/net/ipv4/ip_forward
        # shelly plug, if applicable
        iptables -t nat -A PREROUTING -s 192.168.190.2 -p tcp --dport 81 -j DNAT --to 192.168.0.10:80

    - makedirs: True
    - mode: 0755
