# host-status: runs inside a microvm and tells the host how many agent
# sessions (Claude Code, pi, opencode, ...) are open here, even idle ones, so
# the host does not suspend under them (`power-profile can-sleep` on the
# host). Writes the status file on a virtiofs share every
# HOST_STATUS_INTERVAL seconds:
#
#   agents=<number of agent processes>
#   detail=<name> <count>, ...   (names without a leading "." and "-wrapped")
#
# The host trusts the file while its mtime (host time, set by virtiofsd) is
# less than 60 s old.
#
# Environment (set by the NixOS module; tests point it at fakes):
#   HOST_STATUS_AGENTS    process names (comm) as an extended regex; empty =
#                         always 0
#   HOST_STATUS_FILE      status file (default /run/host-status/status)
#   HOST_STATUS_INTERVAL  seconds between writes (default 15)
#   HOST_STATUS_ONCE      1 = write once and exit (tests)

agents_re=${HOST_STATUS_AGENTS:-}
status_file=${HOST_STATUS_FILE:-/run/host-status/status}
interval=${HOST_STATUS_INTERVAL:-15}

# Prints "<count> <detail>" for the running agent processes.
count_agents() {
  local out='' _pid name n=0 detail=''
  local -A per=()
  if [ -n "$agents_re" ]; then
    out=$(pgrep -l -x -- "$agents_re") || true
  fi
  while read -r _pid name; do
    [ -n "$name" ] || continue
    name=${name#.}
    name=${name%-wrapped}
    name=${name%-wrapp}
    per[$name]=$((${per[$name]:-0} + 1))
    n=$((n + 1))
  done <<<"$out"
  for name in "${!per[@]}"; do
    detail+="${detail:+, }$name ${per[$name]}"
  done
  printf '%s %s\n' "$n" "$detail"
}

write_status() {
  local n detail tmp=$status_file.tmp
  read -r n detail < <(count_agents)
  if printf 'agents=%s\ndetail=%s\n' "$n" "$detail" >"$tmp" &&
    mv -f "$tmp" "$status_file"; then
    return 0
  fi
  echo "host-status: cannot write $status_file" >&2
}

while :; do
  write_status
  [ "${HOST_STATUS_ONCE:-0}" = 1 ] && exit 0
  sleep "$interval"
done
