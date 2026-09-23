(defpackage :mini-kernel-lean-whnf-ingest-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-lean-whnf-ingest-tests)

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

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun %nat ()
  '(:const mini-kernel::nat ()))

(defun %zero ()
  '(:const mini-kernel::zero ()))

(defun %succ (term)
  `(:app (:const mini-kernel::succ ()) ,term))

(defun %sample-whnf-terms ()
  (list
   `(:let ,(%zero) ,(%nat) (:var 0))
   `(:app (:lam ,(%nat) (:var 0)) ,(%zero))
   `(:const mini-kernel::add ())
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
      (:const mini-kernel::zero ())))))

(defun %sample-conv-cases ()
  (list
   (list
    '()
    '(:app
      (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
      (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
    '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
   (list
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
    '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))

(defun %sample-infer-cases ()
  (list
   (list
    '()
    '(:lam (:const mini-kernel::nat ())
      (:app
       (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
       (:var 0))))
   (list
    '()
    '(:app
      (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
      (:const mini-kernel::zero ())))))

(defun %sample-check-cases ()
  (list
   (list
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
       (:var 0))))
   (list
    '()
    '(:const mini-kernel::zero ())
    '(:const mini-kernel::nat ()))))

(defun test-generate-and-ingest-whnf-program ()
  (let* ((path (mini-kernel:generate-lean-whnf-program))
         (program (mini-kernel:ingest-mini-kernel-whnf-program path)))
    (is-true (pathnamep path))
    (is-equal 7 (length (mini-kernel:list-ingested-lean-def-functions program)))
    (is-true (mini-kernel:find-ingested-lean-def-function program "reduceNatRec"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "reduceEqRec"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "whnf"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "conv"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "checkSort"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "infer"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "check"))))

(defun test-whnf-ingested-source-blocks ()
  (let* ((program (mini-kernel:ingest-mini-kernel-whnf-program))
         (whnf (mini-kernel:find-ingested-lean-def-function program "whnf")))
    (is-true (search "partial def whnf (t : CoreTerm) : CoreTerm :="
                     (mini-kernel:lean-def-function-source-block whnf)))
    (is-true (search "| CoreTerm.const ConstName.natRec, args => reduceNatRec args"
                     (mini-kernel:lean-def-function-source-block whnf)))
    (is-true (search "| CoreTerm.const ConstName.eqRec, args => reduceEqRec args"
                     (mini-kernel:lean-def-function-source-block whnf)))))

(defun test-reduction-ingested-parity ()
  (let ((program (mini-kernel:ingest-mini-kernel-whnf-program)))
    (dolist (term (%sample-whnf-terms))
      (is-true (mini-kernel:check-ingested-lean-def-parity program "whnf" term)))
    (is-true
     (mini-kernel:check-ingested-lean-def-parity
      program
      "reduceNatRec"
      (list '(:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ()))
            '(:const mini-kernel::zero ())
            '(:lam (:const mini-kernel::nat ())
              (:lam (:const mini-kernel::nat ())
               (:app (:const mini-kernel::succ ()) (:var 0))))
            '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))
    (is-true
     (mini-kernel:check-ingested-lean-def-parity
      program
      "reduceEqRec"
      (list '(:const mini-kernel::nat ())
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
              (:const mini-kernel::zero ())))))))

(defun test-conv-ingested-parity ()
  (let ((program (mini-kernel:ingest-mini-kernel-whnf-program)))
    (dolist (entry (%sample-conv-cases))
      (is-true
       (apply #'mini-kernel:check-ingested-lean-def-parity
              program
              "conv"
              entry)))))

(defun test-infer-ingested-parity ()
  (let ((program (mini-kernel:ingest-mini-kernel-whnf-program)))
    (dolist (entry (%sample-infer-cases))
      (is-true
       (apply #'mini-kernel:check-ingested-lean-def-parity
              program
              "infer"
              entry)))))

(defun test-check-ingested-parity ()
  (let ((program (mini-kernel:ingest-mini-kernel-whnf-program)))
    (dolist (entry (%sample-check-cases))
      (is-true
       (apply #'mini-kernel:check-ingested-lean-def-parity
              program
              "check"
              entry)))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "generate-and-ingest-whnf-program"
                  #'test-generate-and-ingest-whnf-program)
            (cons "whnf-ingested-source-blocks"
                  #'test-whnf-ingested-source-blocks)
            (cons "reduction-ingested-parity"
                  #'test-reduction-ingested-parity)
            (cons "conv-ingested-parity"
                  #'test-conv-ingested-parity)
            (cons "infer-ingested-parity"
                  #'test-infer-ingested-parity)
            (cons "check-ingested-parity"
                  #'test-check-ingested-parity)))
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
