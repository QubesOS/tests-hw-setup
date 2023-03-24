{% set runner_name = grains['id'] %}
{% set runner_tags = salt['pillar.get']('gitlab-ci:tags', runner_name) %}

/etc/pki/RPM-GPG-gitlab-runner:
  file.managed:
    - source: https://packages.gitlab.com/runner/gitlab-runner/gpgkey/runner-gitlab-runner-4C80FB51394521E9.pub.gpg
    - source_hash: 1594eb7695ec8fff6b96646913abea3fd42a48e6fe7313c97ea8959a34d53329

/etc/pki/RPM-GPG-gitlab-runner-repo:
  file.managed:
    #- source: https://packages.gitlab.com/runner/gitlab-runner/gpgkey
    - source: https://packages.gitlab.com/gpg.key
    - source_hash: 34170579d600a258ab1fbe7efa8078a36ba80793a99a1c1ad55d3be6f2c41c00

gitlab-repo:
  file.managed:
    - name: /etc/zypp/repos.d/gitlab-runner.repo
    - contents: |
        # no dedicated opensuse package right now, use f36 instead
        [runner_gitlab-runner]
        name=runner_gitlab-runner
        baseurl=https://packages.gitlab.com/runner/gitlab-runner/fedora/36/$basearch
        repo_gpgcheck=1
        gpgcheck=1
        enabled=1
        gpgkey=file:///etc/pki/RPM-GPG-gitlab-runner
               file:///etc/pki/RPM-GPG-gitlab-runner-repo
        sslverify=1
        sslcacert=/etc/pki/tls/certs/ca-bundle.crt
        metadata_expire=300

rpm --import /etc/pki/RPM-GPG-gitlab-runner-repo:
  cmd.run:
    - onchanges:
      - file: /etc/pki/RPM-GPG-gitlab-runner-repo

rpm --import /etc/pki/RPM-GPG-gitlab-runner:
  cmd.run:
    - onchanges:
      - file: /etc/pki/RPM-GPG-gitlab-runner

zypper --non-interactive ref:
  cmd.run: []

/etc/systemd/system/gitlab-runner.service:
  file.managed:
    - contents: |
        [Unit]
        Description=GitLab Runner
        ConditionFileIsExecutable=/usr/bin/gitlab-runner
        After=syslog.target network.target
        
        [Service]
        StartLimitInterval=5
        StartLimitBurst=10
        User=gitlab-runner
        ExecStart=/usr/bin/gitlab-runner "run" "--working-directory" "/var/lib/gitlab-runner" "--config" "/var/lib/gitlab-runner/.gitlab-runner/config.toml" "--service" "gitlab-runner" "--user" "gitlab-runner"
        Restart=always
        RestartSec=120
        EnvironmentFile=-/etc/sysconfig/gitlab-runner
        
        [Install]
        WantedBy=multi-user.target


/var/lib/gitlab-runner/.gitlab-runner/config.toml:
  file.managed:
    - source: salt://gitlab-runner-conf.toml
    - makedirs: True
    - user: gitlab-runner
    - group: gitlab-runner
    - template: jinja

podman-pkgs:
  pkg.installed:
  - pkgs:
    - podman
    - cni-plugins
    # default 'runc' fails on setting /proc/self/oom_score_adj
    - crun

gitlab-runner:
  pkg.installed:
   - require:
     - gitlab-repo
  service.running:
   - enable: True
   - restart: True
   - watch:
     - file: /var/lib/gitlab-runner/.gitlab-runner/config.toml
  user.present:
   - home: /var/lib/gitlab-runner
   - remove_groups: False
   - uid: 1004

#gitlab-runner-register:
#  cmd.run:
#    - runas: gitlab-runner
#    - name: echo -e '{{ salt['pillar.get']('gitlab-ci:gitlab_ci_url') }}\n{{ salt['pillar.get']('gitlab-ci:gitlab_ci_register_token') }}\n{{ runner_name }}\n{{ runner_tags }}\nshell\n' | gitlab-runner register
#    - unless: file.exists /var/lib/gitlab-runner/.gitlab-runner/config.toml

/srv/www/htdocs/gitlab-ci:
  file.directory:
  - user: gitlab-runner

/etc/systemd/system/gitlab-runner-ssh-agent.service:
  file.managed:
    - source: salt://files/gitlab-runner-ssh-agent.service

gitlab-runner-ssh-agent.service:
  service.running:
    - enable: True
    - reload: True
    - require:
      - file: /usr/local/openqa-cmds/test-control


# TODO:
# systemctl --user --now enable podman.socket
# sudo loginctl enable-linger gitlab-runner
