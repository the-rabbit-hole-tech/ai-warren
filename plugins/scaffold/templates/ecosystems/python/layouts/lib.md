A Python package published to PyPI, in the `src/` layout.

### Tree

```text
.
├── src/<package>/
│   ├── __init__.py       the public API: re-exports and __all__
│   ├── py.typed          marks the package as typed
│   ├── <module>.py       one concept per module
│   └── _<private>.py     internals, not part of the API
├── tests/
│   ├── conftest.py       shared fixtures
│   ├── test_<module>.py
│   └── data/             fixture files
├── docs/                 optional user docs
├── pyproject.toml        metadata, build backend, ruff, pytest and mypy config
├── Taskfile.yml
└── README.md
```

### What goes where

- `src/<package>/`: everything that ships. The `src/` layout means tests import the installed
  package, not the working tree.
- `__init__.py`: the public names, listed in `__all__`. No heavy import-time work.
- `_<private>.py`: helpers users should not import. A leading underscore marks anything private.
- `tests/`: never shipped; excluded from the wheel.
- All config lives in `pyproject.toml`: no `setup.py`, `setup.cfg` or separate tool config files.

### Naming

- Distribution name (on PyPI): the repo name in `kebab-case`. Import name: the same in
  `snake_case`.
- Modules and functions are `snake_case`; classes `PascalCase`; constants `UPPER_SNAKE_CASE`.
- Public functions and classes carry type hints; `mypy --strict` passes.

### Tests, fixtures and generated code

- Tests live in `tests/`, mirroring the package (`tests/test_<module>.py`), run with pytest.
- Shared fixtures go in `tests/conftest.py`; fixture files in `tests/data/`.
- Tests that need a real service are marked `@pytest.mark.integration` and skipped by default.
- Generated modules, when any, go in `src/<package>/_generated/`, are committed and rebuilt by a
  Taskfile task. Build output (`dist/`, `*.egg-info`, `.venv/`) is gitignored.
