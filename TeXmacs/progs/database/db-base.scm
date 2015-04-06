
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : db-base.scm
;; DESCRIPTION : TeXmacs databases
;; COPYRIGHT   : (C) 2015  Joris van der Hoeven
;;
;; This software falls under the GNU general public license version 3 or later.
;; It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
;; in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (database db-base))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Execution of SQL commands
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (global-database)
  (url-concretize "$TEXMACS_HOME_PATH/server/global.tmdb"))

(tm-define current-database (url-none))

(tm-define-macro (with-database db . body)
  `(with-global current-database ,db ,@body))

(tm-define (db-reset)
  (set! current-database (url-none)))

(define db-previous-db #f)

(tm-define (db-init-database)
  (when (!= current-database db-previous-db)
    (when (url-none? current-database)
      (texmacs-error "db-init-database" "no database specified"))
    (when (not (url-exists? current-database))
      ;;(display* "Create " (url->string current-database) "\n")
      (sql-exec current-database
                (string-append "CREATE TABLE props ("
                               "id text, attr text, val text, "
                               "created integer, expires integer)"))
      (sql-exec current-database
                (string-append "CREATE TABLE matches ("
                               "id text, attr text, key text)"))
      (sql-exec current-database
                (string-append "CREATE TABLE matches_count ("
                               "key text, count integer)"))
      (sql-exec current-database
                (string-append "CREATE TABLE scores ("
                               "id text, key text, score integer)"))
      (sql-exec current-database
                (string-append "CREATE TABLE scores_count ("
                               "key text, count integer)"))
      (sql-exec current-database
                (string-append "CREATE TABLE prefixes ("
                               "prefix text, key text)"))
      (sql-exec current-database
                (string-append "CREATE TABLE prefixes_count ("
                               "prefix text, count integer)"))
      (sql-exec current-database
                (string-append "CREATE TABLE completions ("
                               "prefix text, key text)"))
      (sql-exec current-database
                (string-append "CREATE TABLE completions_count ("
                               "prefix text, count integer)")))
    (set! db-previous-db current-database)))        

(define db-pending #f)

(tm-define (db-sql-start-transaction)
  (when db-pending (sql-end-transaction))
  (set! db-pending (list)))

(tm-define (db-sql-end-transaction)
  (when db-pending
    (let* ((p (reverse db-pending))
           (i (list-intersperse p (list "; ")))
           (a (apply append i)))
      (set! db-pending #f)
      ;;(display* "Transaction: " (apply string-append a) "\n")
      (apply db-sql-raw a))))

(tm-define-macro (db-transaction . body)
  `(begin
     (db-sql-start-transaction)
     ,@body
     (db-sql-end-transaction)))

(define (db-sql-raw . l)
  (db-init-database)
  ;;(display* (url->string (url-tail current-database)) "] "
  ;;(apply string-append l) "\n")
  (sql-exec current-database (apply string-append l)))

(tm-define (db-sql . l)
  (if db-pending
      (set! db-pending (cons l db-pending))
      (apply db-sql-raw l)))

(tm-define (db-sql* . l)
  (with r (apply db-sql-raw l)
    (with f (lambda (x) (and (pair? x) (car x)))
      (map f (if (null? r) r (cdr r))))))

