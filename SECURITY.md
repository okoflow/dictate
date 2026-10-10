# Security Policy

Dictate records your voice, reads the focused text field through
Accessibility, writes to the clipboard, and keeps API keys in the Keychain.
Security reports are taken seriously and handled privately until a fix is
available.

## Supported versions

| Version | Supported |
| --- | --- |
| `main` | Yes |
| Older commits | No, update to `main` |

## Reporting a vulnerability

Report vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/okoflow/dictate/security/advisories/new).
Do not open a public issue, pull request, or discussion for a security problem.

Include what helps reproduce and assess the issue:

- the commit and the macOS version
- steps to reproduce, or a proof of concept
- the impact you expect

You receive an acknowledgement within three business days and a triage
decision within seven. Fixes ship with a security advisory that credits the
reporter unless they prefer otherwise. Please keep the report private until
the advisory is published.

## Scope

In scope: everything in this repository, including the app, the scripts, and
the build configuration. Of particular interest:

- audio, or text outside the cloud modes, leaving the Mac
- text pasted into a password field, or into another app than the one you
  dictated into
- an API key leaving the Keychain for anything other than its provider's API
- dictated text or clipboard contents reaching the logs, the disk, or other
  apps
- the event tap or the Accessibility access used beyond what dictation needs

Out of scope: vulnerabilities in WhisperKit, the speech model, or macOS unless
Dictate's use of them causes the problem; attacks that need an already
compromised user account; the Dictate Dev identity that `make signing`
creates for local builds.

## Dependencies

Dictate has one direct dependency, WhisperKit, pinned to an exact version in
`Package.swift`, with every resolved package recorded in `Package.resolved`.
Dependabot watches it and the GitHub Actions.
