# Contributing

Thank you for helping build Waft. This guide covers the development setup,
the checks a change has to pass, and how code, commits, and pull requests are
shaped. Everyone participating agrees to the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug** with the bug report form. Include the macOS version, the
  mode, and the log lines around the problem.
- **Propose a feature** with the feature request form. Describe the problem
  before the solution.
- **Report a vulnerability** privately, as described in
  [SECURITY.md](SECURITY.md).
- **Send a pull request** for an open issue. Comment on the issue first for
  anything larger than a fix, so the approach is agreed before the work.

## Repository layout

| Path | What lives there |
| --- | --- |
| `Sources/WaftCore` | Domain types, rules, state machines, and every interface |
| `Sources/WaftSpeech` | The WhisperKit adapter |
| `Sources/WaftPlatform` | The macOS adapters |
| `Sources/WaftFeatures` | Observable models, the dictation flow, and the interface |
| `Sources/Waft` | The app and its composition root |
| `Packaging` | The Info.plist and the app icon |
| `scripts` | Bundling and signing the app |
| `docs` | Guides for users and the architecture |

[docs/architecture.md](docs/architecture.md) explains how the modules depend
on each other and where new code goes.

## Development setup

Prerequisites: macOS 14 or later on Apple silicon, the Command Line Tools for
Xcode 26 or later, or Xcode itself, and [Homebrew](https://brew.sh) for the
checks.

```sh
git clone https://github.com/okoflow/waft.git
cd waft

brew install swiftformat swiftlint periphery gitleaks shellcheck shfmt lefthook
make hooks
make signing
make run
```

`make hooks` installs a pre-commit hook that formats, lints, and scans the
staged files. `make signing` creates the Waft Dev code-signing identity in
your login keychain and asks for your password to trust it. Without it, every
build is signed ad hoc and macOS forgets the permissions you granted.

The everyday targets:

```sh
make run      # Build, sign, and open Waft
make bundle   # Build and sign build/Waft.app
make build    # Build every target
make check    # Run every check that CI runs
make format   # Format Swift, shell, and the property list
make clean    # Remove the build output
```

Targets build the debug configuration; add `CONFIG=release` for an optimized
build. `make help` lists every target.

## Checks

CI runs `make check` on every pull request. Run it before you push.

| Target | Tool | Fails on |
| --- | --- | --- |
| `format-check` | SwiftFormat, shfmt, plutil | Any formatting difference; `make format` fixes it |
| `lint` | SwiftLint, strict | Any violation, including comments in code |
| `build` | Swift 6 | Any warning, since warnings are errors |
| `periphery` | Periphery | Unused code |
| `secrets` | gitleaks | Secrets anywhere in the git history |
| `shellcheck` | ShellCheck | Problems in `scripts/*.sh`, with every optional check on |

Fix the code rather than the rule. A rule that is wrong for one line gets a
targeted `// swiftlint:disable:next <rule>` directive.

## Code guidelines

### Swift

- Dependencies point toward `WaftCore`. Interfaces live there; adapters
  for system frameworks go into `WaftPlatform` or `WaftSpeech`, and
  features receive them through `AppDependencies`. No singletons.
- Name things after what they are and do, following the
  [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
  Prefer a precise name to a comment.
- No comments in code. Names, types, and small functions carry the meaning;
  the `no_comments` lint rule enforces it.
- Separate the steps of a function with one blank line: the guards, the
  values it prepares, the work, and the result. A `return`, `throw`, `break`,
  or `continue` that does not open its scope gets a blank line before it,
  which the `blank_line_before_exit` lint rule checks, and so does the
  statement after an `await` that finishes a step. A report, such as a log
  line, stands apart from the work it reports on. Statements of one kind stay
  together: consecutive declarations, or the setup of one object.
- SwiftFormat orders declarations by kind, nested types, properties,
  initializers, then methods, and each kind from the most to the least
  visible.
- The package builds with the Command Line Tools alone, which lack Xcode's
  SwiftUI macro plugins. Keep view state in observable models instead of
  `@State`, declare environment values with an `EnvironmentKey` instead of
  `@Entry`, and do without `#Preview`. The `no_xcode_only_macros` lint rule
  catches them, since CI builds with Xcode and would accept them.
- Logs never contain dictated text or audio. Mark only identifiers, durations,
  and counts as public.
- User-facing text uses American English and sentence case for messages; menu
  items and buttons use title case.

### Shell

Scripts follow the
[Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html):
`set -euo pipefail`, a `main` function called with `"$@"`, functions for
every step, `readonly` constants, and errors on standard error through `die`.
shfmt formats them with two-space indents, and ShellCheck runs with every
optional check.

## Commits

Commits follow
[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):
`type(scope): description`.

- Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`,
  `chore`. Only `feat` and `fix` move the version.
- The scope is an area such as `core`, `speech`, `platform`, or `ui`, never a
  file name.
- The description is imperative and lowercase, under 72 characters, without
  a trailing period. It says what the change does, not what task it closes.
- A breaking change carries `!` before the colon and a `BREAKING CHANGE:`
  footer that says what a user must do.
- One commit is one logical change that builds and passes on its own. Add a
  body only for what the diff cannot show: the problem, the reason for the
  approach, a constraint. Footers such as `Fixes #12` go last.
- Commits credit people. Do not add generator or tooling trailers.

## Pull requests

- One pull request is one standalone change. Split anything above roughly
  400 changed lines unless the parts only make sense together.
- The title is the merge commit subject and follows the commit format. The
  body says what changed and why in a few sentences and names the risky
  spot. Add `Verified:` with the checks you ran and `Fixes #N` when it closes
  an issue.
- Attach a screenshot or a recording for visible changes.
- CI has to pass. Reviews focus on correctness, layering, and whether the
  change is the smallest one that solves the problem.

## Licensing of contributions

Waft is licensed under the [GNU General Public License v3.0](LICENSE). By
submitting a contribution, you agree that it is licensed under the same terms.
Add your name to [AUTHORS](AUTHORS) in your first pull request to be listed
among The Waft Authors.
