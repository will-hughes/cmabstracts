#!/bin/bash
LOG=/opt/eprints3/var/log/generate_views.log

for v in year creators journal_volume thesis iterm subject topic; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') START $v" >> "$LOG"
  /opt/eprints3/bin/generate_views arcom --view "$v" >> "$LOG" 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') OK $v" >> "$LOG"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') FAILED $v (exit $rc)" >> "$LOG"
  fi
done

echo "$(date '+%Y-%m-%d %H:%M:%S') Restarting Apache" >> "$LOG"
sudo systemctl restart apache2
echo "$(date '+%Y-%m-%d %H:%M:%S') Apache restarted" >> "$LOG"