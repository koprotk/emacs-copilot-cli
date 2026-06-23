# Copilot Instructions

## Overview

This is a single-file Emacs Lisp package (`copilot-cli.el`) that integrates GitHub Copilot CLI into Emacs via an [Eat](https://codeberg.org/akib/emacs-eat) terminal buffer. It has no build system, test suite, or package manager.

## Architecture

The entire package lives in `copilot-cli.el`. It depends on:
- `eat` (external package, ≥0.9) — provides the terminal emulator
- `project` (Emacs built-in) — provides project root detection via `project-current`

Key design: each project gets its own named buffer (`*copilot-cli*<project-root>`), so sessions are isolated per project. `copilot-cli--buffer-name` constructs this name; `copilot-cli--find-buffer` locates it with a fallback to prefix matching (for `copilot-cli-stop`, which must work cross-project).

## Key conventions

- **Naming**: Public interactive commands are `copilot-cli` and `copilot-cli-stop`. Private helpers use the `copilot-cli--` double-dash prefix (e.g., `copilot-cli--project-root`, `copilot-cli--open-window`).
- **Customization**: User-facing variables are declared with `defcustom` under the `copilot-cli` group (`:prefix "copilot-cli-"`). Add new user options here, not as plain `defvar`.
- **Window management**: Window placement is delegated to `copilot-cli-window-function` (a `defcustom`). New window strategies belong in that function or in an override, not in `copilot-cli` itself.
- **No Evil integration**: This package intentionally does not touch Evil state. Terminal state handling is left to Eat / Evil user configuration.
- **Autoloads**: Interactive entry points are tagged `;;;###autoload` so package managers can lazy-load via `:commands`.
- **File footer**: must end with `(provide 'copilot-cli)` and `;;; copilot-cli.el ends here`.

## Package Metadata

The header block (`;; Package-Requires`, `;; Version`, etc.) must be kept accurate — it is machine-read by MELPA and `package.el`. Minimum Emacs version is `28.1`.
