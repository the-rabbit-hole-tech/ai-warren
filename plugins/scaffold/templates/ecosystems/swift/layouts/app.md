An iOS or iPadOS app: an Xcode project for the app target, with the code that can stand alone split
into local Swift packages.

### Tree

```text
.
├── <App>.xcodeproj           the Xcode project; the shared scheme is checked in
├── App/
│   ├── <App>App.swift        the @main entry point
│   ├── Shell/                navigation, tab bar and the root views
│   ├── Features/<name>/      a feature's views, model and service protocol together
│   ├── Services/             concrete service implementations behind the feature protocols
│   └── Resources/            asset catalogs, string catalogs, Info.plist keys
├── Packages/<Name>/          local Swift packages the app depends on
│   ├── Package.swift
│   ├── Sources/<Name>/
│   └── Tests/<Name>Tests/
├── Tests/                    unit tests for the app target (Swift Testing)
├── UITests/                  UI tests (XCUIAutomation)
├── docs/
├── .swiftlint.yml
├── .swiftformat
└── Taskfile.yaml
```

### What goes where

- `App/Features/<name>/`: everything one feature owns. Move a piece to a package once a second
  feature needs it.
- Views hold no logic: they read an `@Observable` model, and the model talks to a service
  protocol.
- `Services/`: the real implementations of the protocols. Anything that touches the system
  (Keychain, the network, the microphone, notifications) sits behind a protocol of the app's own
  so tests can fake it.
- `Packages/<Name>/`: product-neutral code with one job each. A package never imports the app
  target.
- The app target stays thin: wiring, features and resources.
- Build settings, bundle identifier and signing live in the Xcode project and its `.xcconfig`
  files, never in code.

### Naming

- Types and files are `UpperCamelCase`, one primary type per file, the file named for the type.
- Folders are `UpperCamelCase`; packages and their targets are `UpperCamelCase`.
- Feature models end in `Model`, service protocols in `Service`, test files in `Tests`.
- Swift 6 language mode with strict concurrency; view models are `@MainActor`.

### Tests, fixtures and generated code

- Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`) and live in `Tests/` or the
  package's own `Tests/`. XCTest is only for UI tests in `UITests/`.
- Fakes and fixtures sit beside the tests that use them, in a `Fixtures/` folder; no real
  addresses or credentials.
- Generated code is committed, carries a "do not edit" header and lives in a `Generated/` folder
  of its target. Never edit it by hand.
- `DerivedData/` and `.build/` are gitignored.
