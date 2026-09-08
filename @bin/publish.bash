#!/usr/bin/env bash

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
# Packs, validates and publishes the orb.
#
# Example:
#
#  - dev:   @bin/publish.bash dev    # dev labels, republishable, expire in 90 days
#  - prod:  @bin/publish.bash prod   # X.Y.Z, taken from the tag on HEAD, immutable
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Bash Strict Mode Settings
set -euo pipefail
# Path Initialization
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P || exit 1)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd -P || exit 1)"

ORB_NAME="rynkowsg/mise"

# Runs a command, echoing it first (prefixed with "+") with any values listed in
# the newline-separated RUN_MASK_VALUES replaced by "XXX" in the printed form.
#
# The echo goes to stderr, where `set -x` puts its trace too. On stdout it would
# land inside the file of any command the caller redirects - `orb pack` here.
run() {
  local arg printed secret
  local -a secrets=()
  if [[ -n "${RUN_MASK_VALUES:-}" ]]; then
    mapfile -t secrets <<<"${RUN_MASK_VALUES}"
  fi
  printf '+' >&2
  for arg in "$@"; do
    printed="${arg}"
    for secret in "${secrets[@]}"; do
      [[ -n "${secret}" ]] || continue
      printed="${printed//"${secret}"/XXX}"
    done
    printf ' %q' "${printed}" >&2
  done
  printf '\n' >&2
  "$@"
}

# The version a release goes out under. It comes from a tag on HEAD itself:
# anything looser publishes a release from a commit nobody marked as one, and an
# orb version cannot be taken back. `git tag --points-at` returns nothing rather
# than failing, and the pattern is the one CI releases on, so both agree on what
# counts as a release.
prod_version() {
  local version
  version="$(git tag --points-at HEAD | sed -n 's/^v\([0-9]\+\.[0-9]\+\.[0-9]\+\)$/\1/p' | head -1)"
  if [ -z "${version}" ]; then
    echo "publish.bash: HEAD has no vX.Y.Z tag, so there is no release to publish." >&2
    echo "  Tag the commit first:  git tag -a v0.1.0 -m 'Version v0.1.0'" >&2
    return 1
  fi
  printf "%s" "${version}"
}

# A release goes out under one version, and an untagged commit has none - which
# stops the publish here, before anything reaches the registry.
publish_prod() {
  local version
  version="$(prod_version)"
  run circleci orb publish dist/orb.yml "${ORB_NAME}@${version}"
}

# A dev label can be published again, so the same artifact goes out under every
# name worth reaching for it by.
publish_dev() {
  # 1. Publish under dev:SHA
  #    Pins one exact build.
  run circleci orb publish dist/orb.yml "${ORB_NAME}@dev:$(git rev-parse HEAD)"

  # 2. Publish under dev:BRANCH_NAME
  #    A reference that outlives this commit - point a config here.
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  # A detached HEAD has no branch name, git answers "HEAD", and a slash in the
  # name would run into the namespace separator, so it becomes a dash.
  if [ "${branch}" != "HEAD" ]; then
    run circleci orb publish dist/orb.yml "${ORB_NAME}@dev:${branch//\//-}"
  fi

  # 3. Publish under dev:GIT_DESCRIBE
  #    The release this build sits after, and the distance from it.
  local described
  # `git describe` fails outright in a repository with no tags yet, so the error
  # is swallowed. The v the tags carry goes too, so the label reads like the
  # version a release goes out under - the sed takes a v only in front of an
  # X.Y.Z, so a tag that is not a release version, "verify-fix" or "v1", keeps
  # its name whole.
  described="$(git describe --tags 2>/dev/null | sed 's/^v\([0-9]\+\.[0-9]\+\.[0-9]\+\)/\1/' || true)"
  # No tags, no label - which is no reason to fail the publish.
  if [ -n "${described}" ]; then
    run circleci orb publish dist/orb.yml "${ORB_NAME}@dev:${described}"
  fi
}

main() {
  local stage="${1:-"dev"}"
  case "${stage}" in
    dev | prod) ;;
    *)
      echo "publish.bash: unknown stage '${stage}'" >&2
      echo "  usage: @bin/publish.bash [dev|prod]" >&2
      return 1
      ;;
  esac

  cd "${ROOT_DIR}"
  rm -rf dist/
  mkdir -p dist

  run circleci orb pack src >dist/orb.yml
  run circleci orb validate dist/orb.yml

  if [ "${stage}" = "prod" ]; then
    publish_prod
  else
    publish_dev
  fi
}

main "$@"
