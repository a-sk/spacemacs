;;; ivy-spacemacs.el --- Spacemacs layer exploration with `ivy'.

;; Author: Justin Burkett <justin@burkett.cc>
;; Keywords: ivy, spacemacs
;; Version: 0.1
;; Package-Requires: ((ivy "0.7"))

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;; This package adds a convenient way to discover Spacemacs configuration
;; layers thanks to ivy.

;;; Code:

(require 'cl)
(require 'ht)
(require 'ivy)
(require 'core-configuration-layer)

(defvar ivy-spacemacs-all-layers nil
  "Alist of all configuration layers.")

(defvar ivy-spacemacs-all-packages nil
  "Hash table of all packages in all layers.")

(defun ivy-spacemacs//init (&optional arg)
  (when (or arg (null ivy-spacemacs-all-packages))
    (mapc (lambda (layer) (push (configuration-layer/make-layer layer)
                                ivy-spacemacs-all-layers))
          (configuration-layer/get-layers-list))
    (dolist (layer ivy-spacemacs-all-layers)
      (unless (configuration-layer/layer-usedp (oref layer :name))
        (configuration-layer//load-layer-files layer '("funcs.el"
                                                       "config.el"))))
    (setq ivy-spacemacs-all-packages (configuration-layer/get-packages
                                       ivy-spacemacs-all-layers))))

;;;###autoload
(defun ivy-spacemacs-docs (arg)
  "Layers discovery with helm interface."
  (interactive "P")
  (ivy-spacemacs//init arg)
  (ivy-read "Spacemacs Documentation: "
            (ivy-spacemacs//documentation-candidates)
            :action #'ivy-spacemacs//documentation-action-open-file))

;;;###autoload
(defun ivy-spacemacs-faq (arg)
  "Looking in the FAQ with helm."
  (interactive "P")
  (ivy-read "Spacemacs FAQ"
            (ivy-spacemacs//faq-candidates)
            :action #'ivy-spacemacs//faq-goto-marker))

;;;###autoload
(defun ivy-spacemacs-layers ()
  (interactive)
  (ivy-spacemacs//init)
  (ivy-read "Spacemacs Layers: "
            (sort (mapcar 'symbol-name (configuration-layer/get-layers-list)) 'string<)
            :action 'ivy-spacemacs//layer-action-open-readme
            :caller 'ivy-spacemacs-layers))

(ivy-set-actions
 'ivy-spacemacs-layers
 '(("a" 'ivy-spacemacs//layer-action-add-layer "add layer")
   ("e" 'ivy-spacemacs//layer-action-open-readme-edit "add readme for editing")
   ("p" 'ivy-spacemacs//layer-action-open-packages "open packages.el")
   ("r" 'ivy-spacemacs//layer-action-open-readme "open readme")))

;;;###autoload
(defun ivy-spacemacs-packages ()
  (interactive)
  (ivy-spacemacs//init)
  (ivy-read "Spacemacs Packages: "
            (ivy-spacemacs//package-candidates)
            :action 'ivy-spacemacs//package-action-goto-init-func
            :caller 'ivy-spacemacs-packages))

;;;###autoload
(defun ivy-spacemacs-toggles ()
  (interactive)
  (ivy-read "Spacemacs Toggles: "
            (ivy-spacemacs//toggle-candidates)
            :action 'ivy-spacemacs//toggle))

;;;###autoload
(defun ivy-spacemacs-dotspacemacs ()
  (interactive)
  (ivy-read ".spacemacs variables: "
            (ivy-spacemacs//dotspacemacs-candidates)
            :action 'ivy-spacemacs//go-to-dotfile-variable))

(defun ivy-spacemacs//documentation-candidates ()
  (let (result file-extension)
    (dolist (filename (directory-files spacemacs-docs-directory))
      (setq file-extension (file-name-extension filename))
      (when (or (equal file-extension "md")
                (equal file-extension "org"))
        (push filename result)))

    ;; CONTRIBUTING.org is a special case as it should be at the root of the
    ;; repository to be linked as the contributing guide on Github.
    (push "CONTRIBUTING.org" result)

    ;; delete DOCUMENTATION.org to make it the first guide
    (delete "DOCUMENTATION.org" result)
    (push "DOCUMENTATION.org" result)

    ;; give each document an appropriate title
    (mapcar (lambda (r)
              (cond
               ((string-equal r "CONTRIBUTING.org")
                `("How to contribute to Spacemacs" . ,r))
               ((string-equal r "CONVENTIONS.org")
                `("Spacemacs conventions" . ,r))
               ((string-equal r "DOCUMENTATION.org")
                `("Spacemacs documentation" . ,r))
               ((string-equal r "FAQ.org")
                `("Spacemacs FAQ" . ,r))
               ((string-equal r "HOWTOs.org")
                `("Quick HOW-TOs for Spacemacs" . ,r))
               ((string-equal r "LAYERS.org")
                `("Tips on writing layers for Spacemacs" . ,r))
               ((string-equal r "QUICK_START.org")
                `("Quick start guide for Spacemacs" . ,r))
               ((string-equal r "VIMUSERS.org")
                `("Vim users migration guide" . ,r))
               (t
                `(r . ,r))))
            result)))

