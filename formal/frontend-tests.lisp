(defpackage :mini-kernel-frontend-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-frontend-tests)

(define-condition test-failure (error)
  ((message :initarg :message :reader test-failure-message))
  (:report (lambda (condition stream)
             (princ (test-failure-message condition) stream))))

(defun fail-test (format-string &rest args)
  (error 'test-failure :message (apply #'format nil format-string args)))

(defmacro is-equal (expected form)
  `(let ((expected-value ,expected)
         (actual-value ,form))
     (unless (equal expected-value actual-value)
       (fail-test "expected ~S, got ~S from ~S"
                  expected-value
                  actual-value
                  ',form))))

(defmacro is-true (form)
  `(unless ,form
     (fail-test "expected truthy form: ~S" ',form)))

(defmacro signals-frontend-error (form)
  `(handler-case
       (progn
         ,form
         (fail-test "expected frontend error from ~S" ',form))
     (mini-kernel::frontend-error () t)))

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun test-lower-bound-variable ()
  (is-equal '(:var 0)
            (mini-kernel:lower-term 'x '(x))))

(defun test-lower-free-symbol-as-const ()
  (is-equal '(:const mini-kernel::nat ())
            (mini-kernel:lower-term 'mini-kernel::nat)))

(defun test-lower-lambda-shadowing ()
  (is-equal
   '(:lam (:const mini-kernel::nat ())
     (:lam (:const mini-kernel::nat ())
      (:var 0)))
   (mini-kernel:lower-term
    '(:lam x mini-kernel::nat
      (:lam x mini-kernel::nat x)))))

(defun test-lower-dependent-pi ()
  (is-equal
   '(:pi (:const mini-kernel::nat ())
     (:app
      (:app
       (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
       (:var 0))
      (:var 0)))
   (mini-kernel:lower-term
    '(:pi n mini-kernel::nat
      (:app
       (:app
        (:app mini-kernel::eq mini-kernel::nat)
        n)
       n)))))

(defun test-lower-let ()
  (is-equal
   '(:let (:const mini-kernel::zero ())
     (:const mini-kernel::nat ())
     (:var 0))
   (mini-kernel:lower-term
    '(:let x mini-kernel::zero mini-kernel::nat x))))

(defun test-lower-nat-rec-shape ()
  (is-equal
   '(:app
     (:app
      (:app
       (:app (:const mini-kernel::nat-rec ())
        (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
       (:const mini-kernel::zero ()))
      (:lam (:const mini-kernel::nat ())
       (:lam
        (:app
         (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ()))
         (:var 0))
        (:app (:const mini-kernel::succ ()) (:var 0)))))
     (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
   (mini-kernel:lower-term
    '(:nat-rec
      (:app mini-kernel::succ mini-kernel::zero)
      (:lam n mini-kernel::nat mini-kernel::nat)
      mini-kernel::zero
      (k ih
       (:app mini-kernel::succ ih))))))

(defun test-lower-nat-rec-converts ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (lhs (mini-kernel:lower-term
               '(:nat-rec
                 (:app mini-kernel::succ mini-kernel::zero)
                 (:lam n mini-kernel::nat mini-kernel::nat)
                 mini-kernel::zero
                 (k ih
                  (:app mini-kernel::succ ih)))))
         (rhs (mini-kernel:lower-term
               '(:app mini-kernel::succ mini-kernel::zero))))
    (is-true (mini-kernel:conv? env '() lhs rhs))))

(defun test-lower-proof-term-and-check ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (term (mini-kernel:lower-term
                '(:lam n mini-kernel::nat
                  (:app
                   (:app mini-kernel::refl mini-kernel::nat)
                   n))))
         (type (mini-kernel:lower-term
                '(:pi n mini-kernel::nat
                  (:app
                   (:app
                    (:app mini-kernel::eq mini-kernel::nat)
                    n)
                   n)))))
    (is-true (mini-kernel:check env '() term type))))

(defun test-lower-add-example-converts ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (lhs (mini-kernel:lower-term
               '(:app
                 (:app mini-kernel::add mini-kernel::zero)
                 (:app mini-kernel::succ mini-kernel::zero))))
         (rhs (mini-kernel:lower-term
               '(:app mini-kernel::succ mini-kernel::zero))))
    (is-true (mini-kernel:conv? env '() lhs rhs))))

(defun test-compile-stage-surface-certificates ()
  (let* ((certificates
           (mini-kernel:compile-stage-surface-certificates
            '((:id :proof-demo
               :term (:lam n mini-kernel::nat
                      (:app
                       (:app mini-kernel::refl mini-kernel::nat)
                       n))
               :type (:pi n mini-kernel::nat
                      (:app
                       (:app
                        (:app mini-kernel::eq mini-kernel::nat)
                        n)
                       n))))
            :env (mini-kernel:make-bootstrap-env))))
    (is-equal 1 (length certificates))
    (is-equal :proof-demo
              (getf (mini-kernel:certificate-metadata (first certificates))
                    :certificate-id))))

(defun test-negative-unsupported-atom ()
  (signals-frontend-error
   (mini-kernel:lower-term 42)))

(defun test-negative-malformed-lam ()
  (signals-frontend-error
   (mini-kernel:lower-term '(:lam x mini-kernel::nat))))

(defun test-negative-malformed-nat-rec ()
  (signals-frontend-error
   (mini-kernel:lower-term
    '(:nat-rec mini-kernel::zero
      (:lam n mini-kernel::nat mini-kernel::nat)
      mini-kernel::zero
      (k ih)))))

(defun test-negative-stage-spec-missing-id ()
  (signals-frontend-error
   (mini-kernel:compile-stage-surface-certificates
    '((:term mini-kernel::zero
       :type mini-kernel::nat))
    :env (mini-kernel:make-bootstrap-env))))

(defun test-negative-stage-spec-missing-type ()
  (signals-frontend-error
   (mini-kernel:compile-stage-surface-certificates
    '((:id :bad
       :term mini-kernel::zero))
    :env (mini-kernel:make-bootstrap-env))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "lower-bound-variable" #'test-lower-bound-variable)
            (cons "lower-free-symbol-as-const" #'test-lower-free-symbol-as-const)
            (cons "lower-lambda-shadowing" #'test-lower-lambda-shadowing)
            (cons "lower-dependent-pi" #'test-lower-dependent-pi)
            (cons "lower-let" #'test-lower-let)
            (cons "lower-nat-rec-shape" #'test-lower-nat-rec-shape)
            (cons "lower-nat-rec-converts" #'test-lower-nat-rec-converts)
            (cons "lower-proof-term-and-check" #'test-lower-proof-term-and-check)
            (cons "lower-add-example-converts" #'test-lower-add-example-converts)
            (cons "compile-stage-surface-certificates" #'test-compile-stage-surface-certificates)
            (cons "negative-unsupported-atom" #'test-negative-unsupported-atom)
            (cons "negative-malformed-lam" #'test-negative-malformed-lam)
            (cons "negative-malformed-nat-rec" #'test-negative-malformed-nat-rec)
            (cons "negative-stage-spec-missing-id" #'test-negative-stage-spec-missing-id)
            (cons "negative-stage-spec-missing-type" #'test-negative-stage-spec-missing-type)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "frontend test suite failed"))
    t))