(tm-define (db-sql-date)
  (if (url-none? current-database)
      (current-time)
      (with r (db-sql-raw "SELECT strftime('%s','now')")
        (if (and (list-2? r) (list-1? (cadr r)) (string? (caadr r)))
            (caadr r)
            (texmacs-error "db-sql-date" "could not retrieve date")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Extra context
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define db-time "strftime('%s','now')")
(tm-define db-time-stamp? #f)
(tm-define db-extra-fields (list))
(tm-define db-limit #f)

(tm-define-macro (with-time t . body)
  `(with-global db-time (db-decode-time ,t) ,@body))

(tm-define-macro (with-time-stamp on? . body)
  `(with-global db-time-stamp? ,on? ,@body))

(tm-define-macro (with-extra-fields l . body)
  `(with-global db-extra-fields (append db-extra-fields ,l) ,@body))

(tm-define-macro (with-limit limit . body)
  `(with-global db-limit ,limit ,@body))

(tm-define (db-reset)
  (former)
  (set! db-time "strftime('%s','now')")
  (set! db-time-stamp? #f)
  (set! db-extra-fields (list))
  (set! db-limit #f))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Time and limit constraints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (db-decode-time t)
  (cond ((== t :now)
         "strftime('%s','now')")
        ((integer? t)
         (number->string t))
        ((string? t)
         (string-append "strftime('%s'," (sql-quote t) ")"))
        ((and (func? t :relative 1) (string? (cadr t)))
         (string-append "strftime('%s','now'," (sql-quote (cadr t)) ")"))
        ((and (func? t :sql 1) (string? (cadr t)))
         (cadr t))
        (else (texmacs-error "sql-time" "invalid time"))))

(define (db-time-constraint)
  (string-append "created <= (" db-time ") AND "
                 "expires >  (" db-time ")"))

(define (db-time-constraint-on x)
  (string-append x ".created <= (" db-time ") AND "
                 x ".expires >  (" db-time ")"))

(define (db-check-now)
  (when (!= db-time "strftime('%s','now')")
    (texmacs-error "db-check-now" "cannot rewrite history")))

(define (db-limit-constraint)
  (if db-limit (string-append " LIMIT " (number->string db-limit)) ""))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Basic private interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (db-insert-value id attr val)
  (db-check-now)
  (db-sql "INSERT INTO props VALUES (" (sql-quote id)
          ", " (sql-quote attr)
          ", " (sql-quote val)
          ", strftime('%s','now')"
          ", 10675199166)"))

(define (db-insert-time-stamp id)
  (db-check-now)
  (db-sql "INSERT INTO props VALUES (" (sql-quote id)
          ", 'date'"
          ", strftime('%s','now')"
          ", strftime('%s','now')"
          ", 10675199166)"))

(define (db-remove-value id attr val)
  (db-check-now)
  (db-sql "UPDATE props SET expires=strftime('%s','now')"
          " WHERE id=" (sql-quote id)
          " AND attr=" (sql-quote attr)
          " AND val=" (sql-quote val)
          " AND " (db-time-constraint)))

(define (db-remove-field id attr)
  (db-check-now)
  (db-sql "UPDATE props SET expires=strftime('%s','now')"
          " WHERE id=" (sql-quote id)
          " AND attr=" (sql-quote attr)
          " AND " (db-time-constraint)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Basic public interface
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (db-get-field id attr)
  (db-sql* "SELECT DISTINCT val FROM props WHERE id=" (sql-quote id)
           " AND attr=" (sql-quote attr)
           " AND " (db-time-constraint)))

(tm-define (db-get-field-first id attr default)
  (with l (db-get-field id attr)
    (if (null? l) default (car l))))

(tm-define (db-set-field id attr vals)
  (with old-vals (db-get-field id attr)
    (when (!= vals old-vals)
      (db-transaction
        (db-remove-field id attr)
        (for-each (cut db-insert-value id attr <>) vals)))))

(tm-define (db-get-attributes id)
  (db-sql* "SELECT DISTINCT attr FROM props WHERE id=" (sql-quote id)
           " AND " (db-time-constraint)))

(tm-define (db-get-entry id)
  (with r (db-sql "SELECT DISTINCT attr, val FROM props"
                  " WHERE id=" (sql-quote id)
                  " AND " (db-time-constraint)
                  " ORDER BY attr ASC")
    (if (nnull? r) (set! r (cdr r)))
    (let* ((t (make-ahash-table))
           (attrs (list-remove-duplicates (map car r))))
      (for (line r)
        (with (attr val) line
          (with old (or (ahash-ref t attr) (list))
            (ahash-set! t attr (cons val old)))))
      (map (lambda (attr) (cons attr (reverse (ahash-ref t attr)))) attrs))))

(tm-define (assoc-add l1 l2)
  (append l1 (list-filter l2 (lambda (x) (not (assoc-ref l1 (car x)))))))

(tm-define (db-set-entry id l)
  (let* ((old-l (db-get-entry id))
	 (new-l (assoc-add db-extra-fields l))
         (old-attrs (map car old-l))
         (new-attrs (map car new-l))
         (rem-attrs (list-difference old-attrs new-attrs)))
    (db-transaction
      (for (attr rem-attrs)
        (db-remove-field id attr))
      (for (attr new-attrs)
        (when (!= (assoc-ref new-l attr) (assoc-ref old-l attr))
          (db-remove-field id attr)
          (for-each (cut db-insert-value id attr <>) (assoc-ref new-l attr))))
      (when (and db-time-stamp? (nin? "date" new-attrs))
        (db-remove-field id "date")
        (db-insert-time-stamp id)))))

(tm-define (db-create-id)
  (if (url-none? current-database)
      (create-unique-id)
      (with id (create-unique-id)
        (while (nnull? (db-get-attributes id))
          (set! id (create-unique-id)))
        id)))

(tm-define (db-create-entry l)
  (with id (db-create-id)
    (db-set-entry id l)
    id))

(tm-define (db-remove-entry id)
  (db-check-now)
  (db-sql "UPDATE props SET expires=strftime('%s','now')"
          " WHERE id=" (sql-quote id)
          " AND " (db-time-constraint)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Searching database entries
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (db-search-table query i)
  (string-append "props AS p" (number->string i)))

(define (db-search-join l)
  (with ss (map db-search-table l (... 1 (length l)))
    (apply string-append (list-intersperse ss " JOIN "))))

(define (db-search-value pi vals)
  (cond ((null? vals)
         (texmacs-error "db-search-value" "invalid search value"))
        ((null? (cdr vals))
         (string-append pi ".val=" (sql-quote (car vals))))
        (else
          (let* ((qvals (map sql-quote vals))
                 (iqvals (list-intersperse qvals ", "))
                 (a (apply string-append iqvals)))
            (string-append pi ".val IN (" a ")")))))

(tm-define (db-search-constraint query i)
  (cond ((and (list? query) (pair? query) (list-and (map string? query)))
         (with (attr . vals) query
           (let* ((pi (string-append "p" (number->string i)))
                  (sattr (string-append pi ".attr=" (sql-quote attr))))
             (string-append sattr " AND "
                            (db-search-value pi vals) " AND "
                            (db-time-constraint-on pi)))))
        ((func? query :order 2)
         (with (tag attr dir) query
           (with pi (string-append "p" (number->string i))
             (string-append pi ".attr=" (sql-quote attr)))))
        (else "1")))

(define (db-search-constraint* query i)
  (let* ((pi (string-append "p" (number->string i)))
         (sid (string-append pi ".id=p1.id"))
         (c (db-search-constraint query i)))
    (cond ((= i 1) c)
          ((== c "1") sid)
          (else (string-append sid " AND " c)))))

(define (db-search-on l)
  (with ss (map db-search-constraint* l (... 1 (length l)))
    (apply string-append (list-intersperse ss " AND "))))

(define (db-search-col query i)
  (if (not (func? query :order 2)) ""
      (string-append "p" (number->string i) ".val")))

(define (db-search-cols pre l)
  (let* ((cols* (map db-search-col l (... 1 (length l))))
         (cols (list-filter cols* (cut != <> "")))
         (ss (list-intersperse (append pre cols) ", ")))
    (apply string-append ss)))

(define (db-search-order l)
  (with cols (db-search-cols (list) l)
    (if (== cols "") ""
        (let* ((i (list-find-index l (cut func? <> :order)))
               (asc (caddr (list-ref l i)))
               (asc? (if (string? asc) (== asc "#t") asc))
               (dir (if asc? "ASC" "DESC")))
          (string-append " ORDER BY " cols " " dir)))))

(tm-define (db-search l)
  (if (null? l)
      (db-sql* "SELECT DISTINCT id FROM props"
               " WHERE " (db-time-constraint) (db-limit-constraint))
      (let* ((join (db-search-join l))
             (on (db-search-on l))
             (cols (db-search-cols (list "p1.id") l))
             (order (db-search-order l))
             (sep (if (null? (cdr l)) " WHERE " " ON ")))
        (db-sql* "SELECT DISTINCT " cols
                 " FROM " join sep on order
                 (db-limit-constraint)))))

(tm-define (db-search-name name)
  (db-search (list (list "name" name))))

(tm-define (db-search-owner owner)
  (db-search (list (list "owner" owner))))
