(defpackage :mini-kernel-reference-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-reference-tests)

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

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun kl-outcome (thunk)
  (handler-case
      (list :ok (funcall thunk))
    (mini-kernel::kernel-error ()
      '(:error))))

(defun kr-outcome (thunk)
  (handler-case
      (list :ok (funcall thunk))
    (mini-kernel-reference::reference-error ()
      '(:error))))

(defun kl-accepts-p (env certificate)
  (handler-case
      (progn
        (mini-kernel:check-certificate env certificate :expected-env-digest :bootstrap-v1)
        t)
    (mini-kernel::kernel-error ()
      nil)))

(defun kr-accepts-p (env certificate)
  (handler-case
      (progn
        (mini-kernel-reference:check-certificate env certificate :expected-env-digest :bootstrap-v1)
        t)
    (mini-kernel-reference::reference-error ()
      nil)))

(defun kl-valid-p (certificate)
  (handler-case
      (progn
        (mini-kernel:validate-certificate certificate)
        t)
    (mini-kernel::kernel-error ()
      nil)))

(defun kr-valid-p (certificate)
  (handler-case
      (progn
        (mini-kernel-reference:validate-certificate certificate)
        t)
    (mini-kernel-reference::reference-error ()
      nil)))

(defun test-accepted-corpus-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (entry (mini-kernel-corpus:accepted-certificates))
      (is-equal t (kl-valid-p (mini-kernel-corpus:corpus-entry-certificate entry)))
      (is-equal t (kr-valid-p (mini-kernel-corpus:corpus-entry-certificate entry)))
      (is-equal t (kl-accepts-p kl-env (mini-kernel-corpus:corpus-entry-certificate entry)))
      (is-equal t (kr-accepts-p kr-env (mini-kernel-corpus:corpus-entry-certificate entry))))))

(defun test-rejected-corpus-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (entry (mini-kernel-corpus:rejected-certificates))
      (is-equal t (kl-valid-p (mini-kernel-corpus:corpus-entry-certificate entry)))
      (is-equal t (kr-valid-p (mini-kernel-corpus:corpus-entry-certificate entry)))
      (is-equal nil (kl-accepts-p kl-env (mini-kernel-corpus:corpus-entry-certificate entry)))
      (is-equal nil (kr-accepts-p kr-env (mini-kernel-corpus:corpus-entry-certificate entry))))))

(defun test-malformed-corpus-agreement ()
  (dolist (entry (mini-kernel-corpus:malformed-certificates))
    (is-equal nil (kl-valid-p (mini-kernel-corpus:corpus-entry-certificate entry)))
    (is-equal nil (kr-valid-p (mini-kernel-corpus:corpus-entry-certificate entry)))))

(defun test-generated-corpus-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (entry (mini-kernel-corpus:generated-certificates))
      (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
        (is-equal (kl-valid-p certificate)
                  (kr-valid-p certificate))
        (is-equal (kl-accepts-p kl-env certificate)
                  (kr-accepts-p kr-env certificate))))))

(defun test-shift-agreement ()
  (dolist (vector '((1 0 (:lam (:var 0) (:var 1)))
                    (2 1 (:app (:var 0) (:var 1)))
                    (1 0 (:pi (:const mini-kernel::nat ()) (:app (:var 1) (:var 0))))
                    (1 0 (:lam (:const mini-kernel::nat ())
                           (:lam (:const mini-kernel::nat ())
                            (:app (:var 2) (:var 0)))))))
    (destructuring-bind (delta cutoff term) vector
      (is-equal (mini-kernel:shift delta cutoff term)
                (mini-kernel-reference::r-shift delta cutoff term)))))

(defun test-subst-top-agreement ()
  (dolist (vector '(((:const mini-kernel::zero ()) (:var 0))
                    ((:const mini-kernel::zero ()) (:lam (:const mini-kernel::nat ()) (:var 1)))
                    ((:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
                     (:app (:var 0) (:const mini-kernel::zero ())))
                    ((:const mini-kernel::zero ())
                     (:lam (:const mini-kernel::nat ())
                      (:let (:var 1)
                       (:const mini-kernel::nat ())
                       (:var 0))))))
    (destructuring-bind (replacement body) vector
      (is-equal (mini-kernel:subst-top replacement body)
                (mini-kernel-reference::r-subst-top replacement body)))))

