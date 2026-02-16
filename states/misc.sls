{% if salt["grains.get"]("os") == "SUSE" %}
/etc/zypp/zypp.conf:
  file.append:
    - text: "solver.onlyRequires = true"
{% endif %}

/etc/systemd/journald.conf.d/30-limit.conf:
  file.managed:
    - contents: |
        [Journal]
        SystemMaxUse=300M
    - makedirs: True

monitoring:
  pkg.installed:
  - name: {{ salt['pillar.get']('pkg-names:prometheus-node-exporter') }}

{{ salt['pillar.get']('service-names:prometheus-node-exporter') }}:
  service.running:
  - enable: true

# ether-wake no longer installed by default (was part of net-tools?)
{{ salt['pillar.get']('pkg-names:ether-wake') }}:
  pkg.installed: []
