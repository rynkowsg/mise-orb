# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/)
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-09-09
### Added
- `setup` command — installs mise and the tools it manages, caches the installs,
  and puts the tools and the environment variables they declare on `PATH` for
  the rest of the job.
- `install_mise`, `cache_key_gen`, `cache_restore`, `install` and `cache_save`
  commands — the five steps `setup` runs, for a job that needs something in
  between.
- `cache_key` parameter on `setup`, `cache_restore` and `cache_save` — the cache
  key, defaulting to a checksum of the file `cache_key_gen` writes. Bump the
  version in it to start a new cache, or key the cache on something else and
  leave `cache_key_gen` out.
- `config_dir` parameter — the directory holding `mise.toml` and `mise.lock`,
  for a config that does not sit in the job's working directory.
- `data_dir` parameter — where mise installs tools. It is exported as
  `MISE_DATA_DIR`, so the directory the cache stores is the one mise installs
  into.
- bats tests for the cache key input, covering the lockfile slicing, the
  locked and unlocked modes, and the order-independence of the tool list.

[Unreleased]: https://example.com/compare/v0.1.0...HEAD
[0.1.0]: https://example.com/releases/tag/v0.1.0
