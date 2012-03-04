
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : calc-edit.scm
;; DESCRIPTION : routines for spread sheets
;; COPYRIGHT   : (C) 2012  Joris van der Hoeven
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (dynamic calc-edit)
  (:use (utils library tree)
	(utils library cursor)
	(utils plugins plugin-cmd)
	(convert tools tmconcat)
        (text tm-structure)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Spreadsheet evaluation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define calc-table (make-ahash-table))
(tm-define calc-formula (make-ahash-table))
(tm-define calc-invalid (make-ahash-table))
(tm-define calc-todo (make-ahash-table))

(tm-define (calc-updated? t)
  (cond ((tree-atomic? t) #t)
        ((tree-is? t 'calc-ref)
         (let* ((var (texmacs->string (tree-ref t 0))))
           (not (ahash-ref calc-invalid var))))
        (else (list-and (map calc-updated? (tree-children t))))))

(tm-define (calc-update-inputs t)
  (cond ((tree-atomic? t) (noop))
        ((tree-in? t '(calc-input))
         (let* ((var (texmacs->string (tree-ref t 0)))
                (old-val (ahash-ref calc-table var))
                (new-val (tree->stree (tree-ref t 1))))
           (when (!= new-val old-val)
             (ahash-set! calc-table var new-val)
             (ahash-set! calc-invalid var #t))))
        ((tree-in? t '(calc-output calc-formula))
         (let* ((var (texmacs->string (tree-ref t 0)))
                (formula-tree (tree-ref t 2))
                (formula (tree->stree formula-tree))
                (out (tree->stree (tree-ref t 1))))
           (when (or (!= (ahash-ref calc-table var) out)
                     (!= (ahash-ref calc-formula var) formula)
                     (not (calc-updated? formula-tree)))
             (ahash-set! calc-invalid var #t)
             (ahash-set! calc-formula var formula)
             (ahash-set! calc-todo var t))))
        (else (for-each calc-update-inputs (tree-children t)))))

(tm-define (calc-repeat-update-inputs t)
  (with n (ahash-size calc-invalid)
    (calc-update-inputs t)
    (when (!= n (ahash-size calc-invalid))
      (calc-repeat-update-inputs t))))

(tm-define (calc-available? t)
  (cond ((tree-atomic? t) #t)
        ((tree-is? t 'calc-ref)
         (let* ((var (texmacs->string (tree-ref t 0))))
           (not (ahash-ref calc-todo var))))
        (else (list-and (map calc-available? (tree-children t))))))

(tm-define (calc-substitute t)
  (cond ((tree-atomic? t) t)
        ((tree-is? t 'calc-ref)
         (let* ((var (texmacs->string (tree-ref t 0))))
           (or (ahash-ref calc-table var) t)))
        (else (apply tree
                     (cons (tree-label t)
                           (map calc-substitute (tree-children t)))))))

(tm-define (calc-reevaluate-output t)
  (when (calc-available? (tree-ref t 2))
    ;;(display* "Reevaluate output " t "\n")
    ;;(display* "src= " (calc-substitute (tree-ref t 2)) "\n")
    (let* ((var (texmacs->string (tree-ref t 0)))
           (src (texmacs->code (calc-substitute (tree-ref t 2))))
           (dest (object->string (eval (string->object src)))))
      ;;(display* "var= " var "\n")
      ;;(display* "src= " src "\n")
      ;;(display* "dest= " dest "\n")
      (ahash-set! calc-table var dest)
      (ahash-remove! calc-todo var)
      (tree-set t 1 dest))))

(tm-define (calc-reevaluate-output t)
  (when (calc-available? (tree-ref t 2))
    ;;(display* "Reevaluate output " t "\n")
    ;;(display* "src= " (calc-substitute (tree-ref t 2)) "\n")
    (let* ((var (texmacs->string (tree-ref t 0)))
           (in (tm->tree (calc-substitute (tree-ref t 2))))
           (out (tree-ref t 1)))
      ;;(display* "var= " var "\n")
      ;;(display* "src= " src "\n")
      ;;(display* "dest= " dest "\n")
      (ahash-set! calc-table var dest)
      (ahash-remove! calc-todo var)
      (tree-set t 1 dest))))

(tm-define (calc-repeat-reevaluate-outputs)
  (with n (ahash-size calc-todo)
    (for (p (ahash-table->list calc-todo))
      (calc-reevaluate-output (cdr p)))
    (when (!= n (ahash-size calc-todo))
      (calc-repeat-reevaluate-outputs))))

(tm-define (calc-reevaluate t)
  (calc-repeat-update-inputs t)
  (calc-repeat-reevaluate-outputs)
  (set! calc-invalid (make-ahash-table))
  (set! calc-todo (make-ahash-table)))

(tm-define (calc-scheme)
  (calc-reevaluate (buffer-tree)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Communication with the plug-in
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (calc-feed var in out)
  (let* ((lan (get-init "prog-scripts"))
	 (ses (get-init "prog-session")))
    (when (supports-scripts? lan)
      (tree-set! out '(script-busy))
      ;;(display* "Calc " var ", " lan ", " ses "\n")
      ;;(display* "Feed " in "\n")
      ;;(display* "Wait " out "\n")
      (with ptr (tree->tree-pointer out)
        (with ret (lambda (r)
                    ;;(display* "r= " r "\n")
                    (with check (tree-pointer->tree ptr)
                      (tree-pointer-detach ptr)
                      (when (== check out)
                        (tree-set out r)
                        (ahash-set! calc-table var (tm->stree r))
                        (ahash-remove! calc-todo var)
                        (delayed (calc-continue)))))
          (silent-feed* lan ses in ret '(:simplify-output)))))))

(tm-define (calc-continue-with t)
  (let* ((var (texmacs->string (tree-ref t 0)))
         (in (tm->tree (calc-substitute (tree-ref t 2))))
         (out (tree-ref t 1)))
    (calc-feed var in out)))

(tm-define (calc-continue-first l)
  (cond ((null? l)
         (set! calc-invalid (make-ahash-table))
         (set! calc-todo (make-ahash-table)))
        ((calc-available? (tree-ref (cdar l) 2))
         (calc-continue-with (cdar l)))
        (else
         (calc-continue-first (cdr l)))))

(tm-define (calc-continue)
  (with n (ahash-size calc-todo)
    (if (== n 0)
        (set! calc-invalid (make-ahash-table))
        (calc-continue-first (ahash-table->list calc-todo)))))

(tm-define (calc)
  (calc-repeat-update-inputs (buffer-tree))
  (calc-continue))

(tm-define (alternate-toggle t)
  (:require (tree-is? t 'calc-output))
  (tree-assign-node t 'calc-formula)
  (tree-go-to t 2 :end))

(tm-define (alternate-toggle t)
  (:require (tree-is? t 'calc-formula))
  (tree-assign-node t 'calc-output)
  (tree-go-to t 1 :end)
  (calc))

(tm-define (kbd-enter t forwards?)
  (:require (tree-in? t '(calc-input)))
  (calc))

(tm-define (kbd-enter t forwards?)
  (:require (tree-in? t '(calc-output calc-formula)))
  (alternate-toggle t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Spreadsheets in tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define calc-rename-table (make-ahash-table))

(tm-define (calc-rename-formulas t)
  (cond ((tree-atomic? t) (noop))
        ((tree-in? t '(calc-ref))
         (with var (texmacs->string (tree-ref t 0))
           (with new (ahash-ref calc-rename-table var)
             (when new
               (tree-set t 0 new)))))
        (else (for-each calc-rename-formulas (tree-children t)))))

(tm-define (cell-row cell)
  (and (tree-is? cell 'cell)
       (tree-is? cell :up 'row)
       (+ (tree-index (tree-up cell)) 1)))

(tm-define (cell-column cell)
  (and (tree-is? cell 'cell)
       (+ (tree-index cell) 1)))

(tm-define (number->row r)
  (if (< r 27)
      (list->string (list (integer->char (+ r 96))))
      (string-append (number->row (quotient r 26))
                     (number->row (+ (modulo (- r 1) 26) 1)))))

(tm-define (cell-name cell)
  (and-with r (cell-row cell)
    (and-with c (cell-column cell)
      (string-append (number->row r) (number->string c)))))

(tm-define (calc-table-rename-cell cell)
  ;;(display* "Renaming " cell "\n")
  (with s (cell-name cell)
    (with body (tree-ref cell 0)
      (when (tree-in? body '(calc-input calc-output calc-formula))
        (with id (tree->string (tree-ref body 0))
          (if (!= s id) (ahash-set! calc-rename-table id s))
          (tree-set body 0 s))))))

(tm-define (calc-table-update-cell cell)
  ;;(display* "Updating " cell "\n")
  (with s (cell-name cell)
    (with body (tree-ref cell 0)
      (when (not (tree-in? body '(calc-input calc-output calc-formula)))
        (tree-insert-node! body 1 `(calc-input ,s))))))

(tm-define (calc-table-update)
  (with-innermost t 'calc-table
    (let* ((tid (tree->string (tree-ref t 0)))
           (cells (select t '(1 :* table :* row :* cell))))
      ;;(display* "Cells: " cells "\n")
      (set! calc-rename-table (make-ahash-table))
      (for-each calc-table-rename-cell cells)
      ;;(display* "Renaming formulas\n")
      (calc-rename-formulas (buffer-tree))
      (set! calc-rename-table (make-ahash-table))
      ;;(display* "Updating cells\n")
      (for-each calc-table-update-cell cells))))

(tm-define (make-calc-table)
  (insert-go-to '(calc-table "" "") '(1 0))
  (make 'block)
  (calc-table-update))
