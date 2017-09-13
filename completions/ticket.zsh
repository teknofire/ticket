if [[ ! -o interactive ]]; then
    return
fi

compctl -K _ticket ticket

_ticket() {
  local word words completions
  read -cA words
  word="${words[2]}"

  if [ "${#words}" -eq 2 ]; then
    completions="$(ticket commands)"
  else
    completions="$(ticket completions "${word}")"
  fi

  reply=("${(ps:\n:)completions}")
}
