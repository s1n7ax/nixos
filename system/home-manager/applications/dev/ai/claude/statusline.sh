input=$(cat)
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
model=$(printf '%s' "$input" | jq -r '.model.display_name // "?"')
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
[[ -n "$effort" ]] && model="$model ($effort)"

limit=""
read -r used resets < <(printf '%s' "$input" | jq -r '.rate_limits.five_hour | select(. != null) | "\(.used_percentage) \(.resets_at)"')
if [[ -n "$used" ]]; then
  left=$(awk -v u="$used" 'BEGIN{ l=100-u; if (l<0) l=0; printf "%.0f", l }')
  mins=$(( (resets - $(date +%s) + 59) / 60 ))
  (( mins < 0 )) && mins=0
  if (( mins < 60 )); then
    eta="${mins} min"
  else
    eta="$((mins / 60))h$((mins % 60))m"
  fi
  limit=" | session ${left}% left, resets $(date -d "@$resets" '+%-I:%M %p') (in ${eta})"
fi

fmt() {
  awk -v n="$1" 'BEGIN{
    if (n>=1e9) printf "%.2fB", n/1e9;
    else if (n>=1e6) printf "%.2fM", n/1e6;
    else if (n>=1e3) printf "%.1fK", n/1e3;
    else printf "%d", n;
  }'
}

if [[ -n "$transcript" && -f "$transcript" ]]; then
  read -r in_tot cache_c cache_r out_tot ctx_last < <(
    jq -rs '
      [.[] | select(.message.usage != null) | .message.usage] as $u
      | ($u | map(.input_tokens // 0) | add // 0) as $in
      | ($u | map(.cache_creation_input_tokens // 0) | add // 0) as $cc
      | ($u | map(.cache_read_input_tokens // 0) | add // 0) as $cr
      | ($u | map(.output_tokens // 0) | add // 0) as $out
      | ($u | last) as $l
      | (($l.input_tokens // 0) + ($l.cache_creation_input_tokens // 0) + ($l.cache_read_input_tokens // 0)) as $ctx
      | "\($in) \($cc) \($cr) \($out) \($ctx)"
    ' "$transcript" 2>/dev/null
  )
  : "${in_tot:=0}" "${cache_c:=0}" "${cache_r:=0}" "${out_tot:=0}" "${ctx_last:=0}"
  total=$((in_tot + cache_c + cache_r + out_tot))
  printf '%s | ctx %s | in %s | out %s | cache %s | total %s%s' \
    "$model" \
    "$(fmt "$ctx_last")" \
    "$(fmt "$in_tot")" \
    "$(fmt "$out_tot")" \
    "$(fmt $((cache_c + cache_r)))" \
    "$(fmt "$total")" \
    "$limit"
else
  printf '%s | ctx 0 | in 0 | out 0 | cache 0 | total 0%s' "$model" "$limit"
fi
