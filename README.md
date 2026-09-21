# CM Abstracts — EPrints configuration

Configuration for [CM Abstracts](https://cmabstracts.com), a curated catalogue
of construction management research, running on EPrints 3.4.7.

Published for transparency and to make technical support easier.

## Layout

Paths in this repository mirror absolute paths on the server:

- `opt/eprints3/archives/arcom/cfg/` — archive configuration (`arcom` is the archive ID)
- `opt/eprints3/archives/arcom/ssl/securevhost.conf` — hand-maintained Apache vhost
- `opt/eprints3/bin/generate_views_and_reload.sh` — nightly regeneration script
- `etc/apache2/` — Apache configuration
- `etc/logrotate.d/` — log rotation for EPrints logs
- `etc/mysql/mysql.conf.d/mysqld.cnf` — MySQL tuning
- `crontab-eprints.txt` — scheduled jobs for the `eprints` user

## Stack

Ubuntu, Apache 2.4 (mpm_event, mod_perl), MySQL 8.0, EPrints 3.4.7,
behind Cloudflare.

## Not included

Credentials and secrets are kept out of this repository by design:
`database.pl` and `z_secrets.pl` are excluded, as are backups (`*.bak`),
TLS keys, documents and generated HTML.

## How it is maintained

`sync-repo.sh` copies the files above from their live locations into this
repository, one way only (server → repository), applying the exclusions in
`.sync-exclude`. Changes are then reviewed and committed from there.

## Licence

Released under the GNU Lesser General Public License v3.0, the licence
EPrints itself uses. See `COPYING.LESSER` and `COPYING`.