(defun test-subst-agreement ()
  (dolist (vector '((0 (:const mini-kernel::zero ()) (:var 0))
                    (0 (:const mini-kernel::zero ())
                     (:lam (:const mini-kernel::nat ()) (:var 1)))
                    (0 (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
                     (:app (:var 0) (:var 1)))
                    (0 (:const mini-kernel::zero ())
                     (:let (:var 0)
                      (:const mini-kernel::nat ())
                      (:app (:var 1) (:var 0))))
                    (1 (:const mini-kernel::zero ())
                     (:lam (:const mini-kernel::nat ())
                      (:app (:var 2) (:var 0))))))
    (destructuring-bind (index replacement term) vector
      (is-equal (mini-kernel:subst index replacement term)
                (mini-kernel-reference::r-subst index replacement term)))))

(defun test-ctx-lookup-agreement ()
  (dolist (vector '((((:var 0) (:sort 0)) 0)
                    (((:var 0) (:sort 0)) 1)
                    (((:const mini-kernel::nat ()) (:sort 0)) 0)))
    (destructuring-bind (ctx index) vector
      (is-equal (kl-outcome (lambda () (mini-kernel::ctx-lookup ctx index)))
                (kr-outcome (lambda () (mini-kernel-reference::r-ctx-lookup ctx index)))))))

