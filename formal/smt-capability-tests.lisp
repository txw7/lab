(defpackage :mini-kernel-smt-capability-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-smt-capability-tests)

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

(defun test-normalization-closed-fragment ()
  (let* ((term '(:= (:bvadd (:bv-lit 8 1) (:bv-lit 8 2))
                    (:extract 7 0 (:concat (:bv-lit 8 0) (:bv-lit 8 3)))))
         (normalized (mini-kernel:normalize-smt-term term)))
    (is-equal (mini-kernel:eval-smt-term term)
              (mini-kernel:eval-smt-term normalized))
    (is-equal normalized
              (mini-kernel:normalize-smt-term-defir term))))

(defun test-boolean-lowering-capability ()
  (let ((term '(:xor (:var p (:Bool)) (:var q (:Bool)))))
    (is-equal (mini-kernel:lower-smt-to-boolean-core term)
              (mini-kernel:lower-smt-to-boolean-core-defir term))))

(defun test-boolean-cnf-capability ()
  (let* ((core '(:or (:and (:var p (:Bool)) (:var q (:Bool)))
                     (:not (:var p (:Bool)))))
         (native (mini-kernel:compile-boolean-core-to-cnf core))
         (defir (mini-kernel:compile-boolean-core-to-cnf-defir core)))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))))

(defun test-boolean-cnf-assumptions-capability ()
  (let* ((assumptions '((:a (:var p (:Bool)))
                        (:b (:not (:var p (:Bool))))))
         (core '(:bool t))
         (native (mini-kernel:compile-boolean-core-to-cnf-with-assumptions assumptions core))
         (defir (mini-kernel:compile-boolean-core-to-cnf-with-assumptions-defir assumptions core)))
    (is-equal (mini-kernel::smt-cnf-assumptions native)
              (mini-kernel::smt-cnf-assumptions defir))))

(defun test-bitblast-capability ()
  (let ((term '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                    (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))
    (is-equal (mini-kernel:bitblast-smt-term term)
              (mini-kernel:bitblast-smt-term-defir term))))

(defun test-composed-bv-cnf-capability ()
  (let* ((bitblasted (mini-kernel:bitblast-smt-term
                      '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                             (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))
         (native (mini-kernel:compile-smt-to-cnf bitblasted))
         (defir (mini-kernel:compile-smt-to-cnf-defir bitblasted)))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))))

(defun test-sat-and-unsat-capability ()
  (let* ((sat-cnf (mini-kernel:compile-smt-to-cnf
                   '(:or (:var p (:Bool)) (:var q (:Bool)))))
         (unsat-cnf (mini-kernel:compile-smt-to-cnf
                     '(:and (:var p (:Bool))
                            (:not (:var p (:Bool)))))))
    (is-true (mini-kernel:solve-cnf-dpll sat-cnf))
    (is-equal nil (mini-kernel:solve-cnf-dpll unsat-cnf))
    (is-true (equalp (mini-kernel:solve-cnf-dpll sat-cnf)
                     (mini-kernel:solve-cnf-dpll-defir sat-cnf)))))

(defun test-unsat-core-capability ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf-with-assumptions
               '((:a (:var p (:Bool)))
                 (:b (:not (:var p (:Bool)))))
               '(:bool t)))
         (core (mini-kernel:smt-cnf-unsat-core cnf)))
    (is-equal '(:a :b) core)))

(defun test-run-smt-check-capability ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                         (:= (:var x (:BV 2)) (:bv-lit 2 2))))))
    (is-equal :rejected (mini-kernel:backend-result-status result))
    (is-equal '(:normalized-form) (mini-kernel:backend-result-evidence result))))

(defun test-bridge-normalization-capability ()
  (let ((formula '(:= (:bvadd (:bv-lit 8 1) (:bv-lit 8 2))
                      (:extract 7 0 (:concat (:bv-lit 8 0) (:bv-lit 8 3))))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-normalization-equivalence formula))
    (is-true (mini-kernel:normalization-side-condition formula))))

