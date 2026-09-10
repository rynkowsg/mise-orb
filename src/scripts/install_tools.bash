#!/bin/bash

###
# Installs the tools mise manages and puts them on PATH for the rest of the job.
#
# Example:
#
#   LOCKED=1 TOOLS="babashka java" ./src/scripts/install_tools.bash
#
###

# Bash Strict Mode Settings
set -euo pipefail

TOOLS="${PARAM_TOOLS:-"${TOOLS:-""}"}"
# CircleCI renders a boolean parameter into the environment as 1 or 0. Only a
# plain 0 drops --locked, so any other value keeps the install on the lockfile
# instead of quietly falling back to the registry.
LOCKED="${PARAM_LOCKED:-"${LOCKED:-"1"}"}"
DATA_DIR="${PARAM_DATA_DIR:-"${DATA_DIR:-"~/.local/share/mise"}"}"

function main {
  # The parameter reaches the step as text, so a leading ~ is still a character
  # here. Expand it, because MISE_DATA_DIR has to be a real path.
  local data_dir="${DATA_DIR/#\~/${HOME}}"
  # The job's cache stores this directory, so mise has to install into it. Later
  # steps get it too, which keeps `mise ls` and any mise call of the user's own
  # looking at the same place.
  export MISE_DATA_DIR="${data_dir}"
  echo "export MISE_DATA_DIR=\"${data_dir}\"" >>"${BASH_ENV}"

  mise trust --yes

  local args
  if [ "${LOCKED}" != 0 ]; then
    args="--locked"
  else
    args=""
  fi

  # both expansions are meant to split into words
  # shellcheck disable=SC2086
  mise install --yes ${args} ${TOOLS}

  # Puts the tools on PATH for the rest of the job. CircleCI sources BASH_ENV
  # before every step, so this one line reaches every later step. It prepends the
  # shims directory, and a shim picks the tool version from the directory it runs
  # in - so a job with a second mise/install against another config gets the right
  # tool in each place.
  #
  # Not the hook that `mise activate` installs without --shims: that one
  # recomputes PATH in every shell sourcing BASH_ENV, including the bash children
  # a program starts, and so discards a PATH entry that program set up for them.
  # bats does exactly that for its helper scripts and breaks under it.
  #
  # Once is enough, however many times the command runs.
  local shims_line
  shims_line="$(mise activate --shims bash)"
  if ! grep -qxF "${shims_line}" "${BASH_ENV}"; then
    echo "${shims_line}" >>"${BASH_ENV}"
  fi

  # The env vars the tools declare, JAVA_HOME among them. Shims do not set those.
  # PATH is dropped: mise prints it as one absolute list, which would undo what
  # the shims line above is for.
  mise env -s bash | awk '!/^export PATH=/' >>"${BASH_ENV}"
}

# shellcheck disable=SC2199
# to disable warning about concatenation of BASH_SOURCE[@].
# It is not a problem. This part of condition is only to prevent `unbound variable` error.
if [[ -n "${BASH_SOURCE[@]}" && "${BASH_SOURCE[0]}" != "${0}" ]]; then
  [[ -n "${BASH_SOURCE[0]}" ]] && printf "%s\n" "Loaded: ${BASH_SOURCE[0]}"
else
  main "$@"
fi
