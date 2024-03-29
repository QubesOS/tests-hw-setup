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