(defun test-bridge-boolean-unsat-capability ()
  (let ((formula '(:and (:bool t) (:bool nil))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-boolean-unsat formula))
    (is-true (mini-kernel:boolean-unsat-side-condition formula))))

(defun test-bridge-bitvector-unsat-capability ()
  (let ((formula '(:and (:= (:bv-lit 2 1) (:bv-lit 2 2))
                       (:bool t))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-bitvector-unsat formula))
    (is-true (mini-kernel:bitvector-unsat-side-condition formula))))

(defun test-bridge-int-unsat-capability ()
  (let ((formula '(:and (:= (:int-lit 1) (:int-lit 1))
                       (:int-lt (:int-lit 2) (:int-lit 1)))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-int-unsat formula))
    (is-true (mini-kernel:int-unsat-side-condition formula))))

(defun test-bridge-affine-int-contradiction-capability ()
  (let ((formula '(:and (:int-ge (:var x (:Int)) (:int-lit 0))
                       (:int-lt (:var x (:Int)) (:int-lit 0)))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-affine-int-contradiction formula))
    (is-true (mini-kernel:affine-int-contradiction-side-condition formula))))

(defun test-smtlib-summary-capability ()
  (let* ((path "/home/user0/MIR/formal/smt/Stage1EnvWalk.smt2")
         (entry (mini-kernel:summarize-smtlib-file path))
         (summary (getf entry :summary)))
    (is-equal path (getf entry :path))
    (is-equal 5 (getf summary :total))
    (is-equal 5 (+ (getf summary :accepted)
                   (getf summary :rejected)
                   (getf summary :unknown)))
    (is-equal 0 (getf summary :unknown))))

(defun test-smtlib-sweep-capability ()
  (let* ((report (mini-kernel:sweep-smtlib-directory
                  "/home/user0/MIR/formal/smt/Stage1EnvWalk.smt2"
                  :sortp t))
         (entries (getf report :entries))
         (entry (first entries))
         (summary (getf entry :summary)))
    (is-equal 1 (getf report :files))
    (is-equal 5 (getf report :checks))
    (is-equal (getf summary :accepted) (getf report :accepted))
    (is-equal (getf summary :rejected) (getf report :rejected))
    (is-equal (getf summary :unknown) (getf report :unknown))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "normalization-closed-fragment" #'test-normalization-closed-fragment)
            (cons "boolean-lowering-capability" #'test-boolean-lowering-capability)
            (cons "boolean-cnf-capability" #'test-boolean-cnf-capability)
            (cons "boolean-cnf-assumptions-capability"
                  #'test-boolean-cnf-assumptions-capability)
            (cons "bitblast-capability" #'test-bitblast-capability)
            (cons "composed-bv-cnf-capability" #'test-composed-bv-cnf-capability)
            (cons "sat-and-unsat-capability" #'test-sat-and-unsat-capability)
            (cons "unsat-core-capability" #'test-unsat-core-capability)
            (cons "run-smt-check-capability" #'test-run-smt-check-capability)
            (cons "bridge-normalization-capability"
                  #'test-bridge-normalization-capability)
            (cons "bridge-boolean-unsat-capability"
                  #'test-bridge-boolean-unsat-capability)
            (cons "bridge-bitvector-unsat-capability"
                  #'test-bridge-bitvector-unsat-capability)
            (cons "bridge-int-unsat-capability"
                  #'test-bridge-int-unsat-capability)
            (cons "bridge-affine-int-contradiction-capability"
                  #'test-bridge-affine-int-contradiction-capability)
            (cons "smtlib-summary-capability" #'test-smtlib-summary-capability)
            (cons "smtlib-sweep-capability" #'test-smtlib-sweep-capability)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "smt capability test suite failed"))
    t))