(defun ivy-spacemacs//documentation-action-open-file (candidate)
  "Open documentation FILE."
  (let ((file (if (string= candidate "CONTRIBUTING.org")
                  ;; CONTRIBUTING.org is a special case as it should be at the
                  ;; root of the repository to be linked as the contributing
                  ;; guide on Github.
                  (concat user-emacs-directory candidate)
                (concat spacemacs-docs-directory candidate))))
    (cond ((equal (file-name-extension file) "md")
           (condition-case nil
               (with-current-buffer (find-file-noselect file)
                 (gh-md-render-buffer)
                 (kill-this-buffer))
             ;; if anything fails, fall back to simply open file
             (find-file file)))
          ((equal (file-name-extension file) "org")
           (spacemacs/view-org-file file "^" 'all))
          (t
           (find-file file)))))

;; (defun ivy-spacemacs//layer-source ()
;;   "Construct the helm source for the layer section."
;;   `((name . "Layers")
;;     (candidates . ,(sort (configuration-layer/get-layers-list) 'string<))
;;     (candidate-number-limit)
;;     (keymap . ,ivy-spacemacs--layer-map)
;;     (action . (("Open README.org"
;;                 . ivy-spacemacs//layer-action-open-readme)
;;                ("Open packages.el"
;;                 . ivy-spacemacs//layer-action-open-packages)
;;                ;; TODO remove extensions in 0.105.0
;;                ("Open extensions.el"
;;                 . ivy-spacemacs//layer-action-open-extensions)
;;                ("Add Layer"
;;                 . ivy-spacemacs//layer-action-add-layer)
;;                ("Open README.org (for editing)"
;;                 . ivy-spacemacs//layer-action-open-readme-edit)))))

(defun ivy-spacemacs//package-candidates ()
  "Return the sorted candidates for package source."
  (let (result)
    (dolist (pkg ivy-spacemacs-all-packages)
      (push (format "%s (%S layer)"
                    (propertize (symbol-name (oref pkg :name))
                                'face 'font-lock-type-face)
                    (oref pkg :owner))
            result))
    (sort result 'string<)))

;; (defun ivy-spacemacs//toggle-source ()
;;   "Construct the helm source for the toggles."
;;   (helm-build-sync-source "Toggles"
;;     :candidates #'ivy-spacemacs//toggle-candidates
;;     :persistent-action #'ivy-spacemacs//toggle
;;     :keymap helm-map
;;     :action (helm-make-actions "Toggle" #'ivy-spacemacs//toggle)))

(defun ivy-spacemacs//toggle-candidates ()
  "Return the sorted candidates for toggle source."
  (let (result)
    (dolist (toggle spacemacs-toggles)
      (let* ((toggle-symbol (symbol-name (car toggle)))
             (toggle-name (capitalize (replace-regexp-in-string "-" " " toggle-symbol)))
             (toggle-doc (format "%s: %s"
                                 toggle-name
                                 (propertize
                                  (or (plist-get (cdr toggle) :documentation) "")
                                  'face 'font-lock-doc-face))))
        (when (plist-member (cdr toggle) :evil-leader)
          (let ((key (key-description
                      (kbd (concat dotspacemacs-leader-key " "
                                   (plist-get (cdr toggle) :evil-leader))))))
            (setq toggle-doc
                  (format "%s (%s)"
                          toggle-doc
                          (propertize key 'face 'helm-M-x-key)))))
        (if (plist-member (cdr toggle) :documentation)
            (push `(,toggle-doc . ,toggle-symbol) result)
          (push `(,toggle-name . ,toggle-symbol) result))))
    (setq result (cl-sort result 'string< :key 'car))
    result))

(defun ivy-spacemacs//dotspacemacs-candidates ()
  "Return the sorted candidates for all the dospacemacs variables."
  (sort (dotspacemacs/get-variable-string-list) 'string<))

(defun ivy-spacemacs//layer-action-open-file (file candidate &optional edit)
  "Open FILE of the passed CANDIDATE.  If EDIT is false, open in view mode."
  (let ((path (if (and (equalp file "README.org") (equalp candidate "spacemacs"))
                  ;; Readme for spacemacs is in the project root
                  (ht-get configuration-layer-paths (intern candidate))
                (file-name-as-directory
                 (concat (ht-get configuration-layer-paths
                                 (intern candidate))
                         candidate)))))
    (if (equal (file-name-extension file) "org")
        (if edit
            (find-file (concat path file))
          (spacemacs/view-org-file (concat path file) "^" 'all))
      (find-file (concat path file)))))

(defun ivy-spacemacs//layer-action-open-readme (candidate)
  "Open the `README.org' file of the passed CANDIDATE for reading."
  (ivy-spacemacs//layer-action-open-file "README.org" candidate))

(defun ivy-spacemacs//layer-action-add-layer (candidate)
  "Adds layer to dotspacemacs file and reloads configuration"
  (if (configuration-layer/layer-usedp (intern candidate))
      (message "Layer already added.")
    (let ((dotspacemacs   (find-file-noselect (dotspacemacs/location))))
      (with-current-buffer dotspacemacs
        (beginning-of-buffer)
        (let ((insert-point (re-search-forward
                             "dotspacemacs-configuration-layers *\n?.*\\((\\)")))
          (insert (format "\n%s\n" candidate))
          (indent-region insert-point (+ insert-point (length candidate)))
          (save-current-buffer)))
      (dotspacemacs/sync-configuration-layers))))

(defun ivy-spacemacs//layer-action-open-readme-edit (candidate)
  "Open the `README.org' file of the passed CANDIDATE for editing."
  (ivy-spacemacs//layer-action-open-file "README.org" candidate t))

(defun ivy-spacemacs//layer-action-open-packages (candidate)
  "Open the `packages.el' file of the passed CANDIDATE."
  (ivy-spacemacs//layer-action-open-file "packages.el" candidate))

;; TODO remove extensions in 0.105.0
(defun ivy-spacemacs//layer-action-open-extensions (candidate)
  "Open the `extensions.el' file of the passed CANDIDATE."
  (ivy-spacemacs//layer-action-open-file "extensions.el" candidate))

(defun ivy-spacemacs//package-action-goto-init-func (candidate)
  "Open the file `packages.el' and go to the init function."
  (save-match-data
    (string-match "^\\(.+\\)\s(\\(.+\\) layer)$" candidate)
    ;; (string-match "^(\\(.+\\))\s\\(.+\\):\s\\(.+\\)$" candidate)
    (let* ((package (match-string 1 candidate))
           (layer (match-string 2 candidate))
           (path (file-name-as-directory
                  (concat (ht-get configuration-layer-paths (intern layer))
                          layer)))
           (filename (concat path "packages.el")))
      (find-file filename)
      (goto-char (point-min))
      (re-search-forward (format "init-%s" package))
      (beginning-of-line))))

(defun ivy-spacemacs//toggle (candidate)
  "Toggle candidate."
  (let ((toggle (assq (intern candidate) spacemacs-toggles)))
    (when toggle
      (funcall (plist-get (cdr toggle) :function)))))

(defun ivy-spacemacs//go-to-dotfile-variable (candidate)
  "Go to candidate in the dotfile."
  (find-file dotspacemacs-filepath)
  (goto-char (point-min))
  ;; try to exclude comments
  (re-search-forward (format "^[a-z\s\\(\\-]*%s" candidate))
  (beginning-of-line))

(defvar ivy-spacemacs--faq-filename
  (concat spacemacs-docs-directory "FAQ.org")
  "Location of the FAQ file.")

;; (defun ivy-spacemacs//faq-source ()
;;   "Construct the helm source for the FAQ."
;;   `((name . "FAQ")
;;     (candidates . ,(ivy-spacemacs//faq-candidates))
;;     (candidate-number-limit)
;;     (action . (("Go to question" . ivy-spacemacs//faq-goto-marker)))))

(defun ivy-spacemacs//faq-candidate (cand)
  (let ((str (substring-no-properties (car cand))))
    (when (string-match "\\`.*/\\([^/]*\\)/\\(.*\\)\\'" str)
      (cons (concat (propertize
                     (match-string 1 str)
                     'face 'font-lock-type-face)
                    ": " (match-string 2 str))
            (cdr cand)))))

(defun ivy-spacemacs//faq-candidates ()
  (let ((cands (helm-org-get-candidates (list ivy-spacemacs--faq-filename)))
        section result)
    (dolist (c cands)
      (let ((str (substring-no-properties (car c))))
        (when (string-match "\\`\\* \\(.*\\)\\'" str)
          (setq section (match-string 1 str)))
        (when (string-match "\\`\\*\\* \\(.*\\)\\'" str)
          (push (cons (concat (propertize section 'face 'font-lock-type-face)
                              ": " (match-string 1 str))
                      (cdr c))
                result))))
    result))

(defun ivy-spacemacs//faq-goto-marker (marker)
  (find-file ivy-spacemacs--faq-filename)
  (goto-char marker)
  (org-show-context)
  (org-show-entry))

(provide 'ivy-spacemacs)

;;; ivy-spacemacs.el ends here
