(add-to-list 'load-path "~/emacs.d/")

;; Disable toolbar
(tool-bar-mode 0)

;; Line numbers please
(global-linum-mode 1)

;; Keep it clean
(setq inhibit-startup-message t
	  inhibit-startup-echo-area-message t)

;; Help me!
(setq ido-enable-flex-matching t
	  ido-everywhere t
	  ido-use-filename-at-point 'guess)
(ido-mode 1)

;; Default to 100x40
(add-to-list 'default-frame-alist '(height . 40))
(add-to-list 'default-frame-alist '(width . 100))
(add-to-list 'initial-frame-alist '(height . 40))
(add-to-list 'initial-frame-alist '(width . 100))

;; http://avdi.org/devblog/2010/04/23/daemonic-emacs/
;; Start either gnuserv or emacsserver for external access
(if (and (or
          (eq 'windows-nt system-type)
          (featurep 'xemacs))
         (locate-library "gnuserv")
         (locate-file "gnuserv" exec-path '(".exe" "")))
    (progn (require 'gnuserv)
           (gnuserv-start))
  (when (not (eq 'windows-nt system-type)) (server-start)))

;; Start up edit-server for Google Chrome Emacs integration
;(if (and (daemonp) (locate-library "edit-server"))
;    (progn
;      (require 'edit-server)
;      (edit-server-start)))

;; Awesome tabs macros from Emacs wiki; uses tabs to indent and spaces to align
;; Use tabs for indentation
(setq-default tab-width 4) ; or any other preferred value
(setq-default c-default-style "linux")
;;	      c-basic-offset 4)
(setq cua-auto-tabify-rectangles nil)

(defadvice align (around smart-tabs activate)
  (let ((indent-tabs-mode nil)) ad-do-it))

(defadvice align-regexp (around smart-tabs activate)
  (let ((indent-tabs-mode nil)) ad-do-it))

(defadvice indent-relative (around smart-tabs activate)
  (let ((indent-tabs-mode nil)) ad-do-it))

(defadvice indent-according-to-mode (around smart-tabs activate)
  (let ((indent-tabs-mode indent-tabs-mode))
		(if (memq indent-line-function
							'(indent-relative
								indent-relative-maybe))
				(setq indent-tabs-mode nil))
		ad-do-it))

(defmacro smart-tabs-advice (function offset)
  (defvaralias offset 'tab-width)
  `(defadvice ,function (around smart-tabs activate)
		 (cond
			(indent-tabs-mode
			 (save-excursion
				 (beginning-of-line)
				 (while (looking-at "\t*\\( +\\)\t+")
					 (replace-match "" nil nil nil 1)))
			 (setq tab-width tab-width)
			 (let ((tab-width fill-column)
						 (,offset fill-column))
				 ad-do-it))
			(t
			 ad-do-it))))

(smart-tabs-advice c-indent-line c-basic-offset)	
(smart-tabs-advice c-indent-region c-basic-offset)

;; TRAMP bits
;; z/OS is a "DUMB FTP HOST"
(setq 
 ange-ftp-dumb-unix-host-regexp (regexp-opt '("torolabb" "TLBA07ME")))
;(add-to-list 'tramp-default-method-alist '("torolabb" "" "ftp"))
;(add-to-list 'tramp-default-method-alist '("TLBA07ME" "" "ftp"))
;(add-to-list 'tramp-default-method-alist '("" "" "ssh"))

(custom-set-variables
  ;; custom-set-variables was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(column-number-mode t)
 '(fringe-mode (quote (nil . 0)) nil (fringe))
 '(menu-bar-mode t)
 '(scroll-bar-mode (quote right))
 '(show-paren-mode t))
(custom-set-faces
  ;; custom-set-faces was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(default ((t (:inherit nil :stipple nil :background "white" :foreground "black" :inverse-video nil :box nil :strike-through nil :overline nil :underline nil :slant normal :weight normal :height 90 :width normal :foundry "unknown" :family "DejaVu Sans Mono")))))
