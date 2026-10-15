# power-profile-ctl: root backend of the `power-profile` CLI. Only systemd
# runs it:
#
#   power-profile-ctl apply <profile>  power-profile-apply@<profile>.service
#   power-profile-ctl boot             power-profile-boot.service
#   power-profile-ctl resume           power-profile-resume.service
#
# Profiles (keep in sync with features.hardware.power-profile.profiles and
# power-profile.sh):
#
#   profile           boost  CPU max      EPP            GPU power limit
#   strict            0      strict cap   power          power.min_limit
#   short-boosts      1      short cap    balance_power  short-boosts watts
#   full-speed-heavy  1      cpuinfo_max  balance_power  power.default_limit
#   full-power        1      cpuinfo_max  performance    power.max_limit
#   disabled          stock values saved at boot         power.default_limit
#
# Every profile keeps the stock min freq and the `powersave` governor
# (amd-pstate stays in `active` mode). Write order: boost, max, min,
# governor, EPP. GPU limits are read from nvidia-smi on every apply.
#
# Environment (set by the NixOS module; tests point it at a fake tree):
#   POWER_PROFILE_SYSFS                 sysfs root (default /sys)
#   POWER_PROFILE_RUN_DIR               stock copy, applied record, lock
#   POWER_PROFILE_STATE_FILE            picked profile, written by the CLI
#   POWER_PROFILE_DEFAULT               profile used while nothing is picked
#   POWER_PROFILE_SHORT_BOOSTS_MAX_KHZ  Short boosts CPU cap
#   POWER_PROFILE_STRICT_MAX_KHZ        Strict CPU cap
#   POWER_PROFILE_SHORT_BOOSTS_GPU_W    Short boosts GPU limit (clamped)
#   POWER_PROFILE_NVIDIA_SMI            nvidia-smi path; empty = no GPU control
#   POWER_PROFILE_GPU_WAIT              seconds to wait for the GPU (default 30)

sysfs=${POWER_PROFILE_SYSFS:-/sys}
run_dir=${POWER_PROFILE_RUN_DIR:-/run/power-profile}
state_file=${POWER_PROFILE_STATE_FILE:-/var/lib/power-profile/state}
default_profile=${POWER_PROFILE_DEFAULT:-disabled}
short_max_khz=${POWER_PROFILE_SHORT_BOOSTS_MAX_KHZ:-4000000}
strict_max_khz=${POWER_PROFILE_STRICT_MAX_KHZ:-2000000}
short_gpu_w=${POWER_PROFILE_SHORT_BOOSTS_GPU_W:-102}
nvidia_smi=${POWER_PROFILE_NVIDIA_SMI:-}
gpu_wait=${POWER_PROFILE_GPU_WAIT:-30}

cpufreq=$sysfs/devices/system/cpu/cpufreq
stock_file=$run_dir/stock
applied_file=$run_dir/applied

# Set by any failed write; the unit then exits non-zero so the CLI reports it.
failed=0

warn() {
  echo "power-profile: $*" >&2
}

usage() {
  echo "usage: power-profile-ctl apply <profile> | boot | resume" >&2
  exit 2
}

valid_profile() {
  case $1 in
    strict | short-boosts | full-speed-heavy | full-power | disabled) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints the value of <key> from a key=value file; empty when missing.
read_kv() {
  local file=$1 key=$2 k v value=
  [ -r "$file" ] || return 0
  while IFS='=' read -r k v; do
    if [ "$k" = "$key" ]; then
      value=$v
    fi
  done <"$file"
  printf '%s' "$value"
}

read_file() {
  local value
  [ -r "$1" ] || return 1
  value=$(<"$1") || return 1
  printf '%s' "$value"
}

# Writes <value> to a sysfs <file>, logs a failed write and carries on so one
# bad knob does not leave the rest half-applied.
write() {
  local value=$1 file=$2
  if [ ! -e "$file" ]; then
    warn "missing $file"
    failed=1
    return 0
  fi
  if ! { printf '%s\n' "$value" >"$file"; } 2>/dev/null; then
    warn "cannot write '$value' to $file"
    failed=1
    return 0
  fi
  local now
  now=$(read_file "$file" || true)
  if [ "$now" != "$value" ]; then
    warn "$file reads '$now' after writing '$value'"
  fi
}

lock() {
  mkdir -p "$run_dir"
  exec 9>"$run_dir/lock"
  if ! flock -w 60 9; then
    warn "timed out waiting for $run_dir/lock"
    exit 1
  fi
}

