---
name: lang-swift
description: Use when writing or reviewing Swift (an *.xcodeproj or Package.swift), building or testing iOS apps, cleaning build output, or before asking for approval to merge a Swift PR.
---

# Swift rules

The global rules come first; this adds Swift detail and never overrides them.

- **Layout:** follow the repo's layout block (defined in your shared rules repo) once the repo has one.
- **Local build first:** never ask the owner to approve or merge a Swift pull request until the owner has confirmed a local build of it. Ask that first, as its own question (the owner built it, or not yet). Only after a yes, ask the approval question. If the branch changes after the owner built, ask again.
- **Old build output is the owner's to delete without asking:** the derived-data folders, result bundles, logs and test-simulator clones that the agent's own build and test runs created (the `<product>-ios-*` folders in the temp folder, or whatever the repo's runner names its own), and the `~/Library/Developer/XCTestDevices` clone set. This is the one narrow exception to the Safety rule's "ask before deleting".
- **Never delete:** source or project files, the owner's own simulators, Xcode's own DerivedData for the owner's builds, or anything a run of the agent's did not create.
- **Builds cover both devices at once:** build and test for the iPhone and the iPad in one run (the repo's runner does it), and replace the previous run's output with the new one.
