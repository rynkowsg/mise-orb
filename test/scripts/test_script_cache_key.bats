#!/usr/bin/env bats

###
# Bats script validating the cache key input built by src/scripts/cache_key.bash.
#
# The script prints the file it writes, so every check here reads its stdout.
# It reads mise.toml and mise.lock from the current directory, which is why
# setup() moves into the fixtures.
#
#   bats test/scripts/test_script_cache_key.bats
#
###

# detect ROOT_DIR - BEGIN
TEST_DIR="$(
  cd "$(dirname "${BATS_TEST_FILENAME}")" || exit 1
  pwd -P
)"
ROOT_DIR="$(
  cd "${TEST_DIR}/../.." || exit 1
  pwd -P
)"
# detect ROOT_DIR - end

SCRIPT="${ROOT_DIR}/src/scripts/cache_key.bash"
RES_DIR="${ROOT_DIR}/test/res"

setup() {
  cd "${RES_DIR}" || exit 1
}

# Runs the script and leaves its stdout in OUT.
#
# The helpers below read OUT rather than negating grep at the call site. Bash
# exempts a command negated with `!` from errexit, so a bare `! grep ...` in the
# middle of a test body never fails that test.
run_cache_key() {
  run env "$@" bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  OUT="${output}"
}

assert_match() {
  if ! grep -q "${1}" <<<"${OUT}"; then
    printf 'expected to find: %s\n' "${1}" >&2
    return 1
  fi
}

refute_match() {
  if grep -q "${1}" <<<"${OUT}"; then
    printf 'expected not to find: %s\n' "${1}" >&2
    return 1
  fi
}

@test "locked: keeps only the sections of the tools being installed" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="bats shellcheck"
  assert_match '^\[\[tools.bats\]\]$'
  assert_match '^\[\[tools.shellcheck\]\]$'
  refute_match '^\[\[tools.bat\]\]$'
  refute_match '^\[\[tools."node"\]\]$'
}

@test "locked: carries the version, url and checksum of a kept tool" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="bats"
  assert_match 'version = "1.14.0"'
  assert_match 'bats-1.14.0-linux-x64.tar.gz'
  assert_match '0000000000000000000000000000000000000000000000000000bats'
}

@test "locked: a shorter tool name does not match a longer one" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="bat"
  assert_match '^\[\[tools.bat\]\]$'
  refute_match '^\[\[tools.bats\]\]$'
  refute_match 'bats-1.14.0-linux-x64.tar.gz'
}

@test "locked: matches a tool whose name is quoted in the lockfile" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="node"
  assert_match '^\[\[tools."node"\]\]$'
  assert_match 'node-26.8.1-linux-x64.tar.gz'
  refute_match '^\[\[tools.bats\]\]$'
}

@test "locked: no tool list takes the whole lockfile" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS=""
  assert_match '^\[\[tools.bat\]\]$'
  assert_match '^\[\[tools.bats\]\]$'
  assert_match '^\[\[tools."node"\]\]$'
  assert_match '^\[\[tools.shellcheck\]\]$'
}

@test "unlocked: reads mise.toml instead of the lockfile" {
  run_cache_key PARAM_LOCKED=0 PARAM_TOOLS="bats"
  assert_match '^\[settings\]$'
  assert_match '^lockfile = true$'
  # mise.toml keeps every tool in one [tools] section, so nothing is sliced out
  assert_match '^bat = "0.25.0"$'
  refute_match 'linux-x64.tar.gz'
}

@test "the header records the mode and the tool list" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="shellcheck bats"
  assert_match '^locked=1$'
  assert_match '^tools=bats shellcheck$'
}

@test "the key input ignores the order and duplicates of the tool list" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="shellcheck bats"
  local first="${OUT}"

  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="bats   shellcheck bats"
  [ "${OUT}" = "${first}" ]
}

@test "a different tool subset produces a different key input" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="bats"
  local one="${OUT}"

  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="bats shellcheck"
  [ "${OUT}" != "${one}" ]
}

@test "locked and unlocked produce a different key input" {
  run_cache_key PARAM_LOCKED=1 PARAM_TOOLS="bats"
  local locked="${OUT}"

  run_cache_key PARAM_LOCKED=0 PARAM_TOOLS="bats"
  [ "${OUT}" != "${locked}" ]
}

@test "the key input is written to the file it is told to" {
  local target="${BATS_TEST_TMPDIR}/somewhere-else.txt"
  run env PARAM_CACHE_KEY_FILE="${target}" PARAM_LOCKED=1 PARAM_TOOLS="bats" bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ -f "${target}" ]
  OUT="$(cat "${target}")"
  assert_match '^locked=1$'
  assert_match '^\[\[tools.bats\]\]$'
}

@test "an unset locked value defaults to the lockfile" {
  run_cache_key PARAM_TOOLS="bats"
  assert_match '^locked=1$'
  assert_match 'bats-1.14.0-linux-x64.tar.gz'
}
