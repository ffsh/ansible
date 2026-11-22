# Ansible

[![Ansible Lint](https://github.com/ffsh/ansible/actions/workflows/ansible-lint.yml/badge.svg?branch=main)](https://github.com/ffsh/ansible/actions/workflows/ansible-lint.yml)

Ansible playbooks for deploying Freifunk Südholstein gateways and service
hosts.

## Docs

https://ffsh.github.io/ansible/

## Requirements

- Ansible installed ([installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#selecting-an-ansible-package-and-version-to-install))
- Access to the Ansible Vault password for the `fastd_key` vault ID

The repository includes a devcontainer with Ansible and ansible-lint. Open it
with **Dev Containers: Reopen in Container**. To lint locally, run:

```bash
ansible-lint
```

## Quick deployment

From the repository root, deploy to the inventory:

```bash
ansible-playbook --vault-id=fastd_key@prompt setup.yml
```

Limit a run to common inventory groups:

```bash
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit gateways
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit "services_map:services_web"
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit monitoring
```

Preview a targeted run before applying it:

```bash
ansible-playbook --vault-id=fastd_key@prompt setup.yml --limit <host-or-group> --check
```

For role tags, host setup, service-specific procedures, and operational
caveats, see the [deployment guide](docs/src/content/docs/guides/deploying.md)
and the [full documentation](docs/).

## Documentation site

The [documentation site](https://ffsh.github.io/ansible/) contains detailed
guides and reference material; its source is in [docs/](docs/). To preview it
locally:

```bash
cd docs
npm ci
npm run dev
```

See [docs/README.md](docs/README.md) for build and publishing details.