(defun test-whnf-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (term '((:let (:const mini-kernel::zero ())
                     (:const mini-kernel::nat ())
                     (:var 0))
                    (:app
                     (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
                     (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                    (:app
                     (:app
                      (:app
                       (:app (:const mini-kernel::nat-rec ())
                        (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                       (:const mini-kernel::zero ()))
                      (:lam (:const mini-kernel::nat ())
                       (:lam (:const mini-kernel::nat ()) (:var 0))))
                     (:const mini-kernel::zero ()))
                    (:app
                     (:lam (:const mini-kernel::nat ())
                      (:let (:var 0)
                       (:const mini-kernel::nat ())
                       (:var 0)))
                     (:const mini-kernel::zero ()))))
      (is-equal (mini-kernel:whnf kl-env term)
                (mini-kernel-reference::r-whnf kr-env term)))))

(defun test-reduce-nat-rec-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (vector
             (list
              (list
               '()
               (list
                '(:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ()))
                '(:const mini-kernel::zero ())
                '(:lam (:const mini-kernel::nat ())
                  (:lam (:const mini-kernel::nat ())
                   (:app (:const mini-kernel::succ ()) (:var 0))))
                '(:const mini-kernel::zero ())))
              (list
               '()
               (list
                '(:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ()))
                '(:const mini-kernel::zero ())
                '(:lam (:const mini-kernel::nat ())
                  (:lam (:const mini-kernel::nat ())
                   (:app (:const mini-kernel::succ ()) (:var 0))))
                '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))))
              (list
               '()
               (list
                '(:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ()))
                '(:const mini-kernel::zero ())
                '(:lam (:const mini-kernel::nat ())
                  (:lam (:const mini-kernel::nat ())
                   (:app (:const mini-kernel::succ ()) (:var 0))))
                '(:var 0)))))
      (destructuring-bind (levels args) vector
        (is-equal (mini-kernel::reduce-nat-rec kl-env levels args)
                  (mini-kernel-reference::r-reduce-nat-rec kr-env levels args))))))

(defun test-reduce-eq-rec-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (vector
             (list
              (list
               '()
               (list
                '(:const mini-kernel::nat ())
                '(:const mini-kernel::zero ())
                '(:lam (:const mini-kernel::nat ())
                  (:lam
                   (:app
                    (:app
                     (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                     (:const mini-kernel::zero ()))
                    (:var 0))
                   (:const mini-kernel::nat ())))
                '(:const mini-kernel::zero ())
                '(:const mini-kernel::zero ())
                '(:app
                  (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
                  (:const mini-kernel::zero ()))))
              (list
               '()
               (list
                '(:const mini-kernel::nat ())
                '(:const mini-kernel::zero ())
                '(:lam (:const mini-kernel::nat ())
                  (:lam
                   (:app
                    (:app
                     (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                     (:const mini-kernel::zero ()))
                    (:var 0))
                   (:const mini-kernel::nat ())))
                '(:const mini-kernel::zero ())
                '(:var 0)
                '(:var 1)))))
      (destructuring-bind (levels args) vector
        (is-equal (mini-kernel::reduce-eq-rec kl-env levels args)
                  (mini-kernel-reference::r-reduce-eq-rec kr-env levels args))))))

(defun test-conv-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (vector `((()
                       (:app
                        (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
                        (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                       (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                      (()
                       (:const mini-kernel::zero ())
                       (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                      (((:const mini-kernel::nat ()))
                       (:var 0)
                       (:var 0))
                      (()
                       (:app
                        (:lam (:const mini-kernel::nat ()) (:var 0))
                        (:const mini-kernel::zero ()))
                       (:const mini-kernel::zero ()))
                      (()
                       (:let (:const mini-kernel::zero ())
                        (:const mini-kernel::nat ())
                        (:var 0))
                       (:const mini-kernel::zero ()))))
      (destructuring-bind (ctx lhs rhs) vector
        (is-equal (mini-kernel:conv? kl-env ctx lhs rhs)
                  (mini-kernel-reference::r-conv kr-env ctx lhs rhs))))))

(defun test-check-sort-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (vector '((() (:const mini-kernel::nat ()))
                      (() (:const mini-kernel::zero ()))))
      (destructuring-bind (ctx term) vector
        (is-equal (kl-outcome (lambda () (mini-kernel::check-sort kl-env ctx term)))
                  (kr-outcome (lambda () (mini-kernel-reference::r-check-sort kr-env ctx term))))))))

(defun test-infer-agreement ()
  (let ((kl-env (mini-kernel:make-bootstrap-env))
        (kr-env (mini-kernel-reference:make-reference-env
                 (mini-kernel:make-bootstrap-env))))
    (dolist (vector '((() (:const mini-kernel::zero ()))
                      (((:const mini-kernel::nat ())) (:var 0))
                      (() (:app (:const mini-kernel::zero ()) (:const mini-kernel::zero ())))
                      (() (:app
                           (:lam (:const mini-kernel::nat ()) (:var 0))
                           (:const mini-kernel::zero ())))
                      (() (:let (:const mini-kernel::zero ())
                           (:const mini-kernel::nat ())
                           (:var 0)))))
      (destructuring-bind (ctx term) vector
        (is-equal (kl-outcome (lambda () (mini-kernel:infer kl-env ctx term)))
                  (kr-outcome (lambda () (mini-kernel-reference::r-infer kr-env ctx term))))))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "accepted-corpus-agreement" #'test-accepted-corpus-agreement)
            (cons "rejected-corpus-agreement" #'test-rejected-corpus-agreement)
            (cons "malformed-corpus-agreement" #'test-malformed-corpus-agreement)
            (cons "generated-corpus-agreement" #'test-generated-corpus-agreement)
            (cons "shift-agreement" #'test-shift-agreement)
            (cons "subst-top-agreement" #'test-subst-top-agreement)
            (cons "subst-agreement" #'test-subst-agreement)
            (cons "ctx-lookup-agreement" #'test-ctx-lookup-agreement)
            (cons "whnf-agreement" #'test-whnf-agreement)
            (cons "reduce-nat-rec-agreement" #'test-reduce-nat-rec-agreement)
            (cons "reduce-eq-rec-agreement" #'test-reduce-eq-rec-agreement)
            (cons "conv-agreement" #'test-conv-agreement)
            (cons "check-sort-agreement" #'test-check-sort-agreement)
            (cons "infer-agreement" #'test-infer-agreement)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "reference checker test suite failed"))
    t))
