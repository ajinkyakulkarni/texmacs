
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : chat-edit.scm
;; DESCRIPTION : editing routines for chatting
;; COPYRIGHT   : (C) 2006  Joris van der Hoeven
;;
;; This software falls under the GNU general public license and comes WITHOUT
;; ANY WARRANTY WHATSOEVER. See the file $TEXMACS_PATH/LICENSE for details.
;; If you don't have this file, write to the Free Software Foundation, Inc.,
;; 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (dynamic chat-edit)
  (:use (utils library tree)
	(utils library cursor)
	(utils remote client)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Basic subroutines for chatting
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define chat-connected (make-ahash-table))

(tm-define (chat-session)
  (:synopsis "Get the current chat session tree.")
  (tree-innermost 'chat-session))

(tm-define (chat-input)
  (and-with session (chat-session)
    (with last (tm-ref session 1 :last)
      (and (tree-is? last 'chat-input) last))))

(tm-define (chat-field)
  (or (tree-innermost 'chat-input)
      (tree-innermost 'chat-output)))

(tm-define (chat-room)
  (and-with session (chat-session)
    (tree->string (tree-ref session 0))))

(tm-define (chat-user)
  (and-with input (chat-input)
    (tree->string (tree-ref input 0))))

(tm-define (chat-user*)
  (and-with field (chat-field)
    (tree->string (tree-ref field 0))))

(tm-define (chat-connected?)
  (:synopsis "Are we inside a session and connected?")
  (and-with room (chat-room)
    (and-with user (chat-user)
      (ahash-ref chat-connected (cons room user)))))

(define (chat-convert field)
  (with (nr user contents) field
    `(chat-output ,user ,(stree->tree contents))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Routines for chatting
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (chat-connect user room)
  (:synopsis "Connect to a chat room.")
  (:argument room "Chat room")
  (:argument user "User name")
  (when (and (not (chat-session))
	     (not (ahash-ref chat-connected (cons user room))))
    (let* ((new (remote-request `(chat-connect ,room ,user)))
	   (cmd (string-append "(mutate-chat \"" room "\" \"" user "\")"))
	   (out (map chat-convert new))
	   (in `(chat-input ,user (document ""))))
      (init-add-package "chat")
      (ahash-set! chat-connected (cons room user) #t)
      (insert-go-to `(mutator (chat-session ,room (document ,@out ,in)) ,cmd)
		    (list 0 1 (length new) 1 0 0)))))

(tm-define (chat-catch-up)
  (:synopsis "Catch up with the discussion.")
  (and-let* ((room (chat-room))
	     (user (chat-user))
	     (session (chat-session))
	     (ok (not (chat-connected?))))
    (remote-request `(chat-connect ,room ,user))
    (ahash-set! chat-connected (cons room user) #t)
    (tree-go-to session 1 :last 1 :end)))

(tm-define (chat-hang-up)
  (:synopsis "Quit the chat room.")
  (and-let* ((room (chat-room))
	     (user (chat-user))
	     (ok (chat-connected?)))
    (remote-request `(chat-hang-up ,room ,user))
    (ahash-remove! chat-connected (cons room user))))

(tm-define (kbd-return)
  (:inside chat-input)
  (and-let* ((room (chat-room))
	     (user (chat-user))
	     (input (chat-input))
	     (emit (tree->stree (tree-ref input 1)))
	     (ok (chat-connected?)))
    (tree-assign (tree-ref input 1) '(document ""))
    (remote-request `(chat-emit ,room ,user ,emit))))

(tm-define (kbd-return)
  (:inside chat-output)
  (and-let* ((room (chat-room))
	     (user (chat-user*))
	     (field (chat-field))
	     (nr (tree-index field))
	     (emit (tree->stree (tree-ref field 1)))
	     (ok (and (chat-connected?) (== user (chat-user)))))
    (remote-request `(chat-update ,room ,user ,nr ,emit))))

(define (chat-update t field)
  ;;(display* "Update " field "\n")
  (with (nr user contents) field
    (while (>= nr (- (tree-arity t) 1))
      (tree-insert! t (- (tree-arity t) 1) '(document "")))
    (tree-assign (tree-ref t nr) (chat-convert field))))

(tm-define (mutate-chat room user)
  (:secure #t)
  (when (ahash-ref chat-connected (cons room user))
    ;;(display* "Synchronize " room ", " user "\n")
    (with new (remote-request `(chat-synchronize ,room ,user))
      (if (nnull? new)
	  (with-mutator t
	    (for-each (lambda (x) (chat-update (tree-ref t 1) x)) new))))))
