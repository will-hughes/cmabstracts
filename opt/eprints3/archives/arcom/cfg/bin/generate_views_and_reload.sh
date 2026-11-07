#!/bin/bash
# Nightly view regeneration, one process per view (avoids OOM).
# Guards added 26 Oct 2026 after the 24 Oct disk-full incident.
# Research design pages added 6 Nov 2026.
LOG=/opt/eprints3/var/log/generate_views.log
MAXLOG=$((50*1024*1024))      # per-view log cap: 50 MB
MINFREE_KB=$((5*1024*1024))   # stop if less than 5 GB free on /

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }
abort() { log "ABORT: $*"; echo "generate_views ABORT: $*" >&2; exit 1; }

for v in year creators journal_volume thesis iterm subject topic; do
  avail=$(df --output=avail -k / | tail -1)
  [ "$avail" -lt "$MINFREE_KB" ] && abort "less than 5 GB free on / before view $v"
  mysql -e 'SELECT 1' >/dev/null 2>&1 || abort "MySQL not responding before view $v"

  log "START $v"
  /opt/eprints3/bin/generate_views arcom --view "$v" 2>&1 | head -c "$MAXLOG" >> "$LOG"
  rc=${PIPESTATUS[0]}
  if [ "$rc" -eq 0 ]; then
    log "OK $v"
  else
    abort "view $v failed (exit $rc; 141 means the 50 MB log cap was hit)"
  fi
done

# Research design browse pages: reuse the iterm view pages just generated.
# Failures are logged but do not stop the Apache restart, since the views
# themselves have already succeeded.
log "START research_design"
if perl /opt/eprints3/archives/arcom/cfg/bin/research_design.pl --write >> "$LOG" 2>&1; then
  log "OK research_design"
  log "START generate_static"
  if /opt/eprints3/bin/generate_static arcom >> "$LOG" 2>&1; then
    log "OK generate_static"
  else
    log "FAILED generate_static"
  fi
else
  log "FAILED research_design (previous pages left in place)"
fi

log "Restarting Apache"
sudo systemctl restart apache2
log "Apache restarted"