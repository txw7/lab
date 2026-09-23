(defpackage :mini-kernel-smt-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-smt-tests)

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

(defun test-normalize-boolean-flattening ()
  (is-equal '(:var a (:Bool))
            (mini-kernel:normalize-smt-term
             '(:and (:bool t) (:and (:var a (:Bool)) (:bool t))))))

(defun test-normalize-boolean-constant-fold ()
  (is-equal '(:bool nil)
            (mini-kernel:normalize-smt-term
             '(:or (:bool nil) (:and (:bool t) (:bool nil))))))

(defun test-normalize-bvadd-constant-fold ()
  (is-equal '(:bv-lit 8 3)
            (mini-kernel:normalize-smt-term
             '(:bvadd (:bv-lit 8 1) (:bv-lit 8 2)))))

(defun test-normalize-int-constant-fold ()
  (is-equal '(:bool t)
            (mini-kernel:normalize-smt-term
             '(:int-le (:int-add (:int-lit 2) (:int-lit 3))
                       (:int-sub (:int-lit 8) (:int-lit 3))))))

(defun test-normalize-concat-extract ()
  (is-equal '(:bv-lit 8 171)
            (mini-kernel:normalize-smt-term
             '(:extract 7 0 (:concat (:bv-lit 8 18) (:bv-lit 8 171))))))

(defun test-eval-normalize-preserves-closed-formula ()
  (let* ((term '(:= (:bvadd (:bv-lit 8 1) (:bv-lit 8 2))
                    (:extract 7 0 (:concat (:bv-lit 8 0) (:bv-lit 8 3)))))
         (normalized (mini-kernel:normalize-smt-term term)))
    (is-equal (mini-kernel:eval-smt-term term)
              (mini-kernel:eval-smt-term normalized))))

(defun test-defir-normalize-agrees-on-closed-formula ()
  (let ((term '(:and (:bool t)
                (:or (:bool nil)
                 (:= (:bvadd (:bv-lit 8 1) (:bv-lit 8 2))
                     (:extract 7 0 (:concat (:bv-lit 8 0) (:bv-lit 8 3))))))))
    (is-equal (mini-kernel:normalize-smt-term term)
              (mini-kernel:normalize-smt-term-defir term))
    (is-equal (mini-kernel:eval-smt-term (mini-kernel:normalize-smt-term term))
              (mini-kernel:eval-smt-term (mini-kernel:normalize-smt-term-defir term)))))

(defun test-defir-lower-agrees-on-boolean-core ()
  (let ((open-term '(:ite (:var p (:Bool))
                     (:xor (:var q (:Bool)) (:bool t))
                     (:= (:var r (:Bool)) (:bool nil))))
        (closed-term '(:ite (:bool t)
                       (:xor (:bool nil) (:bool t))
                       (:= (:bool t) (:bool nil)))))
    (is-equal (mini-kernel:lower-smt-to-boolean-core open-term)
              (mini-kernel:lower-smt-to-boolean-core-defir open-term))
    (is-equal (mini-kernel:eval-smt-term (mini-kernel:lower-smt-to-boolean-core closed-term))
              (mini-kernel:eval-smt-term (mini-kernel:lower-smt-to-boolean-core-defir closed-term)))))

(defun test-defir-cnf-agrees-on-boolean-core ()
  (let* ((core '(:or (:and (:var p (:Bool)) (:var q (:Bool)))
                     (:not (:var p (:Bool)))))
         (native (mini-kernel:compile-boolean-core-to-cnf core))
         (defir (mini-kernel:compile-boolean-core-to-cnf-defir core)))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel:smt-cnf-root-literal native)
              (mini-kernel:smt-cnf-root-literal defir))))

(defun test-defir-cnf-with-assumptions-agrees-on-boolean-core ()
  (let* ((assumptions '((a1 (:var p (:Bool)))
                        (a2 (:not (:var p (:Bool))))))
         (core '(:bool t))
         (native (mini-kernel:compile-boolean-core-to-cnf-with-assumptions assumptions core))
         (defir (mini-kernel:compile-boolean-core-to-cnf-with-assumptions-defir assumptions core)))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel::smt-cnf-assumptions native)
              (mini-kernel::smt-cnf-assumptions defir))))

(defun test-defir-compile-smt-to-cnf-parity ()
  (let* ((term (mini-kernel:bitblast-smt-term
                '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                       (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))
         (native (mini-kernel:compile-smt-to-cnf term))
         (defir (mini-kernel:compile-smt-to-cnf-defir term)))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel:smt-cnf-root-literal native)
              (mini-kernel:smt-cnf-root-literal defir))))

(defun test-defir-compile-smt-to-cnf-with-assumptions-parity ()
  (let* ((assumptions '((a1 (:var p (:Bool)))
                        (a2 (:not (:var p (:Bool))))))
         (term '(:bool t))
         (native (mini-kernel:compile-smt-to-cnf-with-assumptions assumptions term))
         (defir (mini-kernel:compile-smt-to-cnf-with-assumptions-defir assumptions term)))
    (is-equal (mini-kernel:smt-cnf-var-count native)
              (mini-kernel:smt-cnf-var-count defir))
    (is-equal (mini-kernel:smt-cnf-clauses native)
              (mini-kernel:smt-cnf-clauses defir))
    (is-equal (mini-kernel::smt-cnf-assumptions native)
              (mini-kernel::smt-cnf-assumptions defir))))

(defun test-lower-smt-to-boolean-core ()
  (is-equal '(:or (:and (:not (:var p (:Bool))) (:var q (:Bool)))
                  (:and (:not (:var q (:Bool))) (:var p (:Bool))))
            (mini-kernel:lower-smt-to-boolean-core
             '(:xor (:var p (:Bool)) (:var q (:Bool))))))

(defun test-compile-smt-to-cnf-sat ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf
               '(:or (:var p (:Bool))
                     (:not (:var p (:Bool))))))
         (assignment (mini-kernel:smt-cnf-sat-bruteforce cnf)))
    (is-true assignment)
    (is-true (mini-kernel:eval-cnf cnf assignment))))

