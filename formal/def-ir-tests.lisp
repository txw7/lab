(defpackage :mini-kernel-def-ir-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-def-ir-tests)

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

(defun test-call-defir-shift ()
  (let ((program (mini-kernel:make-mini-kernel-defir-program)))
    (is-equal
     '(:lam (:const mini-kernel::nat ()) (:var 0))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::shift
      1
      0
      '(:lam (:const mini-kernel::nat ()) (:var 0))))))

(defun test-call-defir-whnf ()
  (let* ((program (mini-kernel:make-mini-kernel-defir-program))
         (env (mini-kernel:make-bootstrap-env)))
    (is-equal
     '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::whnf
      env
      '(:app
        (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
        (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))))

(defun test-call-defir-infer ()
  (let* ((program (mini-kernel:make-mini-kernel-defir-program))
         (env (mini-kernel:make-bootstrap-env)))
    (is-equal
     '(:pi (:const mini-kernel::nat ())
       (:app
        (:app
         (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
         (:var 0))
        (:var 0)))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::infer
      env
      '()
      '(:lam (:const mini-kernel::nat ())
        (:app
         (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
         (:var 0)))))))

(defun test-call-defir-check ()
  (let* ((program (mini-kernel:make-mini-kernel-defir-program))
         (env (mini-kernel:make-bootstrap-env)))
    (is-true
     (mini-kernel:call-defir-function
      program
      'mini-kernel::check
      env
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

(defun test-lower-ingested-primitives-to-defir ()
  (let* ((ingested (mini-kernel:ingest-declarativecore-def-program))
         (program (mini-kernel:lower-ingested-lean-def-program-to-defir ingested)))
    (is-equal 5 (length (mini-kernel:defir-program-functions program)))
    (is-equal
     '(:lam (:const mini-kernel::nat ()) (:var 0))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::shift
      1
      0
      '(:lam (:const mini-kernel::nat ()) (:var 0))))))

(defun test-merged-lowered-ingested-checker-program ()
  (let* ((primitive (mini-kernel:lower-ingested-lean-def-program-to-defir
                     (mini-kernel:ingest-declarativecore-def-program)))
         (whnf (mini-kernel:lower-ingested-lean-def-program-to-defir
                (mini-kernel:ingest-mini-kernel-whnf-program)))
         (program (mini-kernel:merge-defir-programs primitive whnf))
         (env (mini-kernel:make-bootstrap-env)))
    (is-equal 13 (length (mini-kernel:defir-program-functions program)))
    (is-equal
     '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::whnf
      env
      '(:app
        (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
        (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))))

(defun test-defir-kernel-implementation-uses-lowered-program ()
  (let ((implementation (mini-kernel:make-defir-kernel-implementation))
        (env (mini-kernel:make-bootstrap-env)))
    (mini-kernel:with-kernel-implementation (implementation)
      (is-equal
       '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
       (mini-kernel:whnf
        env
        '(:app
          (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
          (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))
      (is-true
       (mini-kernel:check
        env
        '()
        '(:const mini-kernel::zero ())
        '(:const mini-kernel::nat ()))))))

(defun test-call-defir-smt-normalize ()
  (let ((program (mini-kernel:make-smt-normalizer-defir-program)))
    (is-equal
     (mini-kernel:normalize-smt-term
      '(:and (:bool t)
        (:or (:bool nil) (:var p (:Bool)))
        (:and (:var q (:Bool)) (:bool t))))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::normalize-smt-term
      '(:and (:bool t)
        (:or (:bool nil) (:var p (:Bool)))
        (:and (:var q (:Bool)) (:bool t)))))))

(defun test-call-defir-smt-normalize-bv ()
  (let ((program (mini-kernel:make-smt-normalizer-defir-program)))
    (is-equal
     (mini-kernel:normalize-smt-term
      '(:= (:bvadd (:bv-lit 8 1) (:bv-lit 8 2))
        (:extract 7 0 (:concat (:bv-lit 8 0) (:bv-lit 8 3)))))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::normalize-smt-term
      '(:= (:bvadd (:bv-lit 8 1) (:bv-lit 8 2))
        (:extract 7 0 (:concat (:bv-lit 8 0) (:bv-lit 8 3))))))))

(defun test-call-defir-smt-lower-boolean-core ()
  (let ((program (mini-kernel:make-smt-core-defir-program)))
    (is-equal
     (mini-kernel:lower-smt-to-boolean-core
      '(:xor (:var p (:Bool)) (:var q (:Bool))))
     (mini-kernel:call-defir-function
      program
      'mini-kernel::lower-smt-to-boolean-core
      '(:xor (:var p (:Bool)) (:var q (:Bool)))))))

(defun test-call-defir-smt-compile-boolean-core-to-cnf ()
  (let* ((program (mini-kernel:make-smt-core-defir-program))
         (native (mini-kernel:compile-boolean-core-to-cnf
                  '(:or (:var p (:Bool)) (:not (:var p (:Bool))))))
         (defir (mini-kernel:call-defir-function
                 program
                 'mini-kernel::compile-boolean-core-to-cnf
                 '(:or (:var p (:Bool)) (:not (:var p (:Bool)))))))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel:smt-cnf-root-literal native)
              (mini-kernel:smt-cnf-root-literal defir))))

(defun test-call-defir-smt-compile-boolean-core-to-cnf-with-assumptions ()
  (let* ((program (mini-kernel:make-smt-core-defir-program))
         (assumptions '((a1 (:var p (:Bool)))
                        (a2 (:not (:var p (:Bool))))))
         (native (mini-kernel:compile-boolean-core-to-cnf-with-assumptions
                  assumptions
                  '(:bool t)))
         (defir (mini-kernel:call-defir-function
                 program
                 'mini-kernel::compile-boolean-core-to-cnf-with-assumptions
                 assumptions
                 '(:bool t))))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel::smt-cnf-assumptions native)
              (mini-kernel::smt-cnf-assumptions defir))))

(defun test-call-defir-smt-solve-cnf-dpll ()
  (let* ((program (mini-kernel:make-smt-core-defir-program))
         (cnf (mini-kernel:compile-boolean-core-to-cnf
               '(:or (:var p (:Bool)) (:var q (:Bool)))))
         (assignment (mini-kernel:call-defir-function
                      program
                      'mini-kernel::solve-cnf-dpll
                      cnf)))
    (is-true assignment)
    (is-true (mini-kernel:eval-cnf cnf assignment))))

(defun test-call-defir-smt-solve-cnf-under-assumptions-dpll ()
  (let* ((program (mini-kernel:make-smt-core-defir-program))
         (cnf (mini-kernel:compile-boolean-core-to-cnf-with-assumptions
               '((a1 (:var p (:Bool)))
                 (a2 (:not (:var p (:Bool)))))
               '(:bool t)))
         (assumptions (mapcar #'second (mini-kernel::smt-cnf-assumptions cnf)))
         (assignment (mini-kernel:call-defir-function
                      program
                      'mini-kernel::solve-cnf-under-assumptions-dpll
                      cnf
                      assumptions)))
    (is-equal nil assignment)))

(defun test-call-defir-smt-bitblast ()
  (let* ((program (mini-kernel:make-smt-core-defir-program))
         (term '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                      (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))
    (is-equal
     (mini-kernel:bitblast-smt-term term)
     (mini-kernel:call-defir-function
      program
      'mini-kernel::bitblast-smt-term
      term))))

(defun test-call-defir-smt-compile-smt-to-cnf ()
  (let* ((program (mini-kernel:make-smt-core-defir-program))
         (term (mini-kernel:bitblast-smt-term
                '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                       (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))
         (native (mini-kernel:compile-smt-to-cnf term))
         (defir (mini-kernel:call-defir-function
                 program
                 'mini-kernel::compile-smt-to-cnf
                 term)))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel:smt-cnf-root-literal native)
              (mini-kernel:smt-cnf-root-literal defir))))

(defun test-call-defir-smt-compile-smt-to-cnf-with-assumptions ()
  (let* ((program (mini-kernel:make-smt-core-defir-program))
         (assumptions '((a1 (:var p (:Bool)))
                        (a2 (:not (:var p (:Bool))))))
         (term '(:bool t))
         (native (mini-kernel:compile-smt-to-cnf-with-assumptions assumptions term))
         (defir (mini-kernel:call-defir-function
                 program
                 'mini-kernel::compile-smt-to-cnf-with-assumptions
                 assumptions
                 term)))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel::smt-cnf-assumptions native)
              (mini-kernel::smt-cnf-assumptions defir))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "call-defir-shift" #'test-call-defir-shift)
            (cons "call-defir-whnf" #'test-call-defir-whnf)
            (cons "call-defir-infer" #'test-call-defir-infer)
            (cons "call-defir-check" #'test-call-defir-check)
            (cons "lower-ingested-primitives-to-defir"
                  #'test-lower-ingested-primitives-to-defir)
            (cons "merged-lowered-ingested-checker-program"
                  #'test-merged-lowered-ingested-checker-program)
            (cons "call-defir-smt-normalize"
                  #'test-call-defir-smt-normalize)
            (cons "call-defir-smt-normalize-bv"
                  #'test-call-defir-smt-normalize-bv)
            (cons "call-defir-smt-lower-boolean-core"
                  #'test-call-defir-smt-lower-boolean-core)
            (cons "call-defir-smt-compile-boolean-core-to-cnf"
                  #'test-call-defir-smt-compile-boolean-core-to-cnf)
            (cons "call-defir-smt-compile-boolean-core-to-cnf-with-assumptions"
                  #'test-call-defir-smt-compile-boolean-core-to-cnf-with-assumptions)
            (cons "call-defir-smt-solve-cnf-dpll"
                  #'test-call-defir-smt-solve-cnf-dpll)
            (cons "call-defir-smt-solve-cnf-under-assumptions-dpll"
                  #'test-call-defir-smt-solve-cnf-under-assumptions-dpll)
            (cons "call-defir-smt-bitblast"
                  #'test-call-defir-smt-bitblast)
            (cons "call-defir-smt-compile-smt-to-cnf"
                  #'test-call-defir-smt-compile-smt-to-cnf)
            (cons "call-defir-smt-compile-smt-to-cnf-with-assumptions"
                  #'test-call-defir-smt-compile-smt-to-cnf-with-assumptions)
            (cons "defir-kernel-implementation-uses-lowered-program"
                  #'test-defir-kernel-implementation-uses-lowered-program)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "DefIR test suite failed"))
    t))
