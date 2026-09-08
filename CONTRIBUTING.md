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

## Development

```bash
make orb/validate     # pack and validate the orb
make format           # format shell and YAML
make lint             # lint shell scripts
make test             # run the bats tests
make check            # everything above, in check mode
```

`make orb/validate` calls the CircleCI API, so it needs a token — `circleci auth
login`, or `CIRCLE_TOKEN` in the environment.

`make format` and `make lint` fetch their helpers with `sosh`, so
[sosh](https://github.com/rynkowsg/sosh) has to be on `PATH`.

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

3. **Update version in README.md and examples**

   Replace the previous orb version with `X.Y.Z` in `README.md` and all files under
   `src/examples/`:

   ```sh
   grep -r "rynkowsg/mise@" README.md src/examples/
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
after it is created. The branch label is the one to point `.circleci/config.yml`
at — pinning the sha there means moving it on every change to a command.

The branch label is skipped on a detached HEAD, and the `git describe` one in a
repository with no tags yet. A slash in a branch name becomes a dash.
