
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : generic-edit.scm
;; DESCRIPTION : Generic editing routines
;; COPYRIGHT   : (C) 2001  Joris van der Hoeven
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (generic generic-edit)
  (:use (utils library tree)
	(utils library cursor)
	(utils edit variants)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Basic editing via the keyboard
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (kbd-left) (go-left))
(tm-define (kbd-right) (go-right))
(tm-define (kbd-up) (go-up))
(tm-define (kbd-down) (go-down))
(tm-define (kbd-page-up) (go-page-up))
(tm-define (kbd-page-down) (go-page-down))
(tm-define (kbd-start-line) (go-start-line))
(tm-define (kbd-end-line) (go-end-line))

(tm-define (kbd-select r)
  (select-from-shift-keyboard)
  (r)
  (select-from-cursor))

(tm-define (insert-return) (insert-raw-return))
(tm-define (kbd-return) (insert-return))
(tm-define (kbd-shift-return) (insert-return))

(tm-define (kbd-remove forward?) (remove-text forward?))
(tm-define (kbd-remove forward?)
  (:mode with-any-selection?)
  (clipboard-cut "nowhere")
  (clipboard-clear "nowhere"))

(tm-define (kbd-tab)
  (if (not (complete-try?))
      (with sh (kbd-system-rewrite (kbd-find-inv-binding '(make-htab "5mm")))
	(set-message `(concat "Use " ,sh " in order to insert a tab")
		     "tab"))))

(tm-define (kbd-shift-tab)
  (complete-try?))

(tm-define (kbd-tab)
  (:mode in-source?)
  (:inside label reference pageref)
  (if (complete-try?) (noop)))

(tm-define (kbd-shift-tab)
  (:mode in-source?)
  (:inside label reference pageref)
  (if (complete-try?) (noop)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tree traversal
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (complex-context? t)
  (and (nleaf? t) (nin? (tree-label t) '(concat document))))

(tm-define (simple-context? t)
  (or (leaf? t)
      (and (tree-in? t '(concat document))
	   (simple-context? (tree-down t)))))

(tm-define (similar-complex-context? t)
  (complex-context? t))

(tm-define (document-context? t)
  (tree-is? t 'document))

(tm-define (traverse-right) (go-to-next-word))
(tm-define (traverse-left) (go-to-previous-word))
(tm-define (traverse-up) (noop))
(tm-define (traverse-down) (noop))

(tm-define (traverse-up)
  (:context document-context?)
  (go-to-previous-tag 'document))

(tm-define (traverse-down)
  (:context document-context?)
  (go-to-next-tag 'document))

(define (traverse-tree . l)
  (cond ((null? l) (traverse-tree (tree-up (cursor-tree))))
	((tree-in? (car l) '(concat document))
	 (traverse-tree (tree-up (car l))))
	(else (car l))))

(define (traverse-label . l)
  (tree-label (apply traverse-tree l)))

(define (focus-similar-upwards t l)
  (cond ((in? (tree-label t) l) (tree-focus t))
        ((and (not (tree-is-buffer? t)) (tree-up t))
         (focus-similar-upwards (tree-up t) l))))

(tm-define (traverse-previous)
  (with t (focus-tree)
    (with l (similar-to (tree-label t))
      (go-to-previous-tag l)
      (focus-similar-upwards (focus-tree) l))))

(tm-define (traverse-next)
  (with t (focus-tree)
    (with l (similar-to (tree-label t))
      (go-to-next-tag l)
      (focus-similar-upwards (focus-tree) l))))

(tm-define (traverse-first)
  (go-to-repeat traverse-previous)
  (structured-start))

(tm-define (traverse-last)
  (go-to-repeat traverse-next)
  (structured-end))

(tm-define (traverse-previous-section-title)
  (go-to-previous-tag (similar-to 'section)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Structured editing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (structured-insert forwards?) (insert-argument forwards?))
(tm-define (structured-remove forwards?) (remove-argument forwards?))
(tm-define (structured-insert-up) (noop))
(tm-define (structured-insert-down) (noop))
(tm-define (structured-remove-up) (noop))
(tm-define (structured-remove-down) (noop))

(tm-define (structured-insert-start)
  (structured-first)
  (structured-insert #f))

(tm-define (structured-insert-end)
  (structured-first)
  (structured-insert #t))

(tm-define (structured-insert-top)
  (structured-top)
  (structured-insert-up))

(tm-define (structured-insert-bottom)
  (structured-bottom)
  (structured-insert-down))

(tm-define (structured-left)
  (with-innermost t complex-context?
    (with p (path-previous-argument (root-tree) (tree->path (tree-down t)))
      (if (nnull? p) (go-to p)))))

(tm-define (structured-right)
  (with-innermost t complex-context?
    (with p (path-next-argument (root-tree) (tree->path (tree-down t)))
      (if (nnull? p) (go-to p)))))

(tm-define (structured-up) (noop))
(tm-define (structured-down) (noop))

(tm-define (structured-start)
  (with-innermost t complex-context?
    (tree-go-to t :down :start)))

(tm-define (structured-end)
  (with-innermost t complex-context?
    (tree-go-to t :down :end)))

(tm-define (structured-exit-left)
  (with-innermost t complex-context?
    (tree-go-to t :start)))

(tm-define (structured-exit-right)
  (with-innermost t complex-context?
    (tree-go-to t :end)))

(tm-define (structured-first)
  (go-to-repeat structured-left)
  (structured-start))

(tm-define (structured-last)
  (go-to-repeat structured-right)
  (structured-end))

(tm-define (structured-top)
  (go-to-repeat structured-up)
  (structured-start))

(tm-define (structured-bottom)
  (go-to-repeat structured-down)
  (structured-end))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Multi-purpose alignment
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (geometry-default) (noop))
(tm-define (geometry-left) (noop))
(tm-define (geometry-right) (noop))
(tm-define (geometry-up) (noop))
(tm-define (geometry-down) (noop))
(tm-define (geometry-start) (noop))
(tm-define (geometry-end) (noop))
(tm-define (geometry-top) (noop))
(tm-define (geometry-bottom) (noop))
(tm-define (geometry-slower) (noop))
(tm-define (geometry-faster) (noop))
(tm-define (geometry-variant forward?) (noop))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tree editing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (tree-simple-context? t)
  (and (nleaf? t)
       (tree-is? t 'tree)
       (simple-context? (tree-down t))))

(tm-define (structured-insert forwards?)
  (:inside tree)
  (with-innermost t 'tree
    (if (== (tree-down-index t) 0) (set! t (tree-up t)))
    (if (== (tm-car t) 'tree)
	(with pos (tree-down-index t)
	  (if forwards? (set! pos (1+ pos)))
	  (tree-insert! t pos '(""))
	  (tree-go-to t pos 0)))))

(tm-define (structured-remove forwards?)
  (:inside tree)
  (with-innermost t 'tree
    (if (== (tree-down-index t) 0) (set! t (tree-up t)))
    (if (== (tm-car t) 'tree)
	(with pos (tree-down-index t)
	  (cond (forwards?
		 (tree-remove! t pos 1)
		 (if (== pos (tree-arity t))
		     (tree-go-to t :end)
		     (tree-go-to t pos :start)))
		((== pos 1) (tree-go-to t 0 :end))
		(else (tree-remove! t (- pos 1) 1)))))))

(tm-define (structured-insert-up)
  (:inside tree)
  (with-innermost t 'tree
    (if (!= (tree-down-index t) 0) (set! t (tree-down t)))
    (tree-set! t `(tree "" ,t))
    (tree-go-to t 0 0)))

(tm-define (structured-insert-down)
  (:inside tree)
  (with-innermost t 'tree
    (if (== (tree-down-index t) 0)
	(with pos (tree-arity t)
	  (tree-insert! t pos '(""))
	  (tree-go-to t pos 0))
	(begin
	  (set! t (tree-down t))
	  (tree-set! t `(tree ,t ""))
	  (tree-go-to t 1 0)))))

(define (branch-active)
  (with-innermost t 'tree
    (with i (tree-down-index t)
      (if (and (= i 0) (tree-is? t :up 'tree))
	  (tree-up t)
	  t))))

(define (branch-go-to . l)
  (apply tree-go-to l)
  (if (tree-is? (cursor-tree) 'tree)
      (with last (cAr l)
	(if (nin? last '(:start :end)) (set! last :start))
	(tree-go-to (cursor-tree) 0 last))))

(tm-define (structured-left)
  (:context tree-simple-context?)
  (let* ((t (branch-active))
	 (i (tree-down-index t)))
    (if (> i 1) (branch-go-to t (- i 1) :end))))

(tm-define (structured-right)
  (:context tree-simple-context?)
  (let* ((t (branch-active))
	 (i (tree-down-index t)))
    (if (and (!= i 0) (< i (- (tree-arity t) 1)))
	(branch-go-to t (+ i 1) :start))))

(tm-define (structured-up)
  (:context tree-simple-context?)
  (let* ((t (branch-active))
	 (i (tree-down-index t)))
    (if (!= i 0) (tree-go-to t 0 :end))))

(tm-define (structured-down)
  (:context tree-simple-context?)
  (with-innermost t 'tree
    (if (== (tree-down-index t) 0)
	(branch-go-to t (quotient (tree-arity t) 2) :start))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Extra editing functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (kill-paragraph)
  (selection-set-start)
  (go-end-paragraph)
  (selection-set-end)
  (clipboard-cut "primary"))

(tm-define (select-all)
  (tree-select (buffer-tree)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Inserting various kinds of content
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (make-label)
  (make 'label))

(tm-define (make-specific s)
  (if (or (== s "texmacs") (in-source?))
      (insert-go-to `(specific ,s "") '(1 0))
      (insert-go-to `(inactive (specific ,s "")) '(0 1 0))))

(tm-define (make-include u)
  (insert `(include ,(url->string u))))

(tm-define (make-inline-image l)
  (apply make-image (cons* (url->string (car l)) #f (cdr l))))

(tm-define (make-link-image l)
  (apply make-image (cons* (url->string (car l)) #t (cdr l))))

(tm-define (make-graphics-over-selection)
  (if (selection-active-any?)
  (with selection (selection-tree)
    (clipboard-cut "graphics background")
    (insert-go-to `(draw-over ,selection (graphics)) '(1 1)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Thumbnails facility
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (thumbnail-suffixes)
  (list->url (map url-wildcard
		  '("*.gif" "*.jpg" "*.jpeg" "*.JPG" "*.JPEG"))))

(define (fill-row l nr)
  (cond ((= nr 0) '())
	((nnull? l) (cons (car l) (fill-row (cdr l) (- nr 1))))
	(else (cons "" (fill-row l (- nr 1))))))

(define (make-rows l nr)
  (if (> (length l) nr)
      (cons (list-head l nr) (make-rows (list-tail l nr) nr))
      (list (fill-row l nr))))

(define (make-thumbnails-sub l)
  (define (mapper x)
    `(image ,(url->string x) "0.22par" "" "" ""))
  (let* ((l1 (map mapper l))
	 (l2 (make-rows l1 4))
	 (l3 (map (lambda (r) `(row ,@(map (lambda (c) `(cell ,c)) r))) l2)))
    (insert `(tabular* (tformat (twith "table-width" "1par")
				(twith "table-hyphen" "yes")
				(table ,@l3))))))

(tm-define (make-thumbnails)
  (:interactive #t)
  (dialogue
    (let* ((dir (dialogue-url "Picture directory" "directory"))
	   (find (url-append dir (thumbnail-suffixes)))
	   (files (url->list (url-expand (url-complete find "r"))))
	   (base (get-name-buffer))
	   (rel-files (map (lambda (x) (url-delta base x)) files)))
      (if (nnull? rel-files) (make-thumbnails-sub rel-files)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Routines for floats
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (make-insertion s)
  (:synopsis "Make an insertion of type @s.")
  (with pos (if (== s "float") "tbh" "")
    (insert-go-to (list 'float s pos (list 'document ""))
		  (list 2 0 0))))

(tm-define (insertion-positioning what flag)
  (:synopsis "Allow/disallow the position @what for innermost float.")
  (with-innermost t 'float
    (let ((op (if flag string-union string-minus))
	  (st (tree-ref t 1)))
      (tree-set! st (op (tree->string st) what)))))

(define (test-insertion-positioning? what)
  (with-innermost t 'float
    (with c (string-ref what 0)
      (char-in-string? c (tree->string (tree-ref t 1))))))

(define (not-test-insertion-positioning? s)
  (not (test-insertion-positioning? s)))

(tm-define (toggle-insertion-positioning what)
  (:check-mark "v" test-insertion-positioning?)
  (insertion-positioning what (not-test-insertion-positioning? what)))

(tm-define (toggle-insertion-positioning-not s)
  (:check-mark "v" not-test-insertion-positioning?)
  (toggle-insertion-positioning s))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sound and video
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (make-sound u)
  (if (not (url-none? u))
      (insert `(sound ,(url->string u)))))

(tm-define (make-animation u)
  (interactive
      (lambda (w h len rep)
	(if (== rep "no") (set! rep "false"))
	(insert `(video ,(url->string u) ,w ,h ,len ,rep)))
    "Width" "Height" "Length" "Repeat?"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Search, replace, spell and tab-completion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (key-press-command key)
  ;; FIXME: this routine should do exactly the same as key-press,
  ;; without modification of the internal state and without executing
  ;; the actual shortcut. It should rather return a command which
  ;; does all this, or #f
  (and-with p (kbd-find-key-binding key)
    (car p)))

(tm-define (keyboard-press key time)
  (:mode search-mode?)
  (with cmd (key-press-command (string-append "search " key))
    (cond (cmd (cmd))
	  ((key-press-search key) (noop))
	  (else (key-press key)))))

(tm-define (search-next)
  (key-press-search "next"))

(tm-define (search-previous)
  (key-press-search "previous"))

(tm-define (keyboard-press key time)
  (:mode replace-mode?)
  (with cmd (key-press-command (string-append "replace " key))
    (cond (cmd (cmd))
	  ((key-press-replace key) (noop))
	  (else (key-press key)))))

(tm-define (keyboard-press key time)
  (:mode spell-mode?)
  (with cmd (key-press-command (string-append "spell " key))
    (cond (cmd (cmd))
	  ((key-press-spell key) (noop))
	  (else (key-press key)))))

(tm-define (keyboard-press key time)
  (:mode complete-mode?)
  (with cmd (key-press-command (string-append "complete " key))
    (cond (cmd (cmd))
	  ((key-press-complete key) (noop))
	  (else (key-press key)))))
