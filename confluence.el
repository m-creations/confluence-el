;;; confluence.el --- Emacs mode for interacting with confluence wikie

;; Copyright (C) 2008  Free Software Foundation, Inc.

;; Author: James Ahlborn <jahlborn@boomi.com>
;; Keywords: confluence, wiki, jscheme, xmlrpc

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;;
;; DOWNLOADING
;;
;; This module is available at Google Code:
;;
;;   http://code.google.com/p/confluence-el/
;;
;; INSTALLATION 
;;
;; You must set confluence-url in your .emacs file before using the
;; functions in this moudule.
;;
;; Some examples:
;;
;;   ;; loading xml-rpc.el may not be necessary, it depends on your
;;   ;; installed version of Emacs, it was necessary on 22.1.1
;;
;;   (load (expand-file-name "~/software/emacs/confluence-el/xml-rpc.el"))
;;   (load (expand-file-name "~/software/emacs/confluence-el/confluence.el"))
;;   (setq confluence-url "http://intranet/confluence/rpc/xmlrpc")
;;
;; USING CONFLUENCE MODE
;;
;; To open a page, M-x confluence-get-page and enter the path to the
;; page, for example, to open a page in your home space: ~username/Tasks
;;
;; It is often convienient to bind this to a global key \C-xwf in your .emacs file:
;;   
;;    (global-set-key "\C-xwf")
;;
;; Also, if you want keybindings for confluence-mode, you can put the
;; following in your .emacs file:
;;
;;    (local-set-key "\C-xw" confluence-prefix-map)
;;
;; Once you have opened a page, made changes, simply saving the page
;; ("\C-x\C-f") will push the changes back to the wiki.
;;
;; To view the chagnes in your page versus what is in the wiki, type
;; \C-xw=, or run M-x confluence-ediff-current-page.
;;
;; (add-hook 'confluence-mode-hook
;;   (local-set-key "\C-xw" confluence-prefix-map)
;;   (local-set-key [(control f6)] 'confluence-ediff-merge-current-page)
;;   (local-set-key "\C-j" 'confluence-newline-and-indent))
;;
;; LONGLINES
;;
;;   http://www.emacswiki.org/emacs-en/LongLines
;;
;; Confluence uses a wiki-markup that treats linebreask as <p> HTML
;; tags.  Since this is the case, it is very common for paragraphs in
;; the Confluence markup to wrap around your buffer multiple times.
;; The LongLines mode allows those lines to be viewed within Emacs
;; with 'soft' linebreaks - which are inserted automatically, or via
;; M-q.  This makes it much more pleasant to work with large
;; paragraphs of text in the Confluence markup without introducing
;; unwated paragraphs.
;;
;; See below for more advice on using LongLines and confluence-mode.
;;
;;
;; EXAMPLE .emacs CONFIGURATION
;;
;; (load (expand-file-name "~/software/emacs/confluence-el/xml-rpc.el"))
;; (load (expand-file-name "~/software/emacs/confluence-el/confluence.el"))
;;
;; ;; note, all customization must be in *one* custom-set-variables block
;; (custom-set-variables
;;  ;; ... other custimization
;;
;;  ;; confluence customization
;;  '(confluence-url "http://intranet/confluence/rpc/xmlrpc")
;;  '(confluence-default-space-alist (list (cons confluence-url "your-default-space-name"))))
;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;; confluence editing support (with longlines mode)
;;
;; (autoload 'confluence-get-page "confluence" nil t)
;;
;; (eval-after-load "confluence"
;;   '(progn
;;      (require 'longlines)
;;      (progn
;;        (add-hook 'confluence-mode-hook 'longlines-mode)
;;        (add-hook 'confluence-before-save-hook 'longlines-before-revert-hook)
;;        (add-hook 'confluence-before-revert-hook 'longlines-before-revert-hook)
;;        (add-hook 'confluence-mode-hook '(lambda () (local-set-key "\C-j" 'confluence-newline-and-indent))))))
;;
;; ;; LongLines mode: http://www.emacswiki.org/emacs-en/LongLines
;; (autoload 'longlines-mode "longlines" "LongLines Mode." t)
;;
;; (eval-after-load "longlines"
;;   '(progn
;;      (defvar longlines-mode-was-active nil)
;;      (make-variable-buffer-local 'longlines-mode-was-active)
;;
;;      (defun longlines-suspend ()
;;        (if longlines-mode
;;            (progn
;;              (setq longlines-mode-was-active t)
;;              (longlines-mode 0))))
;;
;;      (defun longlines-restore ()
;;        (if longlines-mode-was-active
;;            (progn
;;              (setq longlines-mode-was-active nil)
;;              (longlines-mode 1))))
;;
;;      ;; longlines doesn't play well with ediff, so suspend it during diffs
;;      (defadvice ediff-make-temp-file (before make-temp-file-suspend-ll
;;                                              activate compile preactivate)
;;        "Suspend longlines when running ediff."
;;        (with-current-buffer (ad-get-arg 0)
;;          (longlines-suspend)))
;;
;;     
;;      (add-hook 'ediff-cleanup-hook 
;;                '(lambda ()
;;                   (dolist (tmp-buf (list ediff-buffer-A
;;                                          ediff-buffer-B
;;                                          ediff-buffer-C))
;;                     (if (buffer-live-p tmp-buf)
;;                         (with-current-buffer tmp-buf
;;                           (longlines-restore))))))))
;;
;; ;; keybindings (change to suit)
;;
;; ;; open confluence page
;; (global-set-key "\C-xwf" 'confluence-get-page)
;;
;; ;; setup confluence mode
;; (add-hook 'confluence-mode-hook
;;           '(lambda ()
;;              (local-set-key "\C-xw" confluence-prefix-map)))
;;
;; 

;;; Code:

(require 'xml-rpc)
(require 'ediff)
(require 'thingatpt)
(require 'browse-url)

(defgroup confluence nil
  "Support for editing confluence wikis."
  :prefix "confluence-")

(defcustom confluence-url nil
  "Url of the confluence service to interact with.  This must
point to the XML-RPC api URL for your confluence installation.

If your confluence installation is at http://intranet/confluence,
then the XML-RPC URL is probably
http://intranet/confluence/rpc/xmlrpc.  Setting this in your
.emacs is necessary before interacting with the Wiki."
  :group 'confluence
  :type 'string)

(defcustom confluence-default-space-alist nil
  "AList of default confluence spaces to use ('url' -> 'space')."
  :group 'confluence
  :type '(alist :key-type string :value-type string))

(defcustom confluence-search-max-results 20
  "Maximum number of results to return from a search."
  :group 'confluence
  :type 'integer)

(defcustom confluence-prompt-page-function 'cf-prompt-page-by-component
  "The function to used to prompt for pages when opening new pages."
  :group 'confluence
  :type 'function)

(defcustom confluence-coding-alist nil
  "Coding systems to use for a given service ('url' -> 'coding-system').  Confluence versions < 2.8 incorrectly
managed xml encoding and used the server's platform default encoding (ignoring any specified by the xml itself).  If
you are working with an older system, you will need to configure the coding system here (default 'utf-8 is used if not
configured here)."
  :group 'confluence
  :type '(alist  :key-type string :value-type coding-system))

(defvar confluence-coding-prefix-alist (list (cons 'utf-16-be "\376\377")
                                             (cons 'utf-16-le "\377\376"))
  "Extra prefix necessary when decoding a string in a given coding system (not necessary for all coding systems).  The
empty string is used if nothing is defined here, which works for most coding systems.")

(defvar confluence-coding-bytes-per-char-alist (list (cons 'utf-16-be 2)
                                                     (cons 'utf-16-le 2))
  "Number of bytes per character for the coding system.  Assumed be be 1 or variable if not defined here, which works
for most coding systems.")

(defvar confluence-before-save-hook nil
  "List of functions to be called before saving a confluence page.")

(defvar confluence-before-revert-hook nil
  "List of functions to be called before reverting a confluence page.")

(defvar confluence-login-token-alist nil
  "AList of 'url' -> 'token' login information.")

(defvar confluence-path-history nil
  "History list of paths accessed.")

(defvar confluence-space-history nil
  "History list of spaces accessed.")

(defvar confluence-page-history nil
  "History list of pages accessed.")

(defvar confluence-search-history nil
  "History list of queries.")

(defvar confluence-page-url nil
  "The url used to load the current buffer.")
(make-variable-buffer-local 'confluence-page-url)
(put 'confluence-page-url 'permanent-local t)

(defvar confluence-page-struct nil
  "The full metadata about the page in the current buffer.")
(make-variable-buffer-local 'confluence-page-struct)
(put 'confluence-page-struct 'permanent-local t)

(defvar confluence-page-id nil
  "The id of the page in the current buffer.")
(make-variable-buffer-local 'confluence-page-id)
(put 'confluence-page-id 'permanent-local t)

(defvar confluence-browse-function nil
  "The function to use for browsing links in the current buffer.")
(make-variable-buffer-local 'confluence-browse-function)
(put 'confluence-browse-function 'permanent-local t)

(defvar confluence-load-info nil
  "The information necessary to reload the page.")
(make-variable-buffer-local 'confluence-load-info)
(put 'confluence-load-info 'permanent-local t)

;; these are never set directly, only defined here to make the compiler happy
(defvar confluence-coding-system nil)
(defvar confluence-coding-prefix nil)
(defvar confluence-coding-num-bytes nil)
(defvar confluence-input-url nil)
(defvar confluence-switch-url nil)

(defvar confluence-tag-stack nil
  "TAGs style stack support for push (\\C-xw.) and pop (\\C-xw*)")

(defun confluence-login (&optional arg)
  "Logs into the current confluence url, if necessary.  With ARG, forces
re-login to the current url."
  (interactive "P")
  (let ((cur-token (cf-get-struct-value confluence-login-token-alist
                                        (cf-get-url))))
    (if (or (not cur-token)
            arg)
        (progn
          (setq cur-token
                (cf-rpc-execute-internal 
                 'confluence1.login
                 (read-string "Username: " user-login-name nil nil t)
                 (read-passwd "Password: ")))
          (cf-set-struct-value 'confluence-login-token-alist
                               (cf-get-url) cur-token)
          ))
    cur-token))

(defun confluence-get-page (&optional page-name space-name)
  "Loads a confluence page for the given SPACE-NAME and PAGE-NAME
into a buffer (if not already loaded) and switches to it.
Analogous to `find-file'.  Every time you navitage to a page with
this function (or M-. `confluence-get-page-at-point'), it is
saved off into a stack (`confluence-tag-stack') that you can then
pop back out of to return back through your navigation path (with
M-* `confluence-pop-tag-stack')."
  (interactive)
  (cf-prompt-page-info nil 'page-name 'space-name)
  (cf-show-page (cf-rpc-get-page-by-name space-name page-name)))

(defun confluence-get-page-with-url (&optional arg)
  "With ARG, prompts for the confluence url to use for the get
page call (based on `confluence-default-space-alist')."
  (interactive "P")
  (let ((confluence-switch-url arg)
        (confluence-input-url nil))
    (confluence-get-page)))

(defun confluence-get-page-at-point ()
  "Opens the confluence page at the current point.  If the link is a url,
opens the page using `browse-url', otherwise attempts to load it
as a confluence page.  Analogous to M-. (`find-tag')."
  (interactive)
  (if (thing-at-point-looking-at "\\[\\(\\([^|]*\\)[|]\\)?\\([^]]+\\)\\]")
      (let ((url (match-string 3)))
        (set-text-properties 0 (length url) nil url)
        (if (string-match thing-at-point-url-regexp url)
            (browse-url url)
          (if confluence-browse-function
              (funcall confluence-browse-function url)
            (cf-simple-browse-function url))))
    (if (thing-at-point 'url)
        (browse-url-at-point)
      (confluence-get-page))))

(defun confluence-get-parent-page ()
  "Loads a confluence page for the parent of the current
confluence page into a buffer (if not already loaded) and
switches to it."
  (interactive)
  (let ((parent-page-id (cf-get-struct-value confluence-page-struct "parentId" "0")))
    (if (equal parent-page-id "0")
        (message "Current page has no parent page")
      (cf-show-page (cf-rpc-get-page-by-id parent-page-id)))))

(defun confluence-create-page (&optional page-name space-name)
  "Creates a new confluence page for the given SPACE-NAME and
PAGE-NAME and loads it into a new buffer."
  (interactive)
  (let ((new-page (list (cons "content" "")))
        (parent-page-id (cf-get-parent-page-id)))
    (cf-prompt-page-info nil 'page-name 'space-name)
    (cf-set-struct-value 'new-page "title" page-name)
    (cf-set-struct-value 'new-page "space" space-name)
    (if parent-page-id
        (cf-set-struct-value 'new-page "parentId" parent-page-id))
    (cf-show-page (cf-rpc-save-page new-page))))

(defun confluence-create-page-with-url (&optional arg)
  "With ARG, prompts for the confluence url to use for the create page call (based on
`confluence-default-space-alist')."
  (interactive "P")
  (let ((confluence-switch-url arg)
        (confluence-input-url nil))
    (confluence-create-page)))

(defun confluence-pop-tag-stack ()
  "Returns to the last previously visited space/page by popping
the tags stack."
  (interactive)
  (if (null confluence-tag-stack)
      (message "Stack is empty...")
    (let* ((stack-info (pop confluence-tag-stack))
           (load-info (nth 0 stack-info))
           (old-point (nth 1 stack-info))
           (page-type (nth 0 load-info))
           (confluence-input-url (nth 1 load-info)))
      (cond 
       ((eq page-type 'page)
        (cf-show-page (cf-rpc-get-page-by-id (nth 2 load-info)) t))
       ((eq page-type 'search)
        (cf-show-search-results 
         (cf-rpc-search (nth 2 load-info) (nth 3 load-info))
         load-info t))
       (t
        (error "Invalid stack info")))
      (goto-char old-point))))

(defun confluence-push-tag-stack ()
  "Pushes the current page onto the visited stack if it is a confluence page."
  (interactive)
  (if confluence-load-info
      (push (list confluence-load-info (point)) confluence-tag-stack)))

(defun confluence-ediff-merge-current-page ()
  "Starts an EDiff session diffing the current confluence page against the
latest version of that page saved in confluence with intent of saving the
result as the latest version of the page."
  (interactive)
  (cf-ediff-current-page t))

(defun confluence-ediff-current-page ()
  "Starts an EDiff session diffing the current confluence page against the
latest version of that page saved in confluence."
  (interactive)
  (cf-ediff-current-page nil))

(defun confluence-reparent-page ()
  "Changes the parent of the current confluence page."
  (interactive)
  (let ((parent-page-id (cf-get-parent-page-id)))
    (if (and parent-page-id
             (not (equal parent-page-id (cf-get-struct-value confluence-page-struct "parentId"))))
        (progn
          (cf-set-struct-value 'confluence-page-struct "parentId" parent-page-id)
          (set-buffer-modified-p t)))))

(defun confluence-rename-page ()
  "Changes the name (title) of the current confluence page."
  (interactive)
  (let ((page-name (cf-prompt-page-name "New ")))
    (if (and (> (length page-name) 0)
             (not (equal page-name (cf-get-struct-value confluence-page-struct "title"))))
        (progn
          (cf-set-struct-value 'confluence-page-struct "title" page-name)
          (rename-buffer (format "%s<%s>"
                                 (cf-get-struct-value confluence-page-struct "title")
                                 (cf-get-struct-value confluence-page-struct "space")))
          (set-buffer-modified-p t)
          ))))

(defun confluence-delete-page ()
  "Deletes the current confluence page."
  (interactive)
  (if (not confluence-page-id)
      (error "Could not delete Confluence page %s, missing page id"
             (buffer-name)))
  (cf-rpc-execute 'confluence1.removePage confluence-page-id)
  (while (assoc confluence-load-info confluence-tag-stack)
    (setq confluence-tag-stack
          (remove (assoc confluence-load-info confluence-tag-stack)
                  confluence-tag-stack)))
  (kill-buffer (current-buffer)))

(defun confluence-search-in-space (&optional query)
  "Runs a confluence search for QUERY, restricting the results to the space of
the current buffer."
  (interactive)
  (confluence-search nil (cf-get-struct-value confluence-page-struct "space")))

(defun confluence-search (&optional query space-name)
  "Runs a confluence search for QUERY, optionally restricting the results to
the given SPACE-NAME."
  (interactive)
  (or query
      (setq query (read-string "Query: " nil 
                               'confluence-search-history nil t)))
  (cf-show-search-results (cf-rpc-search query space-name)
                          (list 'search (cf-get-url) query space-name)))

(defun cf-rpc-execute (method-name &rest params)
  "Executes a confluence rpc call, managing the login token and logging in if
necessary."
  (condition-case err
      (apply 'cf-rpc-execute-internal method-name (confluence-login) params)
    (error
     (if (and xml-rpc-fault-string
              (string-match "\\<authenticated\\>\\|\\<expired\\>" xml-rpc-fault-string))
         (apply 'cf-rpc-execute-internal method-name (confluence-login t) params)
       (error (error-message-string err))))))

(defun cf-rpc-execute-internal (method-name &rest params)
  "Executes a raw confluence rpc call.  Handles all necessary encoding/decoding of strings."
  (setq xml-rpc-fault-string nil)
  (setq xml-rpc-fault-code   nil)
  (let* ((url-http-version "1.0")
         (url-http-attempt-keepalives nil)
         (page-url (cf-get-url))
         (confluence-coding-system (cf-get-struct-value confluence-coding-alist page-url 'utf-8))
         (confluence-coding-prefix (cf-get-struct-value confluence-coding-prefix-alist confluence-coding-system ""))
         (confluence-coding-num-bytes (cf-get-struct-value confluence-coding-bytes-per-char-alist
                                                           confluence-coding-system 1))
         (xml-rpc-encode-coding-system confluence-coding-system)
         (xml-rpc-encode-coding-prefix-length (length confluence-coding-prefix)))
    (if (not page-url)
        (error "No confluence url configured"))
    (condition-case err
        (cf-url-decode-entities-in-value (apply 'xml-rpc-method-call page-url method-name params))
      (error
       (if xml-rpc-fault-string
           (setq xml-rpc-fault-string (cf-url-decode-entities-in-value 
                                       xml-rpc-fault-string)))
       (error (cf-url-decode-entities-in-value (error-message-string err)))))
    ))

(defun cf-rpc-get-page-by-name (space-name page-name)
  "Executes a confluence 'getPage' rpc call with space and page names."
  (cf-rpc-execute 'confluence1.getPage space-name page-name))

(defun cf-rpc-get-page-by-id (page-id)
  "Executes a confluence 'getPage' rpc call with a page id."
  (cf-rpc-execute 'confluence1.getPage page-id))

(defun cf-rpc-search (query space-name)
  "Executes a confluence 'search' rpc call."
  (let ((params (list (cons "type" "page"))))
    (if (> (length space-name) 0)
        (cf-set-struct-value 'params "spaceKey" space-name))
    (cf-rpc-execute 'confluence1.search query
                    params confluence-search-max-results)))

(defun cf-rpc-save-page (page-struct)
  "Executes a confluence 'storePage' rpc call with a page struct."
  (cf-rpc-execute 'confluence1.storePage page-struct))

(defun cf-ediff-current-page (update-cur-version)
  "Starts an EDiff session for the current confluence page, optionally
updating the saved metadata to the latest version."
  (if (not confluence-page-id)
      (error "Could not diff Confluence page %s, missing page id"
             (buffer-name)))
  (let ((rev-buf)
        (cur-buf (current-buffer))
        (rev-page (cf-rpc-get-page-by-id confluence-page-id)))
    (setq rev-buf
          (get-buffer-create (format "%s.~%s~" (buffer-name cur-buf) (cf-get-struct-value rev-page "version" 0))))
    (with-current-buffer rev-buf
      (cf-insert-page rev-page)
      (toggle-read-only 1)
      )
    (if update-cur-version
        (progn
          (setq confluence-page-struct 
                (cf-set-struct-value-copy rev-page "content" ""))))
    (ediff-buffers cur-buf rev-buf nil 'confluence-diff)))

(defun cf-save-page ()
  "Saves the current confluence page and updates the buffer with the latest
page."
  (if (not confluence-page-id)
      (error "Could not save Confluence page %s, missing page id"
             (buffer-name)))
  (widen)
  (run-hooks 'confluence-before-save-hook)
  (cf-insert-page (cf-rpc-save-page 
                   (cf-set-struct-value-copy confluence-page-struct 
                                             "content" (buffer-string))) 
                  nil nil t)
  t)

(defun cf-revert-page (&optional arg noconfirm)
  "Reverts the current buffer to the latest version of the current confluence
page."
  (if (and confluence-load-info
           (or noconfirm
               (yes-or-no-p "Revert Confluence Page ")))
      (progn
        (run-hooks 'confluence-before-revert-hook)
        (let ((page-type (nth 0 confluence-load-info)))
          (setq confluence-page-url (nth 1 confluence-load-info))
          (cond ((eq page-type 'page)
                 (cf-insert-page (cf-rpc-get-page-by-id 
                                  (nth 2 confluence-load-info)) 
                                 confluence-load-info))
                ((eq page-type 'search)
                 (cf-insert-search-results 
                  (cf-rpc-search (nth 2 confluence-load-info) 
                                 (nth 3 confluence-load-info))
                  confluence-load-info))
                (t
                 (error "Invalid load info")))))))

(defun cf-show-page (full-page &optional no-push)
  "Does the work of finding or creating a buffer for the given confluence page
and loading the data if necessary."
  (if (not no-push)
      (confluence-push-tag-stack))
  (let* ((page-buf-name (format "%s<%s>"
                               (cf-get-struct-value full-page "title")
                               (cf-get-struct-value full-page "space")))
         (page-buffer (get-buffer page-buf-name)))
    (if (not page-buffer)
        (progn
          (setq page-buffer (get-buffer-create page-buf-name))
          (set-buffer page-buffer)
          (cf-insert-page full-page)
          (goto-char (point-min))))
    (switch-to-buffer page-buffer)))

(defun cf-insert-page (full-page &optional load-info browse-function keep-undo)
  "Does the work of loading confluence page data into the current buffer.  If
KEEP-UNDO, the current undo state will not be erased.  The LOAD-INFO is the 
information necessary to reload the page (if nil, normal page info is used)."
  (let ((old-point (point))
        (was-read-only buffer-read-only))
    (if was-read-only
        (toggle-read-only))
    (widen)
    (erase-buffer)
    (setq confluence-page-struct full-page)
    (setq confluence-page-url (cf-get-url))
    (setq confluence-page-id (cf-get-struct-value confluence-page-struct "id"))
    (setq confluence-load-info 
          (or load-info
              (list 'page confluence-page-url confluence-page-id)))
    (if browse-function
        (setq confluence-browse-function browse-function))
    (insert (cf-get-struct-value confluence-page-struct "content" ""))
    (cf-set-struct-value 'confluence-page-struct "content" "")
    (set-buffer-modified-p nil)
    (or keep-undo
        (eq buffer-undo-list t)
        (setq buffer-undo-list nil))
    (confluence-mode)
    (goto-char old-point)
    (if was-read-only
        (toggle-read-only 1))))

(defun cf-show-search-results (search-results load-info &optional no-push)
  "Does the work of finding or creating a buffer for the given confluence
search results and loading the data into that page."
  (if (not no-push)
      (confluence-push-tag-stack))
  (let ((confluence-input-url (cf-get-url))
        (search-buffer (get-buffer-create "*Confluence Search Results*")))
    (with-current-buffer search-buffer
      (if (not (equal confluence-load-info load-info))
          (progn
            (if (eq major-mode 'confluence-mode)
                (run-hooks 'confluence-before-revert-hook))
            (cf-insert-search-results search-results load-info)
            (goto-char (point-min))
            (toggle-read-only 1))))
    (switch-to-buffer search-buffer)))

(defun cf-insert-search-results (search-results load-info)
  "Does the work of loading confluence search data into the current buffer."
  (let ((search-page (list (cons "title" "Confluence Search Results"))))
    (with-temp-buffer
      (insert "h1. Confluence Search Results for '" (nth 2 load-info) "'\n\n")
      (dolist (search-result search-results)
        (insert (format "[%s|%s]\n"
                        (cf-get-struct-value search-result "title")
                        (cf-get-struct-value search-result "id")))
        (let ((excerpt (cf-get-struct-value search-result "excerpt")))
          (if (> (length excerpt) 0)
              (insert excerpt "\n")))
        (insert "\n"))
      (cf-set-struct-value 'search-page "content" (buffer-string)))
    (cf-insert-page search-page load-info 'cf-search-browse-function)))

(defun cf-search-browse-function (url)
  "Browse function used in search buffers (the links are page ids)."
  (cf-show-page (cf-rpc-get-page-by-id url)))

(defun cf-simple-browse-function (url)
  "Simple browse function used in page buffers."
  (let ((space-name (cf-get-struct-value confluence-page-struct "space"))
        (page-name url))
    (if (string-match "^\\([^:]*\\)[:]\\(.*\\)$" page-name)
        (progn
          (setq space-name (match-string 1 page-name))
          (setq page-name (match-string 2 page-name))))
    (if (string-match "^\\(.*?\\)[#^].*$" page-name)
        (setq page-name (match-string 1 page-name)))
    (confluence-get-page page-name space-name)))

(defun cf-get-parent-page-id ()
  "Gets a confluence parent page id, optionally using the one in the current
buffer."
  (if (and confluence-page-id
           (yes-or-no-p "Use current page for parent "))
      confluence-page-id
    (let ((parent-space-name (or (cf-get-struct-value confluence-page-struct "space") nil))
          (parent-page-name nil))
      (cf-prompt-page-info "Parent " 'parent-page-name 'parent-space-name)
      (if (and (> (length parent-space-name) 0)
               (> (length parent-page-name) 0))
          (cf-get-struct-value (cf-rpc-get-page-by-name parent-space-name parent-page-name) "id")
        nil))))

(defun cf-prompt-page-info (prompt-prefix page-name-var space-name-var)
  "Prompts for page info using the appropriate input function and sets the given vars appropriately."
  (let ((result-list
         (funcall confluence-prompt-page-function prompt-prefix
                  (symbol-value page-name-var) (symbol-value space-name-var))))
    (set page-name-var (nth 0 result-list))
    (set space-name-var (nth 1 result-list))))

(defun cf-prompt-page-by-component (prompt-prefix page-name space-name)
  "Builds a list of (page-name space-name <url>) by prompting the user for each.  Suitable for use with
`confluence-prompt-page-function'."
  (let ((result-list nil))
    (if (and confluence-switch-url (not confluence-input-url))
        (setq confluence-input-url (cf-prompt-url prompt-prefix)))
    (push (or space-name
              (cf-prompt-space-name prompt-prefix)) result-list)
    (push (or page-name
              (cf-prompt-page-name prompt-prefix)) result-list)
    result-list))

(defun cf-prompt-page-by-path (prompt-prefix page-name space-name)
  "Builds a list of (page-name space-name <url>) by prompting the user for each (where page and space name are
specified as one path).  Suitable for use with `confluence-prompt-page-function'."
  (let ((result-list nil)
        (page-path nil))
    (if (and confluence-switch-url (not confluence-input-url))
        (setq confluence-input-url (cf-prompt-url prompt-prefix)))
    (if (and page-name space-name)
        (setq result-list (cons page-name (cons space-name result-list)))
      (progn
        (setq page-path (cf-prompt-path prompt-prefix page-name space-name))
        (push (cf-get-space-name-from-path page-path) result-list)
        (push (cf-get-page-name-from-path page-path) result-list)))
    result-list))

(defun cf-prompt-url (&optional prompt-prefix)
  "Prompts for a confluence url."
  (let ((temp-url-hist (and confluence-default-space-alist
                            (mapcar 'car confluence-default-space-alist))))
    (read-string (concat (or prompt-prefix "") "Url: ") nil 'temp-url-hist nil t)))

(defun cf-prompt-space-name (&optional prompt-prefix)
  "Prompts for a confluence space name."
  (let* ((def-space (cf-get-default-space))
         (space-prompt (if def-space
                           (format "Page Space [%s]: " def-space)
                         "Page Space: ")))
    (read-string (concat (or prompt-prefix "") space-prompt) 
                 (cf-get-struct-value confluence-page-struct "space") 
                 'confluence-space-history def-space t)))

(defun cf-prompt-page-name (&optional prompt-prefix)
  "Prompts for a confluence page name."
  (read-string (concat (or prompt-prefix "") "Page Name: ") nil 'confluence-page-history nil t))

(defun cf-prompt-path (prompt-prefix page-name space-name)
  "Prompts for a confluence page path."
  (read-string (concat (or prompt-prefix "") "PageSpace/PageName: ")
               (if space-name (concat space-name "/") nil)
               'confluence-path-history nil t))

(defun cf-get-space-name-from-path (page-path)
  "Parses the space name from the given PAGE-PATH."
  (if (string-match "\\([^/]+\\)[/]\\(.*\\)" page-path)
      (match-string 1 page-path)
    (cf-get-default-space)))

(defun cf-get-page-name-from-path (page-path)
  "Parses the page name from the given PAGE-PATH."
  (if (string-match "\\([^/]+\\)[/]\\(.*\\)" page-path)
      (match-string 2 page-path)
    page-path))

(defun cf-get-struct-value (struct key &optional default-value)
  "Gets a STRUCT value for the given KEY from the given struct, returning the
given DEFAULT-VALUE if not found."
  (or (and struct
           (cdr (assoc key struct)))
      default-value))

(defun cf-set-struct-value-copy (struct key value)
  "Copies the given STRUCT, sets the given KEY to the given VALUE and returns
the new STRUCT."
  (let ((temp-struct (copy-alist struct)))
    (cf-set-struct-value 'temp-struct key value)
    temp-struct))

(defun cf-set-struct-value (struct-var key value)
  "Sets (or adds) the given KEY to the given VALUE in the struct named by the
given STRUCT-VAR."
  (let ((cur-assoc (assoc key (symbol-value struct-var))))
    (if cur-assoc
        (setcdr cur-assoc value)
      (add-to-list struct-var (cons key value) t))))

(defun cf-get-url ()
  "Gets the confluence url to use for the current operation."
  (or confluence-input-url confluence-page-url confluence-url))

(defun cf-get-default-space ()
  "Gets the default confluence space to use for the current operation."
  (cf-get-struct-value confluence-default-space-alist (cf-get-url)))

(defun cf-url-decode-entities-in-value (value)
  "Decodes XML entities in the given value, which may be a struct, list or
something else."
  (cond ((listp value)
         (dolist (struct-val value)
           (setcdr struct-val 
                   (cf-url-decode-entities-in-value (cdr struct-val)))))
        ((stringp value)
         (setq value (cf-url-decode-entities-in-string value))))
  value)

(defun cf-url-decode-entities-in-string (string)
  "Convert XML entities to string values:
    &amp;    ==>  &
    &lt;     ==>  <
    &gt;     ==>  >
    &quot;   ==>  \"
    &#[0-9]+ ==>  <appropriate char>"
  (if (and (stringp string)
           (string-match "[&\r]" string))
      (save-excursion
	(set-buffer (get-buffer-create " *Confluence-decode*"))
	(erase-buffer)
	(buffer-disable-undo (current-buffer))
	(insert string)
	(goto-char (point-min))
        (while (re-search-forward "&\\([^;]+\\);" nil t)
          (let ((ent-str (match-string 1)))
            (replace-match (cond
                            ((cdr-safe (assoc ent-str
                                              '(("quot" . ?\")
                                                ("amp" . ?&)
                                                ("lt" . ?<)
                                                ("gt" . ?>)))))
                            ((save-match-data
                               (and (string-match "^#\\([0-9]+\\)$" ent-str)
                                    (cf-number-entity-to-string (string-to-number (match-string 1 ent-str))))))
                            ((save-match-data
                               (and (string-match "^#x\\([0-9A-Fa-f]+\\)$" ent-str)
                                    (cf-number-entity-to-string (string-to-number (match-string 1 ent-str) 16)))))
                            (t ent-str))
                           t t)))

	(goto-char (point-min))
        (while (re-search-forward "\r\n" nil t)
          (replace-match "\n" t t))
	(buffer-string))
    string))

(defun cf-number-entity-to-string (num)
  "Convert an xml number entity to the appropriate character using the current `confluence-coding-system' (which is
set by `cf-rpc-execute-internal')."
  (let ((char-list nil))
    (push (logand num 255) char-list)
    (setq num (lsh num -8))
    (while (/= 0 num)
      (push (logand num 255) char-list)
      (setq num (lsh num -8)))
    (while (< (length char-list) confluence-coding-num-bytes)
      (push 0 char-list))
    (decode-coding-string (concat confluence-coding-prefix (apply 'string char-list)) confluence-coding-system t)))


(defconst confluence-keywords
  (list
  
   '("{\\([^}]+\\)}"
     (1 'font-lock-constant-face))
  
   '("{warning\\(?:[:][^}]*\\)?}\\(.*?\\){warning}"
     (1 'font-lock-warning-face prepend))
   '("{note\\(?:[:][^}]*\\)?}\\(.*?\\){note}"
     (1 'font-lock-minor-warning-face prepend))
   '("{info\\(?:[:][^}]*\\)?}\\(.*?\\){info}"
     (1 'font-lock-doc-face prepend))
   '("{tip\\(?:[:][^}]*\\)?}\\(.*?\\){tip}"
     (1 'font-lock-comment-face prepend))
   '("{noformat\\(?:[:][^}]*\\)?}\\(.*?\\){noformat}"
     (1 'font-lock-comment-face prepend))
  
   ;; bold
   '("[ ][*]\\([^*]+\\)[*][ ]"
     (1 'bold))
   
   ;; code
   '("{{\\([^*]+\\)}}"
     (1 doxygen-code-face))
   
   ;; italics/emphasised
   '("[ ]_\\([^_]+\\)_[ ]"
     (1 'italic prepend))

   ;; underline
   '("[ ][+]\\([^+]+\\)[+][ ]"
     (1 'underline prepend))

   ;; headings
   '("^h1[.] \\(.*\\)$"
     (1 '(bold underline) prepend))
   '("^h2[.] \\(.*\\)$"
     (1 '(bold italic underline) prepend))
   '("^h3[.] \\(.*\\)$"
     (1 '(italic underline) prepend))
   '("^h[4-9][.] \\(.*\\)$"
     (1 'underline prepend))

   ;; bullet points
   '("^\\([*#]+\\)[ ]"
     (1 'font-lock-constant-face))
   
   ;; links
   '("\\(\\[\\)\\([^|]*\\)[|]\\([^]]+\\)\\(\\]\\)"
     (1 'font-lock-constant-face)
     (2 'font-lock-string-face)
     (3 'underline)
     (4 'font-lock-constant-face))
   '("\\(\\[\\)\\([^]|]+\\)\\(\\]\\)"
     (1 'font-lock-constant-face)
     (2 '(font-lock-string-face underline))
     (3 'font-lock-constant-face))

   ;; images, embedded content
   '("\\([!]\\)\\([^!]+\\)\\([!]\\)"
     (1 'font-lock-constant-face)
     (2 'font-lock-reference-face)
     (3 'font-lock-constant-face))
   
   ;; tables
   '("[|]\\{2\\}\\([^|\n]+\\)"
     (1 'bold))
   '("\\([|]\\{1,2\\}\\)"
     (1 'font-lock-constant-face))
   )
  
  )

(define-derived-mode confluence-mode text-mode "Confluence"
  "Set major mode for editing Confluence Wiki pages."
  (turn-off-auto-fill)
  (make-local-variable 'revert-buffer-function)
  (setq revert-buffer-function 'cf-revert-page)
  (make-local-variable 'make-backup-files)
  (setq make-backup-files nil)
  (add-hook 'write-contents-hooks 'cf-save-page)
  ;; we set this to some nonsense so save-buffer works
  (setq buffer-file-name (expand-file-name (concat "." (buffer-name)) "~/"))
  (setq font-lock-defaults
        '(confluence-keywords nil nil nil nil))
)

(defvar confluence-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map "f" 'confluence-get-page)
    (define-key map "c" 'confluence-create-page)
    (define-key map "=" 'confluence-ediff-current-page)
    (define-key map "m" 'confluence-ediff-merge-current-page)
    (define-key map "p" 'confluence-get-parent-page)
    (define-key map "r" 'confluence-rename-page)
    (define-key map "s" 'confluence-search)
    (define-key map "." 'confluence-get-page-at-point)
    (define-key map "*" 'confluence-pop-tag-stack)
    map)
  "Keybinding prefix map which can be bound for common functions in confluence mode.")

(defun confluence-newline-and-indent ()
  "Inserts a newline and indents using the previous indentation.
Supports lists, tables, and headers."
  (interactive)
  (let ((indentation nil)
        (limit nil))
    (save-excursion
      (while (and (search-backward "\n" nil 'silent)
                  use-hard-newlines
                  (not (get-text-property (match-beginning 0) 'hard))))
      (setq limit (point)))
    (save-excursion
      (if (re-search-backward "^\\(?:\\(?:\\(?:[*#]+\\|h[0-9][.]\\)[ \t]+\\)\\|[|]+\\)" limit t)
          (setq indentation (match-string 0))))
    (newline)
    (if indentation
        (insert indentation))))

(provide 'confluence)
;;; confluence.el ends here
