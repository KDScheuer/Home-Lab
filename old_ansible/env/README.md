# Secret .env Files

This directory holds real `.env` files for services that require secrets.
**These files are gitignored and must never be committed.**

Create one file per service that has an `.env.example` in its compose directory:

| File | Service | Required Variables |
|------|---------|-------------------|
| `immich.env` | Immich | `IMMICH_VERSION`, `UPLOAD_LOCATION`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE_NAME`, `DB_DATA_LOCATION` |
| `mealie.env` | Mealie + Postgres | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` |
| `grafana.env` | Grafana | `GF_SECURITY_ADMIN_PASSWORD` |
| `vaultwarden.env` | VaultWarden | `ADMIN_TOKEN` |
| `adguardhome-exporter.env` | AdGuard Exporter | `ADGUARD_PROTOCOL`, `ADGUARD_HOSTNAME`, `ADGUARD_PORT`, `ADGUARD_USERNAME`, `ADGUARD_PASSWORD` |

See each service's `.env.example` file in `roles/services/files/<service>/` for a template.

The AWS credentials for certbot TLS (`aws_access_key_id`, `aws_secret_access_key`)
are passed via Ansible extra-vars at run time — keep them out of files entirely:

```bash
ansible-playbook -i inventory.yml site.yml --tags tls \
  -e "aws_access_key_id=AKIA... aws_secret_access_key=..."
```
