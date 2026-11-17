---
title: Deploying playbooks
description: Select hosts and roles for safe, targeted Ansible runs.
---

Run commands from the repository root. The Vault prompt is required for
encrypted variables:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml
```

By default, the playbook deploys one host at a time. Use `--limit` to select
specific hosts or inventory groups:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit <hostname>
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit gateways
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit "services_map:services_web"
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit monitoring
```

Use check mode before applying a targeted change:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit <host-or-group> --check
```

To run only selected roles, combine a host limit with their tags. The role and
tag associations are defined in `setup.yml`:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml \
  --limit <hostname> --tags "batman-adv,batctl"
```

Some `always` tasks can reboot a host when a reboot is required, even during a
tagged run. Review the selected host and task output before applying changes.

The default serial deployment is safest for routine changes. To deploy all
gateways at once, for example during a fast static-page update, explicitly
override it:

```sh
ansible-playbook --vault-id=fastd_key@prompt setup.yml -e deploy_serial=100%
```

Alertmanager listens on localhost on the monitoring host. Access its UI through
an SSH tunnel:

```sh
ssh -N -L 9093:127.0.0.1:9093 root@<monitoring-host>
```

Then open `http://127.0.0.1:9093`.