# Saves the real stock CPU values once per boot, before any profile touches
# them. /run is empty after a reboot, so the first call of each boot wins.
save_stock() {
  [ -s "$stock_file" ] && return 0
  if [ ! -d "$cpufreq" ]; then
    warn "no cpufreq at $cpufreq; nothing saved"
    return 0
  fi
  local tmp=$stock_file.tmp p
  {
    printf 'boost %s\n' "$(read_file "$cpufreq/boost" || echo -)"
    for p in "$cpufreq"/policy*; do
      [ -d "$p" ] || continue
      printf 'policy %s %s %s %s %s\n' "${p##*/}" \
        "$(read_file "$p/scaling_min_freq" || echo -)" \
        "$(read_file "$p/scaling_max_freq" || echo -)" \
        "$(read_file "$p/scaling_governor" || echo -)" \
        "$(read_file "$p/energy_performance_preference" || echo -)"
    done
  } >"$tmp"
  mv -f "$tmp" "$stock_file"
  echo "saved stock CPU settings to $stock_file"
}

stock_boost() {
  local key value
  while read -r key value _; do
    if [ "$key" = boost ]; then
      printf '%s' "$value"
      return 0
    fi
  done <"$stock_file"
}

# Prints "<min> <max> <governor> <epp>" saved for a policy.
stock_policy() {
  local key name min max gov epp
  while read -r key name min max gov epp; do
    if [ "$key" = policy ] && [ "$name" = "$1" ]; then
      printf '%s %s %s %s' "$min" "$max" "$gov" "$epp"
      return 0
    fi
  done <"$stock_file"
  return 1
}

apply_cpu() {
  local profile=$1 boost cap epp
  if [ ! -d "$cpufreq" ]; then
    warn "no cpufreq at $cpufreq"
    failed=1
    return 0
  fi

  local status
  status=$(read_file "$sysfs/devices/system/cpu/amd_pstate/status" || echo unknown)
  if [ "$status" != active ]; then
    warn "amd-pstate status is '$status', expected 'active'"
  fi

  case $profile in
    strict) boost=0 cap=$strict_max_khz epp=power ;;
    short-boosts) boost=1 cap=$short_max_khz epp=balance_power ;;
    full-speed-heavy) boost=1 cap='' epp=balance_power ;;
    full-power) boost=1 cap='' epp=performance ;;
    disabled) boost=$(stock_boost) cap='' epp='' ;;
  esac

  if [ -e "$cpufreq/boost" ] && [ -n "$boost" ] && [ "$boost" != - ]; then
    write "$boost" "$cpufreq/boost"
  fi

  local p name stock s_min s_max s_gov s_epp max min gov want_epp floor hw_max
  for p in "$cpufreq"/policy*; do
    [ -d "$p" ] || continue
    name=${p##*/}
    if ! stock=$(stock_policy "$name"); then
      warn "no stock values for $name; skipped"
      failed=1
      continue
    fi
    read -r s_min s_max s_gov s_epp <<<"$stock"

    min=$s_min
    if [ "$profile" = disabled ]; then
      max=$s_max gov=$s_gov want_epp=$s_epp
    else
      gov=powersave want_epp=$epp
      # cpuinfo_max_freq follows boost, so read it after the boost write.
      hw_max=$(read_file "$p/cpuinfo_max_freq" || echo "$s_max")
      if [ -z "$cap" ]; then
        max=$hw_max
      else
        floor=$(read_file "$p/amd_pstate_lowest_nonlinear_freq" || echo "$s_min")
        [ "$floor" -ge "$s_min" ] 2>/dev/null || floor=$s_min
        max=$cap
        [ "$max" -le "$hw_max" ] || max=$hw_max
        [ "$max" -ge "$floor" ] || max=$floor
      fi
    fi

    [ "$max" = - ] || write "$max" "$p/scaling_max_freq"
    [ "$min" = - ] || write "$min" "$p/scaling_min_freq"
    [ "$gov" = - ] || write "$gov" "$p/scaling_governor"
    # The performance governor pins EPP and rejects writes (EBUSY).
    if [ -n "$want_epp" ] && [ "$want_epp" != - ] && [ "$gov" != performance ]; then
      write "$want_epp" "$p/energy_performance_preference"
    fi
  done

  echo "cpu: boost=$(read_file "$cpufreq/boost" || echo -)" \
    "policy0 max=$(read_file "$cpufreq/policy0/scaling_max_freq" || echo -)" \
    "min=$(read_file "$cpufreq/policy0/scaling_min_freq" || echo -)" \
    "governor=$(read_file "$cpufreq/policy0/scaling_governor" || echo -)" \
    "epp=$(read_file "$cpufreq/policy0/energy_performance_preference" || echo -)"
}