(defun test-compile-smt-to-cnf-unsat ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf
               '(:and (:var p (:Bool))
                      (:not (:var p (:Bool))))))
         (assignment (mini-kernel:smt-cnf-sat-bruteforce cnf)))
    (is-equal nil assignment)))

(defun test-solve-cnf-dpll-sat ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf
               '(:or (:var p (:Bool))
                     (:var q (:Bool)))))
         (assignment (mini-kernel:solve-cnf-dpll cnf)))
    (is-true assignment)
    (is-true (mini-kernel:eval-cnf cnf assignment))))

(defun test-solve-cnf-dpll-unsat ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf
               '(:and (:var p (:Bool))
                      (:not (:var p (:Bool))))))
         (assignment (mini-kernel:solve-cnf-dpll cnf)))
    (is-equal nil assignment)))

(defun test-solve-cnf-dpll-defir-parity ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf
               '(:or (:var p (:Bool))
                     (:var q (:Bool)))))
         (native (mini-kernel:solve-cnf-dpll cnf))
         (defir (mini-kernel:solve-cnf-dpll-defir cnf)))
    (is-true native)
    (is-true defir)
    (is-true (equalp native defir))))

(defun test-solve-cnf-under-assumptions-dpll-defir-parity ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf-with-assumptions
               '((a1 (:var p (:Bool)))
                 (a2 (:not (:var p (:Bool)))))
               '(:bool t)))
         (assumptions (mapcar #'second (mini-kernel::smt-cnf-assumptions cnf)))
         (native (mini-kernel:solve-cnf-under-assumptions-dpll cnf assumptions))
         (defir (mini-kernel:solve-cnf-under-assumptions-dpll-defir
                 cnf assumptions)))
    (is-equal native defir)))

(defun test-bitblast-smt-term-defir-parity ()
  (let ((term '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                    (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))
    (is-equal (mini-kernel:bitblast-smt-term term)
              (mini-kernel:bitblast-smt-term-defir term))))

(defun test-bitblast-smt-term-equality ()
  (is-equal '(:and (:= (:bool nil) (:var (x 1) (:Bool)))
                   (:= (:bool t) (:var (x 0) (:Bool))))
            (mini-kernel:bitblast-smt-term
             '(:= (:var x (:BV 2))
                  (:bv-lit 2 1)))))

