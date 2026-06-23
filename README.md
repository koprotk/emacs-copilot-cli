# copilot-cli.el

Launch [GitHub Copilot CLI](https://github.com/github/copilot-cli) inside Emacs using an [Eat](https://codeberg.org/akib/emacs-eat) terminal buffer.

Running `M-x copilot-cli` splits your frame vertically (side by side) and opens a full terminal session rooted at your project directory — no context-switching required.

## Requirements

- Emacs 28.1+
- [eat](https://codeberg.org/akib/emacs-eat) 0.9+
- [copilot-cli](https://github.com/github/copilot-cli) installed and available in your `PATH`

## Installation

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-copilot-cli")
(require 'copilot-cli)
```

### use-package (with straight.el)

```elisp
(use-package copilot-cli
  :straight (:host github :repo "koprotk/emacs-copilot-cli")
  :commands (copilot-cli copilot-cli-stop))
```

### Doom Emacs

In `packages.el`:

```elisp
(package! copilot-cli
  :recipe (:host github :repo "koprotk/emacs-copilot-cli"))
```

In `config.el`:

```elisp
(use-package! copilot-cli
  :commands (copilot-cli copilot-cli-stop))
```

## Usage

| Command           | Description                                      |
|-------------------|--------------------------------------------------|
| `M-x copilot-cli` | Start or switch to the Copilot CLI session       |
| `M-x copilot-cli-stop` | Stop the session and close its window       |

If a session is already running, `copilot-cli` switches to the existing buffer instead of starting a new one.

`copilot-cli-stop` gracefully shuts the CLI down by sending `/exit` and waits up to `copilot-cli-exit-timeout` seconds before force-killing. It works from any buffer or project: if the current buffer is a Copilot CLI session it acts on that one; otherwise it falls back to the current project's session, the only running session, or prompts when several are active.

### Keybinding examples

Bind it to whatever feels natural:

```elisp
;; Vanilla Emacs
(global-set-key (kbd "C-c c") #'copilot-cli)

;; Evil / Doom / Spacemacs leader key
(map! :leader :desc "Copilot CLI" "o c" #'copilot-cli)
```

## Customization

All options live under `M-x customize-group RET copilot-cli`:

| Variable                      | Default                    | Description                              |
|-------------------------------|----------------------------|------------------------------------------|
| `copilot-cli-program`         | `"copilot"`                | The executable to run                    |
| `copilot-cli-buffer-name`     | `"*copilot-cli*"`          | Name of the terminal buffer              |
| `copilot-cli-window-function` | `copilot-cli--open-window` | Function that opens the target window    |
| `copilot-cli-exit-command`    | `"/exit\\n"`               | String sent to gracefully shut down CLI  |
| `copilot-cli-exit-timeout`    | `3.0`                      | Seconds to wait before force-killing     |

Example — use a different CLI command:

```elisp
(setq copilot-cli-program "gh copilot")
```

### Doom Emacs — side window

Replace the default right-split with a Doom-managed side window:

```elisp
(setq copilot-cli-window-function
      (lambda ()
        (select-window
         (display-buffer-in-side-window
          (current-buffer) '((side . right) (window-width . 0.4))))))
```

Or use Doom's popup system:

```elisp
(after! copilot-cli
  (set-popup-rule! "^\\*copilot-cli\\*" :side 'right :width 0.4 :quit nil :ttl nil))
```

### Evil-mode

This package does not change your Evil state.  Eat ships its own
integration with Evil; configure terminal-mode state through Eat or
Evil directly (e.g., `eat-eshell-visual-command-mode`, `evil-set-initial-state`).

## How it works

1. Detects the project root via Emacs's built-in `project.el`.
2. Opens a window using `copilot-cli-window-function` (default: vertical split).
3. Launches an Eat terminal running `copilot-cli-program` in that root, using a project-specific buffer name (e.g., `*copilot-cli*</path/to/project/>`).
4. Reuses the existing session if one is already alive for the current project.
5. On stop, sends `copilot-cli-exit-command` to let the CLI shut down cleanly, then closes the window and kills the buffer when the process exits (force-killing after `copilot-cli-exit-timeout` seconds if needed).

## License

GPL-3.0-or-later
