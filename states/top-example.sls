base:
  '*':
    - misc
  'hal9* and G@productname:Raspberry*Pi*4*':
    - match: compound
    - rpi4
  'hal9* and G@productname:*Orange*5*Plus':
    - match: compound
    - opi5plus
  hal9002:
    - openqa-worker
    - gadget
    - local-serial
    - local-power-press
    - pikvm
    - gitlab-runner