(defun test-bitblast-smt-term-ult ()
  (is-equal (mini-kernel:eval-smt-term
             '(:ult (:bv-lit 2 1) (:bv-lit 2 2)))
            (mini-kernel:eval-smt-term
             (mini-kernel:bitblast-smt-term
              '(:ult (:bv-lit 2 1) (:bv-lit 2 2))))))

(defun test-run-smt-check-true-formula ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check store '(:= (:bv-lit 8 1) (:bv-lit 8 1)))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :summary)))
    (is-true (typep (first (mini-kernel:backend-result-artifacts result))
                    'mini-kernel:smt-obligation-bundle))))

(defun test-run-smt-check-false-formula ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check store '(:ult (:bv-lit 8 2) (:bv-lit 8 1)))))
    (is-equal :rejected (mini-kernel:backend-result-status result))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :unsat-core)))))

(defun test-run-smt-check-unknown-formula ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:and (:var p (:Bool))
                         (:not (:var q (:Bool)))))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :summary)))
    (is-true (typep (second (mini-kernel:backend-result-artifacts result))
                    'mini-kernel:smt-cnf-bundle))))

(defun test-run-smt-check-boolean-unsat ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:and (:var p (:Bool))
                         (:not (:var p (:Bool)))))))
    (is-equal :rejected (mini-kernel:backend-result-status result))
    (is-equal '(:cnf-form) (mini-kernel:backend-result-evidence result))
    (is-true (typep (second (mini-kernel:backend-result-artifacts result))
                    'mini-kernel:smt-cnf-bundle))))

(defun test-run-smt-check-bv-unsat ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                         (:= (:var x (:BV 2)) (:bv-lit 2 2))))))
    (is-equal :rejected (mini-kernel:backend-result-status result))
    (is-equal '(:normalized-form) (mini-kernel:backend-result-evidence result))))

(defun test-run-smt-check-int-unsat ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:and (:= (:var x (:Int)) (:int-lit 1))
                         (:= (:var y (:Int))
                             (:int-add (:var x (:Int)) (:int-lit 1)))
                         (:int-lt (:var y (:Int)) (:var x (:Int)))))))
    (is-equal :rejected (mini-kernel:backend-result-status result))
    (is-equal '(:normalized-form)
              (mini-kernel:backend-result-evidence result))))

(defun test-run-smt-check-int-accepted ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:and (:int-le (:int-lit 0) (:var x (:Int)))
                         (:int-le (:var x (:Int)) (:int-lit 4))))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '(:normalized-form :int-fragment :normalized-true)
              (mini-kernel:backend-result-evidence result))))

(defun test-run-smt-check-int-unknown ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:int-le (:int-add (:var x (:Int)) (:int-lit 1))
                            (:int-lit 16)))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '(:normalized-form :int-fragment :normalized-true)
              (mini-kernel:backend-result-evidence result))))

(defun test-cnf-unsat-core ()
  (let* ((cnf (mini-kernel:compile-smt-to-cnf-with-assumptions
               '((:a (:var p (:Bool)))
                 (:b (:not (:var p (:Bool)))))
               '(:bool t)))
         (core (mini-kernel:smt-cnf-unsat-core cnf)))
    (is-equal '(:a :b) core)))

(defun test-run-smt-check-assumption-core ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check
                  store
                  '(:assuming ((:a (:var p (:Bool)))
                               (:b (:not (:var p (:Bool)))))
                    (:bool t))))
         (bundle (first (mini-kernel:backend-result-artifacts result))))
    (is-equal :rejected (mini-kernel:backend-result-status result))
    (is-equal '(:a :b) (mini-kernel:smt-obligation-bundle-unsat-core bundle))))

(defun test-smt-obligation-catalog ()
  (let ((entry (mini-kernel:find-admitted-obligation-class :o-normalization-equivalence))
        (int-entry (mini-kernel:find-admitted-obligation-class :o-closed-int-unsat))
        (affine-entry (mini-kernel:find-admitted-obligation-class :o-affine-int-contradiction)))
    (is-true entry)
    (is-true int-entry)
    (is-true affine-entry)
    (is-equal :unsat (mini-kernel:admitted-obligation-class-result-polarity entry))
    (is-equal :normalization-equivalence
              (mini-kernel:admitted-obligation-class-smt-obligation-class-id entry))
    (is-equal :closed-int-unsat
              (mini-kernel:admitted-obligation-class-smt-obligation-class-id int-entry))
    (is-equal :affine-int-contradiction
              (mini-kernel:admitted-obligation-class-smt-obligation-class-id affine-entry))
    (is-equal "Closed normalization-equivalence obligation projected to SMT and discharged by unsat."
              (mini-kernel:admitted-obligation-class-statement entry))))

(defun test-j-smt-obligation-bridge-normalization ()
  (let ((formula '(:= (:bvadd (:bv-lit 8 1) (:bv-lit 8 2))
                     (:extract 7 0 (:concat (:bv-lit 8 0) (:bv-lit 8 3))))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-normalization-equivalence formula))
    (is-true (mini-kernel:normalization-side-condition formula))))

