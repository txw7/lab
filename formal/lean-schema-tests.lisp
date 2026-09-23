(defpackage :mini-kernel-lean-schema-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-lean-schema-tests)

(define-condition test-failure (error)
  ((message :initarg :message :reader test-failure-message))
  (:report (lambda (condition stream)
             (princ (test-failure-message condition) stream))))

(defun fail-test (format-string &rest args)
  (error 'test-failure :message (apply #'format nil format-string args)))

(defmacro is-true (form)
  `(unless ,form
     (fail-test "expected truthy form: ~S" ',form)))

(defmacro is-equal (expected form)
  `(let ((expected-value ,expected)
         (actual-value ,form))
     (unless (equal expected-value actual-value)
       (fail-test "expected ~S, got ~S from ~S"
                  expected-value
                  actual-value
                  ',form))))

(defmacro signals-kernel-error (form)
  `(handler-case
       (progn
         ,form
         (fail-test "expected kernel error from ~S" ',form))
     (mini-kernel::kernel-error () t)))

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun test-schema-catalog ()
  (let ((schema (mini-kernel:find-lean-theorem-schema :declarativecore-weakening)))
    (is-true schema)
    (is-equal "Formal.DeclarativeCore" (mini-kernel:lean-theorem-schema-module schema))
    (is-equal "weakening" (mini-kernel:lean-theorem-schema-name schema))
    (is-equal :axiom (mini-kernel:lean-theorem-schema-source-kind schema))
    (is-equal :jd-weakening (mini-kernel:lean-theorem-schema-obligation-id schema)))
  (is-equal 4 (length (mini-kernel:list-lean-theorem-schemas))))

(defun test-instantiate-weakening-statement ()
  (let* ((gamma '())
         (a '(:const mini-kernel::nat ()))
         (term '(:const mini-kernel::zero ()))
         (type '(:const mini-kernel::nat ()))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-weakening
            :gamma gamma
            :a a
            :term term
            :type type)))
    (is-equal :declarativecore-weakening (mini-kernel:theorem-statement-id statement))
    (is-equal 1 (length (mini-kernel:theorem-statement-premises statement)))
    (is-equal
     (mini-kernel:proof-claim->proposition
      :j-d
      (mini-kernel:make-has-type-claim
       (list a)
       (mini-kernel:shift 1 0 term)
       (mini-kernel:shift 1 0 type)))
     (mini-kernel:theorem-statement-conclusion statement))))

(defun test-instantiate-substitution-statement ()
  (let* ((gamma '())
         (a '(:const mini-kernel::nat ()))
         (term '(:var 0))
         (type '(:const mini-kernel::nat ()))
         (replacement '(:const mini-kernel::zero ()))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-substitution
            :gamma gamma
            :a a
            :term term
            :type type
            :replacement replacement)))
    (is-equal 2 (length (mini-kernel:theorem-statement-premises statement)))
    (is-equal
     (mini-kernel:proof-claim->proposition
      :j-d
      (mini-kernel:make-has-type-claim
       gamma
       (mini-kernel:subst-top replacement term)
       (mini-kernel:subst-top replacement type)))
     (mini-kernel:theorem-statement-conclusion statement))))

(defun test-instantiate-subject-reduction-statement ()
  (let* ((gamma '())
         (term '(:app (:lam (:const mini-kernel::nat ()) (:var 0))
                 (:const mini-kernel::zero ())))
         (type '(:const mini-kernel::nat ()))
         (reduct '(:const mini-kernel::zero ()))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-subject-reduction
            :gamma gamma
            :term term
            :type type
            :reduct reduct)))
    (is-equal 2 (length (mini-kernel:theorem-statement-premises statement)))
    (is-equal
     (mini-kernel:proof-claim->proposition
      :j-d
      (mini-kernel:make-step-claim term reduct))
     (second (mini-kernel:theorem-statement-premises statement)))
    (is-equal
     (mini-kernel:proof-claim->proposition
      :j-d
     (mini-kernel:make-has-type-claim gamma reduct type))
     (mini-kernel:theorem-statement-conclusion statement))))

(defun test-instantiate-krcheck-sound-statement ()
  (let* ((gamma '())
         (term '(:const mini-kernel::zero ()))
         (type '(:const mini-kernel::nat ()))
         (statement
           (mini-kernel:instantiate-lean-theorem-statement
            :declarativecore-krcheck-sound
            :gamma gamma
            :term term
            :type type)))
    (is-equal :declarativecore-krcheck-sound
              (mini-kernel:theorem-statement-id statement))
    (is-equal
     (mini-kernel:proof-claim->proposition
      :j-kr
      (mini-kernel:make-has-type-claim gamma term type))
     (first (mini-kernel:theorem-statement-premises statement)))
    (is-equal
     (mini-kernel:proof-claim->proposition
      :j-d
      (mini-kernel:make-has-type-claim gamma term type))
     (mini-kernel:theorem-statement-conclusion statement))))

(defun test-missing-param-rejected ()
  (signals-kernel-error
   (mini-kernel:instantiate-lean-theorem-statement
    :declarativecore-weakening
    :gamma '()
    :a '(:const mini-kernel::nat ())
    :term '(:const mini-kernel::zero ()))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "schema-catalog" #'test-schema-catalog)
            (cons "instantiate-weakening-statement" #'test-instantiate-weakening-statement)
            (cons "instantiate-substitution-statement" #'test-instantiate-substitution-statement)
            (cons "instantiate-subject-reduction-statement"
                  #'test-instantiate-subject-reduction-statement)
            (cons "instantiate-krcheck-sound-statement"
                  #'test-instantiate-krcheck-sound-statement)
            (cons "missing-param-rejected" #'test-missing-param-rejected)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "test suite failed"))
    t))
