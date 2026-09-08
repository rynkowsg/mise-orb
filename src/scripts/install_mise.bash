#!/bin/bash

###
# Installs the mise binary into ~/.local/bin and puts that directory on PATH
# for the rest of the job.
#
# Example:
#
#   MISE_VERSION=v2026.9.2 ./src/scripts/install_mise.bash
#
###

# Bash Strict Mode Settings
set -euo pipefail

REQUESTED_VERSION="${PARAM_MISE_VERSION:-"${MISE_VERSION:-""}"}"

# The directory that goes on PATH. MISE_INSTALL_PATH, which the installer reads,
# is the binary inside it.
INSTALL_DIR="${HOME}/.local/bin"

# Where the installer comes from. mise documents installing itself with
# `curl https://mise.run | sh`, and that URL always serves the newest installer,
# so what runs can change under a job that pins a version. The copy attached to
# a release is fixed once published, and it carries that release's checksums
# inline instead of fetching SHASUMS256.txt. `latest/download` is a redirect
# GitHub serves, so taking the newest release needs no call to the API and no
# rate limit to worry about.
RELEASES_URL="https://github.com/jdx/mise/releases"

function installer_url {
  if [ -z "${REQUESTED_VERSION}" ]; then
    printf "%s/latest/download/install.sh" "${RELEASES_URL}"
  else
    # The tag carries a v the parameter may or may not have, so take it off and
    # put it back. That is also why the empty version is answered above: it
    # would come out as a bare "v".
    local normalized_version="v${REQUESTED_VERSION#"v"}"
    printf "%s/download/%s/install.sh" "${RELEASES_URL}" "${normalized_version}"
  fi
}

function main {
  # The installer reads MISE_VERSION. The pinned installer would install its own
  # version anyway, but saying it keeps the two from drifting apart.
  if [ -n "${REQUESTED_VERSION}" ]; then
    export MISE_VERSION="${REQUESTED_VERSION}"
  fi
  export MISE_INSTALL_PATH="${INSTALL_DIR}/mise"

  local url
  url="$(installer_url)"
  echo "Installing mise with ${url}"
  curl -fsSL "${url}" | sh

  # ${PATH} is escaped, so the line lands in BASH_ENV with it unexpanded and it
  # picks up whatever PATH a later step starts with.
  echo "export PATH=\"${INSTALL_DIR}:\${PATH}\"" >>"${BASH_ENV}"
  "${MISE_INSTALL_PATH}" --version
}

# shellcheck disable=SC2199
# to disable warning about concatenation of BASH_SOURCE[@].
# It is not a problem. This part of condition is only to prevent `unbound variable` error.
if [[ -n "${BASH_SOURCE[@]}" && "${BASH_SOURCE[0]}" != "${0}" ]]; then
  [[ -n "${BASH_SOURCE[0]}" ]] && printf "%s\n" "Loaded: ${BASH_SOURCE[0]}"
else
  main "$@"
fi
