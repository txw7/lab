(in-package :mini-kernel)

(defstruct core-smt-obligation
  id
  label
  (logic :qf_lia)
  query
  (assertions '())
  expected-status
  source-ref
  metadata)

(defstruct core-smt-module
  id
  source-path
  (logic :unknown)
  (obligations '())
  metadata)

(defun %core-smt-copy-smtlib-env (env)
  (let ((copy (make-hash-table :test #'eq)))
    (maphash (lambda (key value)
               (setf (gethash key copy) value))
             env)
    copy))

(defun %current-core-smt-assertions (stack)
  (if stack
      (first stack)
      (kernel-error "empty CoreSMT assertion stack")))

(defun %core-smt-conjoin-assertions (assertions)
  (cond
    ((null assertions) (smt-bool-const t))
    ((null (rest assertions)) (first assertions))
    (t (apply #'smt-and (reverse assertions)))))

(defun smt-spec->core-smt-module (spec)
  (make-core-smt-module
   :id (smt-spec-id spec)
   :source-path (smt-spec-source-path spec)
   :logic (smt-spec-logic spec)
   :metadata (list :semantic-tags (smt-spec-semantic-tags spec)
                   :source :native-spec)
   :obligations
   (mapcar (lambda (obligation)
             (make-core-smt-obligation
              :id (smt-obligation-id obligation)
              :label (smt-obligation-label obligation)
              :logic (smt-obligation-logic obligation)
              :query (compile-smt-obligation obligation)
              :assertions (copy-list (smt-obligation-assumptions obligation))
              :expected-status (or (smt-obligation-expected-status obligation)
                                   (case (smt-obligation-polarity obligation)
                                     (:prove-unsat :rejected)
                                     (:find-sat :accepted)
                                     (otherwise nil)))
              :source-ref (smt-obligation-source-ref obligation)
              :metadata (list :semantic-tags (smt-obligation-semantic-tags obligation)
                              :unknown-policy (smt-obligation-unknown-policy obligation)
                              :source :native-spec)))
           (smt-spec-obligations spec))))

(defun smtlib-forms->core-smt-module (forms &key source-path module-id)
  (let ((env (make-hash-table :test #'eq))
        (stack (list '()))
        (current-label nil)
        (current-logic :unknown)
        (counter 0)
        (obligations '()))
    (dolist (form forms)
      (cond
        ((smtlib-symbol= (first form) "SET-LOGIC")
         (setf current-logic
               (intern (string-upcase (symbol-name (second form))) :keyword)))
        ((smtlib-symbol= (first form) "DECLARE-CONST")
         (setf (gethash (second form) env)
               (%make-smtlib-const-entry
                (smtlib-sort->sort (third form)))))
        ((smtlib-symbol= (first form) "DECLARE-FUN")
         (unless (null (third form))
           (kernel-error "only nullary DECLARE-FUN is supported in CoreSMT ingestion: ~S"
                         form))
         (setf (gethash (second form) env)
               (%make-smtlib-const-entry
                (smtlib-sort->sort (fourth form)))))
        ((smtlib-symbol= (first form) "DEFINE-FUN")
         (let ((name (second form))
               (params (third form))
               (result-sort (smtlib-sort->sort (fourth form)))
               (body (fifth form)))
           (setf (gethash name env)
                 (%make-smtlib-define-entry
                  (mapcar (lambda (param)
                            (list (first param)
                                  (smtlib-sort->sort (second param))))
                          params)
                  result-sort
                  body))))
        ((smtlib-symbol= (first form) "ASSERT")
         (push (smtlib-term->ast (second form) env (smt-bool-sort))
               (first stack)))
        ((smtlib-symbol= (first form) "ECHO")
         (setf current-label (second form)))
        ((smtlib-symbol= (first form) "PUSH")
         (push (copy-list (%current-core-smt-assertions stack)) stack))
        ((smtlib-symbol= (first form) "POP")
         (when (null (rest stack))
           (kernel-error "CoreSMT pop underflow"))
         (pop stack))
        ((smtlib-symbol= (first form) "CHECK-SAT")
         (incf counter)
         (push (make-core-smt-obligation
                :id (or current-label counter)
                :label current-label
                :logic current-logic
                :query (%core-smt-conjoin-assertions (%current-core-smt-assertions stack))
                :assertions (reverse (copy-list (%current-core-smt-assertions stack)))
                :source-ref source-path
                :metadata (list :source :smtlib-import
                                :env-size (hash-table-count env)))
               obligations))
        ((or (smtlib-symbol= (first form) "GET-MODEL")
             (smtlib-symbol= (first form) "GET-UNSAT-CORE"))
         nil)
        (t
         (kernel-error "unsupported SMT-LIB command in CoreSMT ingestion: ~S" form))))
    (make-core-smt-module
     :id (or module-id source-path (gensym "CORE-SMT-MODULE-"))
     :source-path source-path
     :logic current-logic
     :obligations (nreverse obligations)
     :metadata (list :source :smtlib-import))))

(defun smtlib-file->core-smt-module (path)
  (smtlib-forms->core-smt-module (read-smtlib-forms path)
                                 :source-path path
                                 :module-id path))

(defun check-core-smt-module (module)
  (mapcar (lambda (obligation)
            (let* ((result (run-smt-check (make-advisory-store)
                                          (core-smt-obligation-query obligation)))
                   (actual (backend-result-status result))
                   (expected (core-smt-obligation-expected-status obligation)))
              (list :id (core-smt-obligation-id obligation)
                    :label (core-smt-obligation-label obligation)
                    :query (core-smt-obligation-query obligation)
                    :expected-status expected
                    :actual-status actual
                    :matchedp (or (null expected) (eq expected actual))
                    :result result)))
          (core-smt-module-obligations module)))

(defun %canonicalize-core-smt-term (term)
  (cond
    ((atom term) term)
    ((eq (first term) :var)
     (list :var
           (etypecase (second term)
             (symbol (string-upcase (symbol-name (second term))))
             (string (string-upcase (second term)))
             (t (second term)))
           (third term)))
    (t
     (mapcar #'%canonicalize-core-smt-term term))))

(defun compare-core-smt-modules (lhs rhs)
  (let ((lhs-obligations (core-smt-module-obligations lhs))
        (rhs-obligations (core-smt-module-obligations rhs)))
    (list
     :lhs-id (core-smt-module-id lhs)
     :rhs-id (core-smt-module-id rhs)
     :same-length-p (= (length lhs-obligations) (length rhs-obligations))
     :entries
     (mapcar (lambda (left right)
               (let ((left-query (%canonicalize-core-smt-term
                                  (normalize-smt-term (core-smt-obligation-query left))))
                     (right-query (%canonicalize-core-smt-term
                                   (normalize-smt-term (core-smt-obligation-query right)))))
                 (list :lhs-label (core-smt-obligation-label left)
                       :rhs-label (core-smt-obligation-label right)
                       :label-match-p (equal (core-smt-obligation-label left)
                                             (core-smt-obligation-label right))
                       :query-match-p (equal left-query right-query)
                       :expected-status-match-p
                       (equal (core-smt-obligation-expected-status left)
                              (core-smt-obligation-expected-status right))
                       :lhs-query left-query
                       :rhs-query right-query)))
             lhs-obligations
             rhs-obligations))))
