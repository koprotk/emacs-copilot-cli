;;; copilot-cli.el --- Launch Copilot CLI in an Eat terminal -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Daniel Munoz

;; Author: Daniel Munoz
;; Version: 0.2.0
;; Package-Requires: ((emacs "28.1") (eat "0.9"))
;; Keywords: tools, terminals
;; URL: https://github.com/koprotk/emacs-copilot-cli

;;; Commentary:

;; This package provides a convenient way to launch GitHub Copilot CLI
;; inside an Eat terminal buffer.  Running `M-x copilot-cli' splits the
;; frame vertically (side by side) and opens an Eat terminal running
;; the `copilot-cli' command in the current project's root directory.
;;
;; Usage:
;;
;;   M-x copilot-cli      Start or switch to the Copilot CLI session.
;;   M-x copilot-cli-stop Stop the running session and close its window.
;;
;; Customization:
;;
;;   `copilot-cli-program'         The executable to run (default: "copilot").
;;   `copilot-cli-buffer-name'     The buffer name (default: "*copilot-cli*").
;;   `copilot-cli-window-function' How to open and select the terminal window.

;;; Code:

(require 'eat)
(require 'project)
(require 'seq)

(defgroup copilot-cli nil
  "Launch Copilot CLI in an Eat terminal."
  :group 'tools
  :prefix "copilot-cli-")

(defcustom copilot-cli-program "copilot"
  "The command used to start Copilot CLI."
  :type 'string
  :group 'copilot-cli)

(defcustom copilot-cli-buffer-name "*copilot-cli*"
  "Name of the Copilot CLI terminal buffer."
  :type 'string
  :group 'copilot-cli)

(defcustom copilot-cli-window-function #'copilot-cli--open-window
  "Function called to open and select the window for a new Copilot CLI session.
It should leave the desired target window as the selected window.
Override this to control window placement.  For example, for a Doom
Emacs side window:

  (setq copilot-cli-window-function
        (lambda ()
          (select-window
           (display-buffer-in-side-window
            (current-buffer) \\='((side . right) (window-width . 0.4))))))"
  :type 'function
  :group 'copilot-cli)

(defcustom copilot-cli-exit-command "/exit\n"
  "String sent to Copilot CLI to request a graceful shutdown."
  :type 'string
  :group 'copilot-cli)

(defcustom copilot-cli-exit-timeout 3.0
  "Seconds to wait for Copilot CLI to exit gracefully before force-killing."
  :type 'number
  :group 'copilot-cli)

(defun copilot-cli--open-window ()
  "Split the frame to the right and select the new window."
  (split-window-right)
  (other-window 1))

(defvar copilot-cli--buffers nil
  "List of live buffers started by `copilot-cli'.")

(defun copilot-cli--register-buffer (buf)
  "Track BUF as a Copilot CLI buffer and arrange for cleanup on kill."
  (unless (memq buf copilot-cli--buffers)
    (push buf copilot-cli--buffers))
  (with-current-buffer buf
    (add-hook 'kill-buffer-hook #'copilot-cli--unregister-buffer nil t)))

(defun copilot-cli--unregister-buffer ()
  "Remove the current buffer from `copilot-cli--buffers'."
  (setq copilot-cli--buffers (delq (current-buffer) copilot-cli--buffers)))

(defun copilot-cli--live-buffers ()
  "Return (and prune) the list of live Copilot CLI buffers."
  (setq copilot-cli--buffers (seq-filter #'buffer-live-p copilot-cli--buffers)))

(defun copilot-cli--project-root ()
  "Return the root directory of the current project.
Falls back to `default-directory' if no project is found."
  (or (when-let ((project (project-current)))
        (project-root project))
      default-directory))

(defun copilot-cli--buffer-name ()
  "Return a project-specific buffer name for Copilot CLI.
Includes the project root so each project gets its own session."
  (format "%s<%s>" copilot-cli-buffer-name
          (abbreviate-file-name (copilot-cli--project-root))))

;;;###autoload
(defun copilot-cli ()
  "Start Copilot CLI in an Eat terminal in a vertical split.

The terminal runs in the current project's root directory.  If a
Copilot CLI session is already running for this project, switch to
its buffer instead of starting a new one."
  (interactive)
  (let ((cmd (car (split-string copilot-cli-program))))
    (unless (executable-find cmd)
      (user-error "Cannot find `%s' on PATH; customize `copilot-cli-program'" cmd)))
  (let* ((root (copilot-cli--project-root))
         (default-directory root)
         (buf-name (copilot-cli--buffer-name))
         (buf (get-buffer buf-name)))
    (cond
     ;; Live session exists for this project — switch to it.
     ((and buf (get-buffer-process buf))
      (pop-to-buffer buf)
      (copilot-cli--register-buffer buf))
     ;; Stale or no buffer — start fresh.
     (t
      (when buf (kill-buffer buf))
      (funcall copilot-cli-window-function)
      (let ((eat-buffer-name buf-name))
        (eat copilot-cli-program))
      (when-let ((eat-buf (get-buffer buf-name)))
        (copilot-cli--register-buffer eat-buf))))))

(defun copilot-cli--find-buffer ()
  "Find a Copilot CLI buffer to act on.
Prefers the current buffer if it is managed, then the current
project's session, then the only active session, otherwise prompts."
  (let ((bufs (copilot-cli--live-buffers)))
    (cond
     ((memq (current-buffer) bufs) (current-buffer))
     ((let ((b (get-buffer (copilot-cli--buffer-name))))
        (and (memq b bufs) b)))
     ((null bufs) nil)
     ((null (cdr bufs)) (car bufs))
     (t (get-buffer
         (completing-read "Copilot CLI session: "
                          (mapcar #'buffer-name bufs)
                          nil t))))))

(defun copilot-cli--cleanup-buffer (buf)
  "Close BUF's window and kill BUF without prompting."
  (when (buffer-live-p buf)
    (let ((win (get-buffer-window buf t)))
      (when (and win (window-deletable-p win))
        (delete-window win)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let ((kill-buffer-query-functions nil)
              (kill-buffer-hook nil))
          (kill-buffer buf))))))

;;;###autoload
(defun copilot-cli-stop ()
  "Gracefully shut down the Copilot CLI session, then close its buffer.
Sends `copilot-cli-exit-command' to the running process and waits up
to `copilot-cli-exit-timeout' seconds before force-killing."
  (interactive)
  (if-let ((buf (copilot-cli--find-buffer)))
      (let ((proc (get-buffer-process buf)))
        (cond
         ((not (and proc (process-live-p proc)))
          (copilot-cli--cleanup-buffer buf))
         (t
          (set-process-query-on-exit-flag proc nil)
          (add-function :after (process-sentinel proc)
                        (lambda (p _event)
                          (unless (process-live-p p)
                            (copilot-cli--cleanup-buffer (process-buffer p)))))
          (message "Shutting down Copilot CLI (%s)..." (buffer-name buf))
          (process-send-string proc copilot-cli-exit-command)
          (run-at-time
           copilot-cli-exit-timeout nil
           (lambda ()
             (when (process-live-p proc)
               (message "Copilot CLI did not exit in time; force-killing.")
               (delete-process proc)
               (copilot-cli--cleanup-buffer buf)))))))
    (message "No active Copilot CLI session found.")))

(provide 'copilot-cli)
;;; copilot-cli.el ends here
