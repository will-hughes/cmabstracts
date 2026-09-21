#!/bin/bash
# sync-repo.sh — copy publishable config from live paths into the staging repo.
# One-way only: live → repo. Never copy back.
set -euo pipefail
REPO="$HOME/cmabstracts-repo"
EP=/opt/eprints3
ARC=$EP/archives/arcom

mkdir -p "$REPO$ARC/cfg"
rsync -a --delete --delete-excluded \
  --exclude-from="$REPO/.sync-exclude" \
  "$ARC/cfg/" "$REPO$ARC/cfg/"

mkdir -p "$REPO$ARC/ssl"
cp "$ARC/ssl/securevhost.conf" "$REPO$ARC/ssl/"

mkdir -p "$REPO$EP/bin"
cp "$EP/bin/generate_views_and_reload.sh" "$REPO$EP/bin/"

mkdir -p "$REPO/etc/apache2"
rsync -a --delete --delete-excluded \
  --exclude='*.bak' --exclude='*~' \
  /etc/apache2/ "$REPO/etc/apache2/"

mkdir -p "$REPO/etc/logrotate.d"
cp /etc/logrotate.d/eprints-* "$REPO/etc/logrotate.d/"

mkdir -p "$REPO/etc/mysql/mysql.conf.d"
cp /etc/mysql/mysql.conf.d/mysqld.cnf "$REPO/etc/mysql/mysql.conf.d/"

crontab -l > "$REPO/crontab-eprints.txt"
