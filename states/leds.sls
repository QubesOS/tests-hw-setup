# SPI access for NeoPixel (ws2811), on a Debian kernel

device-tree-compiler:
  pkg.installed

/etc/default/raspi-firmware-custom:
  file.managed:
  - contents: |
      core_freq=250
      dtparam=spi=on
      dtoverlay=spi

/etc/default/raspi-extra-cmdline:
  file.managed:
  - contents: |
      spidev.bufsiz=32768 iomem=relaxed

/etc/modules-load.d/leds.conf:
  file.managed:
  - contents: |
      spi_bcm2835

/etc/modprobe.d/blacklist-snd.conf:
  file.managed:
  - contents: |
      blacklist snd_bcm2835

/home/pi/overlay/spi.dts:
  file.managed:
  - source: salt://thor/spi.dts
  - makedirs: True
  - user: pi

/home/pi/overlay/Makefile:
  file.managed:
  - source: salt://thor/spi-Makefile
  - makedirs: True
  - user: pi

build spi.dtbo:
  cmd.run:
  - name: make
  - cwd: /home/pi/overlay
  - user: pi
  - onchanges:
    - file: /home/pi/overlay/spi.dts
    - file: /home/pi/overlay/Makefile

/boot/firmware/overlays/spi.dtbo:
  file.copy:
  - source: /home/pi/overlay/spi.dtbo
  - force: True
  - makedirs: True
  # FAT, can't have it different...
  - mode: 755
  - onchanges:
    - cmd: build spi.dtbo

"https://github.com/rpi-ws281x/rpi-ws281x-python":
  git.detached:
  - rev: ca5645fadd1d43942477f3629aac14a9cf6d32a7
  - user: pi
  - target: /home/pi/rpi-ws281x-python
  - submodules: True

install rpi-ws281x-python:
  cmd.run:
  - name: python3 ./setup.py install
  - cwd: /home/pi/rpi-ws281x-python/library
  - onchanges:
    - git: "https://github.com/rpi-ws281x/rpi-ws281x-python"

/etc/udev/rules.d/90-gpiomem.rules:
  file.managed:
  - contents: |
      # rpi-ws281x expects /dev/gpiomem as on the kernel from Raspberry fundation
      KERNEL=="mem", SYMLINK+="gpiomem"

/usr/local/bin/stripes:
  file.managed:
  - source: salt://thor/stripes
  - mode: 755