(defun test-j-smt-obligation-bridge-boolean-unsat ()
  (let ((formula '(:and (:bool t) (:bool nil))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-boolean-unsat formula))
    (is-true (mini-kernel:boolean-unsat-side-condition formula))))

(defun test-j-smt-obligation-bridge-bitvector-unsat ()
  (let ((formula '(:and (:= (:bv-lit 2 1) (:bv-lit 2 2))
                       (:bool t))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-bitvector-unsat formula))
    (is-true (mini-kernel:bitvector-unsat-side-condition formula))))

(defun test-j-smt-obligation-bridge-int-unsat ()
  (let ((formula '(:and (:= (:int-lit 1) (:int-lit 1))
                       (:int-lt (:int-lit 2) (:int-lit 1)))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-closed-int-unsat formula))
    (is-true (mini-kernel:int-unsat-side-condition formula))))

(defun test-j-smt-obligation-bridge-affine-int-contradiction ()
  (let ((formula '(:and (:int-ge (:var x (:Int)) (:int-lit 0))
                       (:int-lt (:var x (:Int)) (:int-lit 0)))))
    (is-true (mini-kernel:j-smt-admitted-obligation-bridge
              :o-affine-int-contradiction formula))
    (is-true (mini-kernel:affine-int-contradiction-side-condition formula))))

(defun test-run-smtlib-commands ()
  (let* ((store (mini-kernel:make-advisory-store))
         (results (mini-kernel:run-smtlib-commands
                   store
                   '((set-logic qf_bv)
                     (declare-const path_0_ok Bool)
                     (assert path_0_ok)
                     (echo "path_sat")
                     (check-sat)
                     (push)
                     (assert (not path_0_ok))
                     (echo "path_unsat")
                     (check-sat)
                     (pop)))))
    (is-equal 2 (length results))
    (is-equal "path_sat" (getf (first results) :label))
    (is-equal :accepted (getf (first results) :status))
    (is-equal "path_unsat" (getf (second results) :label))
    (is-equal :rejected (getf (second results) :status))))

(defun test-run-mir-smtlib-file ()
  (let* ((store (mini-kernel:make-advisory-store))
         (path "/home/user0/MIR/formal/smt/G2ClInterlockPaths.smt2")
         (results (mini-kernel:run-smtlib-file store path)))
    (is-equal 16 (length results))
    (is-equal "k18_rol_cl_path_sat" (getf (first results) :label))
    (is-equal :accepted (getf (first results) :status))
    (is-equal "k18_rol_cl_path_path_break_unsat" (getf (second results) :label))
    (is-equal :rejected (getf (second results) :status))
    (is-equal :accepted (getf (third results) :status))
    (is-equal :rejected (getf (fourth results) :status))))

(defun test-run-mir-payload-traversal-search ()
  (let* ((store (mini-kernel:make-advisory-store))
         (path "/home/user0/MIR/formal/smt/payload_traversal_search.smt2")
         (results (mini-kernel:run-smtlib-file store path)))
    (is-equal 1 (length results))
    (is-equal :accepted (getf (first results) :status))))

