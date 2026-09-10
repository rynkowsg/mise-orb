# [`rynkowsg/mise`][orb-page] orb

[![CircleCI Build Status][ci-build-badge]][ci-build]
[![CircleCI Orb Version][orb-version-badge]][orb-page]
[![License][license-badge]][license]
[![CircleCI Community][orbs-discuss-badge]][orbs-discuss]

Installs [mise](https://mise.jdx.dev/) and the tools it manages in a CircleCI
job. The installs are cached between jobs, and the tools, together with the
environment variables they declare, are put on `PATH` for the rest of the job
through `BASH_ENV`.

For the full orb reference, see the [orb registry listing][orb-page].

## Commands

| Command         | Description                                                |
|-----------------|------------------------------------------------------------|
| `setup`         | The five below, in the order they have to run. Start here. |
| `install_mise`  | Installs the mise binary and puts it on `PATH`             |
| `cache_key_gen` | Writes the file the default cache key checksums            |
| `cache_restore` | Restores the cache of installed tools                      |
| `install`       | Installs the tools mise manages and puts them on `PATH`    |
| `cache_save`    | Saves the cache of installed tools                         |

Reach past `setup` when a job needs a step in between — a build before the cache
is saved, say. `cache_restore` and `cache_save` take a `cache_key`, so the cache
can be keyed on whatever you like; the default checksums what `cache_key_gen`
writes.

## Quickstart

### Every tool from `mise.toml`

```yaml
version: '2.1'

orbs:
  mise: rynkowsg/mise@0.1.0

jobs:
  build:
    docker: [{image: "cimg/base:current"}]
    steps:
      - checkout
      - mise/setup
      - run: make test

workflows:
  main-workflow:
    jobs:
      - build
```

### Only the tools a job needs

A repository's `mise.toml` usually lists more tools than any single job uses.
Naming them in `tools` keeps the job from installing the rest, and it keeps the
cache entry to those tools — a version bump of a tool this job does not install
leaves its cache alone.

CircleCI has no list parameter, so the tools go in one string:

```yaml
      - mise/setup: {tools: shellcheck shfmt yamlfmt}
```

<details>
<summary>A longer list, over several lines</summary>

A YAML folded scalar (`>-`) is the way to write a longer list over several
lines. It joins them back into a single line separated by spaces:

```yaml
      - mise/setup:
          tools: >-
            shellcheck
            shfmt
            yamlfmt
```

</details>

### Pinning mise itself

`mise.lock` pins every tool, but not mise. Left alone, `mise_version` installs
the latest release, which is what the examples above do. Name a version when the
job has to be reproducible — mise is the one link in the chain the lockfile does
not cover:

```yaml
      - mise/setup: {mise_version: v2026.9.2}
```

### `setup` parameters

Each of the five commands takes the subset that applies to it — `install_mise`
takes `mise_version`, `cache_key_gen` takes `tools`, and so on.

| Parameter      | Default               | Description                                                             |
|----------------|-----------------------|-------------------------------------------------------------------------|
| `install_mise` | `true`                | Download the mise binary first. Off on an image that already ships it.  |
| `mise_version` | `""`                  | Version of mise to install. Empty installs the latest release.          |
| `locked`       | `true`                | Resolve every tool from the lockfile, so the install calls no registry. |
| `config_dir`   | `""`                  | Directory holding `mise.toml`. Empty uses the job's working directory.  |
| `data_dir`     | `~/.local/share/mise` | Where mise installs tools. Exported as `MISE_DATA_DIR`.                 |
| `tools`        | `""`                  | Whitespace-separated tools to install. Empty installs everything.       |

`locked` also picks the file the cache key is built from — `mise.lock` when
true, `mise.toml` when false.

### More than one `mise.toml`

`config_dir` points the command at a config outside the repository root:

```yaml
      - mise/setup: {config_dir: build, tools: shellcheck}
```

The tools land on `PATH` through mise's shims directory, which every step picks
up when it sources `BASH_ENV`. A shim resolves the version from the directory it
runs in, so a job using two configs gets the right tool in each place, and mise
merges a nested config with the ones above it. A step running where no config is
reachable fails loudly (`No version is set for shim: <tool>`) — give such a step
the same `working_directory` you gave `config_dir`.

### Two configs, one cache

`setup` restores and saves a cache entry per call, so a job installing from two
configs ends up with two. Both installs write into the same `data_dir` anyway,
which leaves the second entry holding more than its key describes.

Calling the commands apart restores once and saves once, around both installs.
The key checksums both lockfiles, so it describes exactly what the entry holds:

```yaml
      - mise/install_mise
      - mise/cache_restore:
          cache_key: &key 'mise-v1-{{ arch }}-{{ checksum "mise.lock" }}-{{ checksum "build/mise.lock" }}'
      - mise/install: {tools: babashka java}
      - mise/install: {config_dir: build, tools: shellcheck}
      - mise/cache_save: {cache_key: *key}
      - run: make test
```

`cache_key_gen` reads one config, so it has no part here — which is what the
`cache_key` parameter is for.

### A cache key of your own

`cache_restore` and `cache_save` take a `cache_key`, defaulting to
`mise-v1-{{ arch }}-{{ checksum "/tmp/mise-cache-key.txt" }}` — the file
`cache_key_gen` writes. Bump the version in it to start a new cache, or key the
cache on something else entirely and drop `cache_key_gen`:

```yaml
      - mise/setup:
          tools: shellcheck
          cache_key: 'mise-v2-{{ arch }}-{{ checksum "mise.lock" }}'
```

`setup` passes one value to the restore and the save. Calling those two apart,
give them the same key — the restore reads back what the save wrote.

`restore_cache` also takes a list of keys, for fallbacks. Orb parameters have no
list type, so write your own `restore_cache` step for that; `cache_key_gen` still
gives you the file to checksum.

## `rynkowsg/` orb family

| Name                                                            | Description                                                                                       |
|-----------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| [`rynkowsg/asdf`](https://github.com/rynkowsg/asdf-orb)         | Orb providing support for ASDF                                                                    |
| [`rynkowsg/aws`](https://github.com/rynkowsg/aws-orb)           | Commands for working with AWS credentials                                                         |
| [`rynkowsg/checkout`](https://github.com/rynkowsg/checkout-orb) | Advanced checkout with support of LFS, submodules, custom SSH identities, shallow clones and more |
| [`rynkowsg/gpg`](https://github.com/rynkowsg/gpg-orb)           | Sets up GPG                                                                                       |
| [`rynkowsg/mise`](https://github.com/rynkowsg/mise-orb)         | Installs mise and the tools it manages                                                            |
| [`rynkowsg/rynkowsg`](https://github.com/rynkowsg/rynkowsg-orb) | Orb with no particular theme, used primarily for prototyping                                      |

## License

Copyright © 2026 Greg Rynkowski (https://rynkowski.pl)

Use is permitted solely for executing CircleCI workflows; all other rights are
reserved. See the [LICENSE][license] file for details.

[ci-build-badge]: https://circleci.com/gh/rynkowsg/mise-orb.svg?style=shield "CircleCI Build Status"
[ci-build]: https://circleci.com/gh/rynkowsg/mise-orb
[license-badge]: https://img.shields.io/badge/license-proprietary-lightgrey.svg
[license]: https://raw.githubusercontent.com/rynkowsg/mise-orb/main/LICENSE
[orb-page]: https://circleci.com/developer/orbs/orb/rynkowsg/mise
[orb-version-badge]: https://badges.circleci.com/orbs/rynkowsg/mise.svg
[orbs-discuss-badge]: https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg
[orbs-discuss]: https://discuss.circleci.com/c/ecosystem/orbs
