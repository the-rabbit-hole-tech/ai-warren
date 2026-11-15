A Python command-line tool installed as a console script, in the `src/` layout.

### Tree

```text
.
├── src/<package>/
│   ├── __init__.py       version and public names
│   ├── __main__.py       enables `python -m <package>`
│   ├── cli.py            argument parsing and command dispatch
│   ├── commands/         one module per command
│   │   └── <command>.py
│   ├── core/             the work itself, free of argv and printing
│   │   └── <module>.py
│   └── py.typed
├── tests/
│   ├── conftest.py
│   ├── test_cli.py       runs commands in-process and checks output
│   ├── test_<module>.py
│   └── data/             fixture files and expected output
├── pyproject.toml        [project.scripts] maps the command to cli:main
├── Taskfile.yml
└── README.md
```

### What goes where

- `cli.py`: parses arguments and calls a command; `main()` returns the exit code. No logic.
- `commands/`: one command each. It reads options, calls `core/`, and formats output.
- `core/`: the behaviour, testable without a subprocess. No `sys.exit`, no `print`; return values
  or raise typed exceptions.
- `__main__.py`: one line that calls `cli.main()`.

### Naming

- The console script is named for the repo (`kebab-case`); the import package is the same name in
  `snake_case`.
- Command modules are named for the command (`init.py`, `check.py`).
- Flags are `--kebab-case`; environment variables `<NAME>_<SETTING>` in upper case.
- Modules and functions `snake_case`; classes `PascalCase`.

### Tests, fixtures and generated code

- Tests live in `tests/`, mirroring the package, run with pytest.
- CLI tests call `main([...])` in-process and compare output with expected files in `tests/data/`.
- Generated modules, when any, go in `src/<package>/_generated/`, are committed and rebuilt by a
  Taskfile task. Build output is gitignored.