(defun test-run-mir-stage1-env-walk ()
  (let* ((store (mini-kernel:make-advisory-store))
         (path "/home/user0/MIR/formal/smt/Stage1EnvWalk.smt2")
         (results (mini-kernel:run-smtlib-file store path)))
    (is-equal 5 (length results))
    (is-true (every (lambda (entry) (eq :rejected (getf entry :status))) results))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "normalize-boolean-flattening" #'test-normalize-boolean-flattening)
            (cons "normalize-boolean-constant-fold" #'test-normalize-boolean-constant-fold)
            (cons "normalize-bvadd-constant-fold" #'test-normalize-bvadd-constant-fold)
            (cons "normalize-int-constant-fold" #'test-normalize-int-constant-fold)
            (cons "normalize-concat-extract" #'test-normalize-concat-extract)
            (cons "eval-normalize-preserves-closed-formula" #'test-eval-normalize-preserves-closed-formula)
            (cons "defir-normalize-agrees-on-closed-formula"
                  #'test-defir-normalize-agrees-on-closed-formula)
            (cons "defir-lower-agrees-on-boolean-core"
                  #'test-defir-lower-agrees-on-boolean-core)
            (cons "defir-cnf-agrees-on-boolean-core"
                  #'test-defir-cnf-agrees-on-boolean-core)
            (cons "defir-cnf-with-assumptions-agrees-on-boolean-core"
                  #'test-defir-cnf-with-assumptions-agrees-on-boolean-core)
            (cons "defir-compile-smt-to-cnf-parity"
                  #'test-defir-compile-smt-to-cnf-parity)
            (cons "defir-compile-smt-to-cnf-with-assumptions-parity"
                  #'test-defir-compile-smt-to-cnf-with-assumptions-parity)
            (cons "lower-smt-to-boolean-core" #'test-lower-smt-to-boolean-core)
            (cons "compile-smt-to-cnf-sat" #'test-compile-smt-to-cnf-sat)
            (cons "compile-smt-to-cnf-unsat" #'test-compile-smt-to-cnf-unsat)
            (cons "solve-cnf-dpll-sat" #'test-solve-cnf-dpll-sat)
            (cons "solve-cnf-dpll-unsat" #'test-solve-cnf-dpll-unsat)
            (cons "solve-cnf-dpll-defir-parity" #'test-solve-cnf-dpll-defir-parity)
            (cons "solve-cnf-under-assumptions-dpll-defir-parity"
                  #'test-solve-cnf-under-assumptions-dpll-defir-parity)
            (cons "bitblast-smt-term-defir-parity"
                  #'test-bitblast-smt-term-defir-parity)
            (cons "bitblast-smt-term-equality" #'test-bitblast-smt-term-equality)
            (cons "bitblast-smt-term-ult" #'test-bitblast-smt-term-ult)
            (cons "run-smt-check-true-formula" #'test-run-smt-check-true-formula)
            (cons "run-smt-check-false-formula" #'test-run-smt-check-false-formula)
            (cons "run-smt-check-unknown-formula" #'test-run-smt-check-unknown-formula)
            (cons "run-smt-check-boolean-unsat" #'test-run-smt-check-boolean-unsat)
            (cons "run-smt-check-bv-unsat" #'test-run-smt-check-bv-unsat)
            (cons "run-smt-check-int-unsat" #'test-run-smt-check-int-unsat)
            (cons "run-smt-check-int-accepted" #'test-run-smt-check-int-accepted)
            (cons "run-smt-check-int-unknown" #'test-run-smt-check-int-unknown)
            (cons "cnf-unsat-core" #'test-cnf-unsat-core)
            (cons "run-smt-check-assumption-core" #'test-run-smt-check-assumption-core)
            (cons "smt-obligation-catalog" #'test-smt-obligation-catalog)
            (cons "j-smt-obligation-bridge-normalization"
                  #'test-j-smt-obligation-bridge-normalization)
            (cons "j-smt-obligation-bridge-boolean-unsat"
                  #'test-j-smt-obligation-bridge-boolean-unsat)
            (cons "j-smt-obligation-bridge-bitvector-unsat"
                  #'test-j-smt-obligation-bridge-bitvector-unsat)
            (cons "j-smt-obligation-bridge-int-unsat"
                  #'test-j-smt-obligation-bridge-int-unsat)
            (cons "j-smt-obligation-bridge-affine-int-contradiction"
                  #'test-j-smt-obligation-bridge-affine-int-contradiction)
            (cons "run-smtlib-commands" #'test-run-smtlib-commands)
            (cons "run-mir-smtlib-file" #'test-run-mir-smtlib-file)
            (cons "run-mir-payload-traversal-search"
                  #'test-run-mir-payload-traversal-search)
            (cons "run-mir-stage1-env-walk" #'test-run-mir-stage1-env-walk)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "smt test suite failed"))
    t))
