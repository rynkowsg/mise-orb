# Contributing

## Source layout

```
src/
  @orb.yml              # orb entry point
  commands/             # orb command definitions
  examples/             # usage examples shown in the orb registry
  scripts/              # shell scripts embedded via <<include(...)>>
test/
  res/                  # mise.toml and mise.lock fixtures the tests read
  scripts/              # bats tests for the scripts above
```

The fixtures under `test/res/` are a real config and lockfile, so a `mise` command
run from that directory picks them up. Tests never do that - they only run the
script under test with `test/res` as its working directory.

The scripts source no external shell library, so they go into the orb as they
are — there is no packing step and no `scripts_generated/` directory.

## Toolchain

The tools the checks need are pinned in `mise.toml` and locked in `mise.lock`:

```bash
mise trust
mise install
```

One thing stays outside that: the shell checks fetch their helpers with
[sosh](https://github.com/rynkowsg/sosh), so it has to be on `PATH`.

## Development

```bash
make            # list the targets
make check      # run every check and the tests
```

`make check` includes `make orb/validate`, which calls the CircleCI API, so it
needs a token — `circleci auth login`, or `CIRCLE_TOKEN` in the environment.

[direnv](https://direnv.net) is the recommended way to set it. The `.envrc` here
pulls in the one above it, so in the `orbs-rynkowsg` checkout a single
`.envrc.local` covers every orb. Read the value from a secret store instead of
writing it into the file:

```bash
export CIRCLE_TOKEN="$(pass show rynkowski/circleci/token)"
```

## CI

The pipeline runs in two halves, and they use two different versions of this orb.

`.circleci/config.yml` is the setup config: it runs the checks and installs their
toolchain with a **released** version, `rynkowsg/mise@X.Y.Z`. That is deliberate.
The checks are about the working tree, so what installs their tools should not
also come from it - otherwise a broken command would take the checks that would
have caught it down with it.

`.circleci/test-deploy.yml` is where the working tree is exercised. It declares
`mise: {}`, which resolves to the orb packed from the current commit, so the
integration jobs there run the commands as they are now. That is the half that
tells you whether a change to a command works.

The version in `config.yml` therefore lags one release behind the source, by
design. Move it forward as part of a release, together with the README and the
examples.

## Release Process

1. **Review unreleased changes**

   Compare the `[Unreleased]` section in `CHANGELOG.md` against actual commits since the last tag:

   ```sh
   git log $(git describe --tags --abbrev=0)..HEAD --oneline
   ```

   Add any notable changes that are missing from the `[Unreleased]` section.

2. **Update CHANGELOG.md**

   Move all entries from `[Unreleased]` into a new versioned section placed above it:

   ```markdown
   ## [Unreleased]

   [Unreleased]: https://github.com/rynkowsg/mise-orb/compare/vX.Y.Z..main

   ## [X.Y.Z](https://github.com/rynkowsg/mise-orb/commits/vX.Y.Z) (YYYY-MM-DD)

   - ...
   ```

   Also update the `[Unreleased]` comparison link to point to the new version.

3. **Update the version everywhere it is written down**

   Replace the previous orb version with `X.Y.Z` in `README.md`, in every file under
   `src/examples/`, and in `.circleci/config.yml`, which installs the check toolchain
   with the last released version:

   ```sh
   grep -rn "rynkowsg/mise@" README.md src/examples/ .circleci/config.yml
   ```

4. **Commit**

   ```sh
   git commit -m "chore: Bump to version X.Y.Z" --no-gpg-sign
   ```

5. **Tag**

   ```sh
   git tag -a vX.Y.Z -m "Version vX.Y.Z"
   ```

6. **Publish**

   ```sh
   @bin/publish.bash prod
   ```

   The version comes from the tag on `HEAD`, so this only publishes the commit that
   was tagged in the previous step, and it refuses anything else. Pushing the tag
   publishes it through CI as well — the script is the way to do it by hand.

## Publishing a dev version

```sh
@bin/publish.bash dev
```

Publishes the same artifact under every label worth reaching for it by:

| Label                | Moves | Good for                                   |
|----------------------|-------|--------------------------------------------|
| `dev:<sha>`          | never | pinning one exact build                    |
| `dev:<branch>`       | yes   | a reference that survives the next commit  |
| `dev:<git describe>` | yes   | reading which release the build sits after |

A dev version can be published again under the same label and expires 90 days
after it is created.

This is for trying a change out from another repository before it is released -
point that repository's config at `rynkowsg/mise@dev:<branch>` and it follows the
branch.

The branch label is skipped on a detached HEAD, and the `git describe` one in a
repository with no tags yet. A slash in a branch name becomes a dash.
