
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : animate-edit.scm
;; DESCRIPTION : routines for editing animations
;; COPYRIGHT   : (C) 2016  Joris van der Hoeven
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (dynamic animate-edit)
  (:use (utils library tree)
        (utils library cursor)
        (dynamic dynamic-drd)
        (generic generic-edit)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Useful subroutines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (reset-players t)
  (players-set-elapsed t 0.0)
  (update-players (tree->path t) #t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Parameters for various animation tags
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'translate-in))
  (list (list "translate-start-x" "Start x")
        (list "translate-start-y" "Start y")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'translate-out))
  (list (list "translate-end-x" "End x")
        (list "translate-end-y" "End y")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'translate-smooth))
  (list (list "translate-start-x" "Start x")
        (list "translate-start-y" "Start y")
        (list "translate-end-x" "End x")
        (list "translate-end-y" "End y")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'progressive-in))
  (list (list "progressive-start-l" "Start left")
        (list "progressive-start-b" "Start bottom")
        (list "progressive-start-r" "Start right")
        (list "progressive-start-t" "Start top")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'progressive-out))
  (list (list "progressive-end-l" "End left")
        (list "progressive-end-b" "End bottom")
        (list "progressive-end-r" "End right")
        (list "progressive-end-t" "End top")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'progressive-smooth))
  (list (list "progressive-start-l" "Start left")
        (list "progressive-start-b" "Start bottom")
        (list "progressive-start-r" "Start right")
        (list "progressive-start-t" "Start top")
        (list "progressive-end-l" "End left")
        (list "progressive-end-b" "End bottom")
        (list "progressive-end-r" "End right")
        (list "progressive-end-t" "End top")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'fade-in))
  (list (list "fade-start" "Start intensity")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'fade-out))
  (list (list "fade-end" "End intensity")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'fade-smooth))
  (list (list "fade-start" "Start intensity")
        (list "fade-end" "End intensity")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'zoom-in))
  (list (list "zoom-start" "Start magnification")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'zoom-out))
  (list (list "zoom-end" "End magnification")))

(tm-define (customizable-parameters t)
  (:require (tree-is? t 'zoom-smooth))
  (list (list "zoom-start" "Start magnification")
        (list "zoom-end" "End magnification")))

(tm-define (customizable-parameters t)
  (:require (tree-in? t '(shadowed-smooth emboss-smooth
                          outlined-emboss-smooth)))
  (list (list "emboss-start-dx" "Start dx")
        (list "emboss-start-dy" "Start dy")
        (list "emboss-end-dx" "End dx")
        (list "emboss-end-dy" "End dy")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Time bending
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (anim-get-accelerate t)
  (cond ((not (tree? t)) #f)
        ((tree-is? t 'anim-accelerate) t)
        ((tree-is? t :up 'anim-accelerate) (tree-up t))
        ((and (tree-is? t :up 'with) (tree-is? t :up :up 'anim-accelerate))
         (tree-up (tree-up t)))
        ((and (tree-is? t :up 'with) (tree-in? t (animation-tag-list)))
         (tree-up t))
        ((tree-in? t (animation-tag-list)) t)
        (else #f)))

(tm-define (accelerate-get-type t)
  (and-with a (anim-get-accelerate t)
    (or (and (tree-func? a 'anim-accelerate 2)
             (tree->stree (tree-ref a 1)))
        "normal")))

(tm-define (accelerate-test-type? dummy new-type)
  (with t (tree-innermost 'anim-accelerate #t)
    (tm-equal? (accelerate-get-type t) new-type)))

(tm-define (accelerate-set-type t new-type)
  (:check-mark "*" accelerate-test-type?)
  (and-with a (anim-get-accelerate t)
    (if (tree-func? a 'anim-accelerate 2)
        (if (== new-type "normal")
            (tree-remove-node! a 0)
            (tree-set (tree-ref a 1) new-type))
        (if (!= new-type "normal")
            (tree-set! a `(anim-accelerate ,a ,new-type))))
    (reset-players a)))

(tm-define (accelerate-get-reverse? t)
  (and-with s (accelerate-get-type t)
    (string-starts? s "reverse")))

(tm-define (accelerate-test-reverse? dummy)
  (with t (tree-innermost 'anim-accelerate #t)
    (accelerate-get-reverse? t)))

(tm-define (accelerate-toggle-reverse? t)
  (:check-mark "*" accelerate-test-reverse?)
  (accelerate-set-type**
   t (accelerate-get-type* t) (not (accelerate-get-reverse? t))))

(tm-define (accelerate-get-type* t)
  (and-with s (accelerate-get-type t)
    (cond ((== s "reverse") "normal")
          ((string-starts? s "reverse-") (string-drop s 8))
          (else s))))

(tm-define (accelerate-test-type*? dummy new-type)
  (with t (tree-innermost 'anim-accelerate #t)
    (tm-equal? (accelerate-get-type* t) new-type)))

(define (accelerate-set-type** t new-type reverse?)
  (if reverse?
      (if (== new-type "normal")
          (accelerate-set-type t "reverse")
          (accelerate-set-type t (string-append "reverse-" new-type)))
      (accelerate-set-type t new-type)))

(tm-define (accelerate-set-type* t new-type)
  (:check-mark "*" accelerate-test-type*?)
  (accelerate-set-type** t new-type (accelerate-get-reverse? t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start and end editing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (user-anim-context? t)
  (tree-in? t '(anim-static anim-dynamic anim-edit)))

(define (checkout-animation t len)
  (cond ((tm-func? t 'gr-screen 1)
         (with (r p) (checkout-animation (tm-ref t 0) len)
           (list `(gr-screen ,r) (cons 0 p))))
        (else
          (with r (animate-checkout `(anim-static ,t ,len "0.1s" "0s"))
            (list r (cons 1 (path-start (tm-ref r 1) '())))))))

(tm-define (make-animate t len)
  (with (r p) (checkout-animation t len)
    (insert-go-to r p)))

(tm-define (animate-selection len)
  (:argument len "Duration")
  (with sel (selection-tree)
    (clipboard-cut "primary")
    (make-animate sel len)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Global duration and step length
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (anim-duration t)
  (cond ((tree-in? t '(anim-static anim-dynamic))
         (tree-ref t 1))
        ((tree-in? t '(anim-edit))
         (tree-ref t 2))
        (else #f)))

(tm-define (anim-set-duration t d)
  (and-with x (anim-portion t)
    (cond ((tree-in? t '(anim-static anim-dynamic))
           (tree-set! t 1 d))
          ((tree-in? t '(anim-edit))
           (tree-set! t 2 d)))
    (anim-set-portion t x)
    (reset-players t)))

(tm-define (anim-set-duration* d)
  (and-with t (tree-innermost user-anim-context? #t)
    (when d (anim-set-duration t d))))

(tm-define (anim-step t)
  (cond ((tree-in? t '(anim-static anim-dynamic))
         (tree-ref t 2))
        ((tree-in? t '(anim-edit))
         (tree-ref t 3))
        (else #f)))

(tm-define (anim-set-step t d)
  (cond ((tree-in? t '(anim-static anim-dynamic))
         (tree-set! t 2 d))
        ((tree-in? t '(anim-edit))
         (tree-set! t 3 d)))
  (reset-players t))

(tm-define (anim-set-step* d)
  (and-with t (tree-innermost user-anim-context? #t)
    (when d (anim-set-step t d))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Current animation frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (anim-now t)
  (cond ((tree-in? t '(anim-static anim-dynamic))
         (tree-ref t 3))
        ((tree-in? t '(anim-edit))
         (tree-ref t 4))
        (else #f)))

(tm-define (anim-set-now t now)
  (cond ((tree-in? t '(anim-static anim-dynamic))
         (tree-set! t 3 now))
        ((tree-in? t '(anim-edit))
         (with r (animate-commit t)
           (tree-set! t 0 (tree-ref r 0))
           (tree-set! t 4 now))
         (with r (animate-checkout `(anim-static ,(tree-ref t 0)
                                                 ,@(cddr (tm-children t))))
           (tree-set! t 0 (tree-ref r 0))
           (tree-set! t 1 (tree-ref r 1))
           (tree-go-to t 1 :start)))))

(tm-define (anim-set-now* x)
  (and-with t (tree-innermost user-anim-context? #t)
    (when x (anim-set-now t x))))

(define (get-ms t)
  (cond ((and (tree? t) (tree-atomic? t)) (get-ms (tree->string t)))
        ((not (string? t)) #f)
        ((string-ends? t "sec") (get-ms (string-drop-right t 2)))
        ((string-ends? t "ms") (string->number (string-drop-right t 2)))
        (else (* 1000 (string->number (string-drop-right t 1))))))

(tm-define (anim-portion t)
  (let* ((n (get-ms (anim-now t)))
         (d (get-ms (anim-duration t))))
    (and n d (/ (* 1.0 n) (* 1.0 d)))))

(tm-define (anim-set-portion t x)
  (and-with d (get-ms (anim-duration t))
    (when (number? x)
      (with n (inexact->exact (floor (+ (* x d) 0.5)))
        (anim-set-now t (string-append (number->string (* 0.001 n)) "s"))))))

(tm-define (anim-set-portion* x)
  (and-with t (tree-innermost user-anim-context? #t)
    (when x (anim-set-portion t x))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start and end editing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (anim-checkout t)
  (with r (animate-checkout t)
    (tree-assign-node! t (tree-label r))
    (tree-set! t 0 (tree-ref r 0))
    (tree-insert! t 1 (list (tree-ref r 1)))
    (tree-go-to t 1 :start)
    (set-bottom-bar "animate" #t)))

(tm-define (anim-checkout*)
  (and-with t (tree-innermost user-anim-context? #t)
    (anim-checkout t)))

(tm-define (anim-commit t)
  (with r (animate-commit t)
    (tree-set! t 0 (tree-ref r 0))
    (tree-remove! t 1 1)
    (tree-assign-node! t (tree-label r))
    (tree-go-to t :end)
    (reset-players t)))

(tm-define (anim-commit*)
  (and-with t (tree-innermost user-anim-context? #t)
    (anim-commit t)))
