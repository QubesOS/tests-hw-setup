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

  hosts:
    openqa.qubes-os.org:
      key: ....API KEY...
      secret: ....API SECRET...

gadget:
  thor_pubkey: SSH PUBKEY

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
