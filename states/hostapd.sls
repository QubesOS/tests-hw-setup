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
    - enable: False

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


systemd-sysvcompat:
  pkg.removed: []

/etc/init.d/boot.local:
  file.absent: []

/usr/local/bin/startup-misc:
  file.managed:
    - contents: |
        #!/bin/sh

        modprobe nf_tables
        modprobe nf_nat
        modprobe nft_chain_nat

        nft add table nat
        nft 'add chain nat postrouting { type nat hook postrouting priority 100 ; }'
        nft add rule nat postrouting masquerade

        echo 1 > /proc/sys/net/ipv4/ip_forward
        # shelly plug, if applicable
        nft 'add chain nat prerouting { type nat hook prerouting priority -100; }'
        nft 'add rule nat prerouting ip saddr 192.168.190.2 tcp dport 81 dnat to 192.168.0.10:80'

    - makedirs: True
    - mode: 0755

/etc/systemd/system/startup-misc.service:
  file.managed:
    - contents: |
        [Unit]
        [Service]
        ExecStart=/usr/local/bin/startup-misc
        RemainAfterExit=true
        [Install]
        WantedBy=multi-user.target
    - makedirs: True

startup-misc.service:
  service.running:
  - require:
    - file: /etc/systemd/system/startup-misc.service
    - file: /usr/local/bin/startup-misc
  - enable: True
