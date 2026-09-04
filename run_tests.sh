#!/bin/sh

cd "$(dirname "$0")" || exit 1

lua -lluacov tests/run.lua || exit 1

awk 'NF == 4 && $1 ~ /^bj\// {
  printf "%-22s %s\n", $1, $4
  if ($3 != "0") {
    printf "  uncovered lines in %s\n", $1
    uncovered = 1
  }
}
END { exit uncovered }' luacov.report.out
