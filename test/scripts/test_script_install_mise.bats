#!/usr/bin/env bats

###
# Bats script validating the installer URL built by src/scripts/install_mise.bash.
#
# The script only runs main when it is executed, so sourcing it here gets the
# functions without installing anything.
#
#   bats test/scripts/test_script_install_mise.bats
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

SCRIPT="${ROOT_DIR}/src/scripts/install_mise.bash"
RELEASES="https://github.com/jdx/mise/releases"

# Sources the script with the given environment and leaves installer_url's
# answer in OUT.
url_for() {
  run env "$@" bash -c "source '${SCRIPT}' >/dev/null; installer_url"
  [ "${status}" -eq 0 ]
  OUT="${output}"
}

@test "no version asked for takes the latest release" {
  url_for PARAM_MISE_VERSION=""
  [ "${OUT}" = "${RELEASES}/latest/download/install.sh" ]
}

@test "a version with the v it is documented with" {
  url_for PARAM_MISE_VERSION="v2026.9.2"
  [ "${OUT}" = "${RELEASES}/download/v2026.9.2/install.sh" ]
}

@test "a version without the v lands on the same URL" {
  url_for PARAM_MISE_VERSION="2026.9.2"
  [ "${OUT}" = "${RELEASES}/download/v2026.9.2/install.sh" ]
}

@test "MISE_VERSION is taken when the step passes no parameter" {
  url_for MISE_VERSION="v2026.9.2"
  [ "${OUT}" = "${RELEASES}/download/v2026.9.2/install.sh" ]
}

@test "the parameter wins over MISE_VERSION" {
  url_for PARAM_MISE_VERSION="v2026.9.3" MISE_VERSION="v2026.9.2"
  [ "${OUT}" = "${RELEASES}/download/v2026.9.3/install.sh" ]
}
