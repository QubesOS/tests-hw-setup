openqa:
  worker:
    hosts:
     - openqa.qubes-os.org
    hostname: ...
    worker_class: ...
    ssh_pubkey: ... pubkey of the below privkey ...
    ssh_key: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ...
      -----END OPENSSH PRIVATE KEY-----

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
