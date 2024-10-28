openqa:
  worker:
    hosts:
     - openqa.qubes-os.org
    hostname: ...
    worker_class: ...
    ssh_pubkey: ... pubkey of the privkey below ...
    ssh_key: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ...
      -----END OPENSSH PRIVATE KEY-----
    # options: ttyUSB0, ttyAMA1, tcp (default)
    serial: ttyAMA1
    # optional extra xen options to setup com1
    serial_xen_opts: com1=115200,8n1
    ustreamer: True
    kickstart-extra: |
      %post
      echo something to do after install
      %end

  hosts:
    openqa.qubes-os.org:
      key: ....API KEY...
      secret: ....API SECRET...

gadget:
  thor_pubkey: SSH PUBKEY
  # supported: usb, ps2; default: usb; ps2 requires https://docs.pikvm.org/pico_hid_bridge/
  hid: usb

boot:
  restore_efi: "IPV4"

buttons:
  # example:
  power: "servo 17 4.0 1.8"
  # PiKVMv3
  #power: "switch 23 0 1"
  #reset: "switch 27 0 1"

system_state:
  # example, PiKVMv3
  power: "led 24 1"

hostapd:
  ap_name: xxxx
  wpa_passphrase: xxxx
  # currently unused, as default Qubes' configuration use random MAC anyway
  client_mac: 'XX:XX:XX:XX:XX:XX'
