## corpus/retry.sh -- source it: `retry <cmd...>` runs a command up to 5 times,
## backing off 5, 10, 20, 40 s. For gh release calls, which GitHub answers
## with the odd 500/502.
retry() {
  local n=1 wait=5
  until "$@"; do
    if [ "$n" -ge 5 ]; then
      echo "failed after $n tries: $*" >&2
      return 1
    fi
    echo "try $n failed, again in ${wait}s: $*" >&2
    sleep "$wait"
    n=$((n + 1)); wait=$((wait * 2))
  done
}
