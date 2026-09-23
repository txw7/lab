(defpackage :mini-kernel-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-tests)

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

(defun test-shift-under-binder ()
  (is-equal '(:lam (:var 1) (:var 0))
            (mini-kernel:shift 1 0 '(:lam (:var 0) (:var 0)))))

(defun test-subst-top-beta-shape ()
  (is-equal '(:var 0)
            (mini-kernel:subst-top '(:var 0) '(:var 0)))
  (is-equal '(:lam (:const mini-kernel::nat ()) (:const mini-kernel::zero ()))
            (mini-kernel:subst-top '(:const mini-kernel::zero ())
                                   '(:lam (:const mini-kernel::nat ()) (:var 1)))))

(defun test-ctx-lookup-lifts-types ()
  (is-equal '(:sort 0)
            (mini-kernel::ctx-lookup '((:var 0) (:sort 0)) 1))
  (is-equal '(:var 1)
            (mini-kernel::ctx-lookup '((:var 0) (:sort 0)) 0)))

(defun test-whnf-zeta-reduces-let ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (is-equal '(:const mini-kernel::zero ())
              (mini-kernel:whnf env
                                '(:let (:const mini-kernel::zero ())
                                  (:const mini-kernel::nat ())
                                  (:var 0))))))

(defun test-whnf-nat-rec-reduces-constructors ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (is-equal '(:const mini-kernel::zero ())
              (mini-kernel:whnf env
                                '(:app
                                  (:app
                                   (:app
                                    (:app (:const mini-kernel::nat-rec ())
                                     (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                                    (:const mini-kernel::zero ()))
                                   (:lam (:const mini-kernel::nat ())
                                    (:lam (:const mini-kernel::nat ()) (:var 0))))
                                  (:const mini-kernel::zero ()))))
    (is-equal '(:app
                (:const mini-kernel::succ ())
                (:app
                 (:app
                  (:app
                   (:app (:const mini-kernel::nat-rec ())
                    (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                   (:const mini-kernel::zero ()))
                  (:lam (:const mini-kernel::nat ())
                   (:lam (:const mini-kernel::nat ())
                    (:app (:const mini-kernel::succ ()) (:var 0)))))
                 (:const mini-kernel::zero ())))
              (mini-kernel:whnf env
                                '(:app
                                  (:app
                                   (:app
                                    (:app (:const mini-kernel::nat-rec ())
                                     (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                                    (:const mini-kernel::zero ()))
                                   (:lam (:const mini-kernel::nat ())
                                    (:lam (:const mini-kernel::nat ())
                                     (:app (:const mini-kernel::succ ()) (:var 0)))))
                                  (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))))

(defun test-whnf-eq-rec-reduces-refl ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (is-equal '(:const mini-kernel::zero ())
              (mini-kernel:whnf env
                                '(:app
                                  (:app
                                   (:app
                                    (:app
                                     (:app
                                      (:app (:const mini-kernel::eq-rec ())
                                       (:const mini-kernel::nat ()))
                                      (:const mini-kernel::zero ()))
                                     (:lam (:const mini-kernel::nat ())
                                      (:lam
                                       (:app
                                        (:app
                                         (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                                         (:const mini-kernel::zero ()))
                                        (:var 0))
                                       (:const mini-kernel::nat ()))))
                                    (:const mini-kernel::zero ()))
                                   (:const mini-kernel::zero ()))
                                  (:app
                                   (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
                                   (:const mini-kernel::zero ())))))))

(defun test-conv-delta-beta-iota ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (is-true
     (mini-kernel:conv? env
                        '()
                        '(:app
                          (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
                          (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                        '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))))
    (is-true
     (mini-kernel:conv? env
                        '()
                        '(:app
                          (:app
                           (:app
                            (:app (:const mini-kernel::nat-rec ())
                             (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                            (:const mini-kernel::zero ()))
                           (:lam (:const mini-kernel::nat ())
                            (:lam (:const mini-kernel::nat ())
                             (:app (:const mini-kernel::succ ()) (:var 0)))))
                          (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                        '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))))))

(defun test-infer-proof-term ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (is-equal
     '(:pi (:const mini-kernel::nat ())
       (:app
        (:app
         (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
         (:var 0))
        (:var 0)))
     (mini-kernel:infer env
                        '()
                        '(:lam (:const mini-kernel::nat ())
                          (:app
                           (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
                           (:var 0)))))))

(defun test-check-proof-term ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (is-true
     (mini-kernel:check env
                        '()
                        '(:lam (:const mini-kernel::nat ())
                          (:app
                           (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
                           (:var 0)))
                        '(:pi (:const mini-kernel::nat ())
                          (:app
                           (:app
                            (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                            (:var 0))
                           (:var 0)))))))

(defun test-negative-unbound-var ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (signals-kernel-error
     (mini-kernel:infer env '() '(:var 0)))))

(defun test-negative-apply-nonfunction ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (signals-kernel-error
     (mini-kernel:infer env '() '(:app (:const mini-kernel::zero ()) (:const mini-kernel::zero ()))))))

(defun test-negative-type-mismatch ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (signals-kernel-error
     (mini-kernel:check env
                        '()
                        '(:const mini-kernel::zero ())
                        '(:app
                          (:app
                           (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                           (:const mini-kernel::zero ()))
                          (:const mini-kernel::zero ()))))))

(defun test-negative-pi-domain-not-sort ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (signals-kernel-error
     (mini-kernel:infer env
                        '()
                        '(:pi (:const mini-kernel::zero ()) (:const mini-kernel::nat ()))))))

(defun test-negative-bad-nat-rec-motive ()
  (let ((env (mini-kernel:make-bootstrap-env)))
    (signals-kernel-error
     (mini-kernel:infer env
                        '()
                        '(:app
                          (:app
                           (:app
                            (:app (:const mini-kernel::nat-rec ())
                             (:const mini-kernel::nat ()))
                            (:const mini-kernel::zero ()))
                           (:lam (:const mini-kernel::nat ())
                            (:lam (:const mini-kernel::nat ()) (:var 0))))
                          (:const mini-kernel::zero ()))))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "shift-under-binder" #'test-shift-under-binder)
            (cons "subst-top-beta-shape" #'test-subst-top-beta-shape)
            (cons "ctx-lookup-lifts-types" #'test-ctx-lookup-lifts-types)
            (cons "whnf-zeta-reduces-let" #'test-whnf-zeta-reduces-let)
            (cons "whnf-nat-rec-reduces-constructors" #'test-whnf-nat-rec-reduces-constructors)
            (cons "whnf-eq-rec-reduces-refl" #'test-whnf-eq-rec-reduces-refl)
            (cons "conv-delta-beta-iota" #'test-conv-delta-beta-iota)
            (cons "infer-proof-term" #'test-infer-proof-term)
            (cons "check-proof-term" #'test-check-proof-term)
            (cons "negative-unbound-var" #'test-negative-unbound-var)
            (cons "negative-apply-nonfunction" #'test-negative-apply-nonfunction)
            (cons "negative-type-mismatch" #'test-negative-type-mismatch)
            (cons "negative-pi-domain-not-sort" #'test-negative-pi-domain-not-sort)
            (cons "negative-bad-nat-rec-motive" #'test-negative-bad-nat-rec-motive)))
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