is_watts() {
  [[ $1 =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

# Rounds watts down / up to whole watts so a limit stays inside the range.
watts_floor() {
  printf '%s' "${1%%.*}"
}

watts_ceil() {
  local int=${1%%.*} frac
  frac=${1#"$int"}
  frac=${frac#.}
  frac=${frac//0/}
  if [ -n "$frac" ]; then
    printf '%s' "$((int + 1))"
  else
    printf '%s' "$int"
  fi
}

# Drops trailing zeros: 200.00 -> 200, 180.50 -> 180.5.
watts_exact() {
  local value=$1
  if [[ $value == *.* ]]; then
    value=${value%"${value##*[!0]}"}
    value=${value%.}
  fi
  printf '%s' "$value"
}

apply_gpu() {
  local profile=$1 out tries=0
  [ -n "$nvidia_smi" ] || return 0

  # At boot the nvidia module loads from udev, possibly after this unit.
  until out=$("$nvidia_smi" --query-gpu=index,power.min_limit,power.default_limit,power.max_limit \
    --format=csv,noheader,nounits 2>&1); do
    tries=$((tries + 1))
    if [ "$tries" -ge "$gpu_wait" ]; then
      warn "nvidia-smi failed: $out"
      failed=1
      return 0
    fi
    sleep 1
  done

  local idx min def max target lo hi rows=0
  while IFS=',' read -r idx min def max; do
    idx=${idx// /} min=${min// /} def=${def// /} max=${max// /}
    # Skips anything nvidia-smi prints besides the CSV rows.
    [[ $idx =~ ^[0-9]+$ ]] || continue
    rows=$((rows + 1))
    if ! is_watts "$min" || ! is_watts "$def" || ! is_watts "$max"; then
      warn "gpu $idx: no power limit range ('$min' '$def' '$max'); skipped"
      failed=1
      continue
    fi
    case $profile in
      strict) target=$(watts_ceil "$min") ;;
      short-boosts)
        lo=$(watts_ceil "$min")
        hi=$(watts_floor "$def")
        target=$short_gpu_w
        [ "$target" -le "$hi" ] || target=$hi
        [ "$target" -ge "$lo" ] || target=$lo
        ;;
      full-power) target=$(watts_floor "$max") ;;
      full-speed-heavy | disabled) target=$(watts_exact "$def") ;;
    esac
    if ! "$nvidia_smi" -i "$idx" -pl "$target" </dev/null >/dev/null; then
      warn "gpu $idx: nvidia-smi -pl $target failed"
      failed=1
      continue
    fi
    echo "gpu $idx: power limit $target W (min $min, default $def, max $max)"
  done <<<"$out"
  if [ "$rows" -eq 0 ]; then
    warn "nvidia-smi listed no GPU: $out"
    failed=1
  fi
}

record_applied() {
  local tmp=$applied_file.tmp result=ok
  [ "$failed" -eq 0 ] || result=failed
  printf 'profile=%s\nresult=%s\n' "$1" "$result" >"$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$applied_file"
}

apply_profile() {
  local profile=$1
  echo "applying $profile"
  apply_cpu "$profile"
  apply_gpu "$profile"
  record_applied "$profile"
}

picked_profile() {
  local profile
  profile=$(read_kv "$state_file" profile)
  if ! valid_profile "$profile"; then
    [ -z "$profile" ] || warn "ignoring unknown profile in $state_file"
    profile=$default_profile
  fi
  printf '%s' "$profile"
}

cmd_apply() {
  [ $# -eq 1 ] || usage
  valid_profile "$1" || {
    warn "unknown profile '$1'"
    exit 2
  }
  lock
  save_stock
  apply_profile "$1"
}

# "Disabled" at boot means pure stock: nothing is written.
cmd_boot() {
  local profile
  lock
  save_stock
  profile=$(picked_profile)
  if [ "$profile" = disabled ]; then
    echo "profile disabled: leaving stock settings untouched"
    record_applied disabled
    return 0
  fi
  apply_profile "$profile"
}

# The GPU power limit resets on resume; CPU settings survive, re-writing them
# is harmless. Re-applies what was applied before sleep (a game's full power
# included), not just the picked profile.
cmd_resume() {
  local profile
  lock
  profile=$(read_kv "$applied_file" profile)
  if ! valid_profile "$profile"; then
    echo "nothing applied this boot; nothing to re-apply"
    return 0
  fi
  if [ "$profile" = disabled ]; then
    echo "profile disabled: nothing to re-apply"
    return 0
  fi
  save_stock
  apply_profile "$profile"
}

[ $# -ge 1 ] || usage
command=$1
shift
case $command in
  apply) cmd_apply "$@" ;;
  boot) cmd_boot "$@" ;;
  resume) cmd_resume "$@" ;;
  *) usage ;;
esac

exit "$failed"
