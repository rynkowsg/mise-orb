#!/bin/bash

###
# Writes the file that restore_cache and save_cache checksum.
#
# One path covers both the locked and the unlocked case - what changes is the
# content of the file, not the key template. The mode and the tool list go into
# the file too, so two jobs installing different subsets of the same lockfile
# get different keys.
#
# The config is read from the current directory, which is the same place mise
# reads it from when it installs. Point both at another directory with the
# step's working_directory.
#
# Example:
#
#   LOCKED=1 TOOLS="babashka java" ./src/scripts/cache_key.bash
#
###

# Bash Strict Mode Settings
set -euo pipefail

TOOLS="${PARAM_TOOLS:-"${TOOLS:-""}"}"
# CircleCI renders a boolean parameter into the environment as 1 or 0. Only a
# plain 0 turns the lockfile off, so any other value keeps the locked path and
# the key gets built from the lockfile.
LOCKED="${PARAM_LOCKED:-"${LOCKED:-"1"}"}"

# mise looks for these names in the current directory and the ones above it, so
# the names are fixed and the directory is what moves.
CONFIG_FILE="mise.toml"
LOCKFILE="mise.lock"

# Where the key input is written. Whoever changes it has to point the cache key
# of cache_restore and cache_save at the same file.
CACHE_KEY_FILE="${PARAM_CACHE_KEY_FILE:-"${CACHE_KEY_FILE:-"/tmp/mise-cache-key.txt"}"}"

function main {
  # one tool per line, sorted and deduplicated, so the key does not
  # depend on the order the tools were listed in
  local tools
  tools="$(printf '%s\n' "${TOOLS}" | tr -s '[:space:]' '\n' | sed '/^$/d' | sort -u)"

  local src_file
  if [ "${LOCKED}" != 0 ]; then
    src_file="${LOCKFILE}"
  else
    src_file="${CONFIG_FILE}"
  fi

  # The mode and the tool list are part of the key input too. Two jobs
  # installing a different subset of the same lockfile must not share
  # a cache entry.
  {
    echo "locked=${LOCKED}"
    echo "tools=$(printf '%s' "${tools}" | tr '\n' ' ')"
  } >"${CACHE_KEY_FILE}"

  if [ "${LOCKED}" != 0 ] && [ -n "${tools}" ]; then
    # Take only the lockfile sections of the tools being installed, so a
    # version bump of a tool this job does not install leaves the cache
    # alone. A section starts at a [tools.<name>...] or [[tools.<name>]]
    # header and runs to the next header, so the keep flag carries the
    # version, url and checksum lines with it. The name boundary []". is
    # what keeps a query for `bat` off `bats`.
    local names
    names="$(printf '%s' "${tools}" | tr '\n' '|')"
    awk -v names="${names}" '
      /^\[/ { keep = ($0 ~ ("^\\[+tools\\.\"?(" names ")[]\".]")) }
      keep
    ' "${src_file}" >>"${CACHE_KEY_FILE}"
  else
    # With no tool list there is nothing to narrow down to. mise.toml
    # also keeps every tool in one [tools] section, so the per-section
    # slicing above does not apply to it.
    cat "${src_file}" >>"${CACHE_KEY_FILE}"
  fi

  cat "${CACHE_KEY_FILE}"
}

# shellcheck disable=SC2199
# to disable warning about concatenation of BASH_SOURCE[@].
# It is not a problem. This part of condition is only to prevent `unbound variable` error.
if [[ -n "${BASH_SOURCE[@]}" && "${BASH_SOURCE[0]}" != "${0}" ]]; then
  [[ -n "${BASH_SOURCE[0]}" ]] && printf "%s\n" "Loaded: ${BASH_SOURCE[0]}"
else
  main "$@"
fi
