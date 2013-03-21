(add-to-list 'load-path "~/.emacs.d/")
(add-to-list 'load-path "~/.emacs.d/el-get/el-get")

(unless (require 'el-get nil 'noerror)
  (with-current-buffer
      (url-retrieve-synchronously
       "https://raw.github.com/dimitri/el-get/master/el-get-install.el")
    (goto-char (point-max))
    (eval-print-last-sexp)))

(el-get 'sync)

;; GUI tweaks
(tool-bar-mode 0)
(global-linum-mode 1)

;; IDO
(setq ido-enable-flex-matching t
      ido-everywhere t
      ido-use-filename-at-point 'guess)
(ido-mode 1)

;; Default to 100x40
;; (104 allocates 4 columns for line nums)
(add-to-list 'default-frame-alist '(height . 40))
(add-to-list 'default-frame-alist '(width . 104))
(add-to-list 'initial-frame-alist '(height . 40))
(add-to-list 'initial-frame-alist '(width . 104))

;; Color
(load "color-theme-dark-bliss")
(load "color-theme-tomorrow")
(color-theme-tomorrow-night)

;; C indentation
(load "c-smart-indent")

;; Lua mode
(setq auto-mode-alist 
	  (cons '("\.fluant$" . lua-mode)
			(cons '("\.lua$" . lua-mode) auto-mode-alist)))
(autoload 'lua-mode "lua-mode" "Lua editing mode." t)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(column-number-mode t)
 '(fringe-mode (quote (nil . 0)) nil (fringe))
 '(inhibit-startup-screen t)
 '(menu-bar-mode t)
 '(scroll-bar-mode (quote right))
 '(show-paren-mode t))
