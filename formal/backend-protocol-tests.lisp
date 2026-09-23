(defpackage :mini-kernel-backend-protocol-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-backend-protocol-tests)

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

(defun test-kernel-backend-registration ()
  (let ((backend (mini-kernel:find-backend 'mini-kernel::kernel-check)))
    (is-true backend)
    (is-equal :trusted (mini-kernel:backend-trust-class backend))
    (is-equal '(:gamma :delta) (mini-kernel:backend-reads backend))
    (is-equal '(:delta) (mini-kernel:backend-writes backend))))

(defun test-frontend-backend-registration ()
  (let ((backend (mini-kernel:find-backend 'mini-kernel::frontend-lower)))
    (is-true backend)
    (is-equal :checked (mini-kernel:backend-trust-class backend))
    (is-equal '(:omega :delta) (mini-kernel:backend-reads backend))
    (is-equal '(:omega) (mini-kernel:backend-writes backend))
    (is-equal '(:core-term) (mini-kernel:backend-proposes backend))))

(defun test-backend-listing ()
  (is-equal '(mini-kernel::audit-check mini-kernel::frontend-lower mini-kernel::kernel-check
               mini-kernel::model-check mini-kernel::smt-check)
            (mapcar #'mini-kernel:backend-id
                    (mini-kernel:list-backends))))

(defun test-kernel-ingested-algorithm-registration ()
  (let ((algorithm (mini-kernel:find-ingested-algorithm :kernel-frozen-core)))
    (is-true algorithm)
    (is-equal :kernel (mini-kernel:ingested-algorithm-lane algorithm))
    (is-equal :equivalence
              (mini-kernel:ingested-algorithm-agreement-theorem-kind algorithm))
    (is-equal :accepted (mini-kernel:ingested-algorithm-status algorithm))
    (is-true (mini-kernel:ingested-algorithm-defir-program algorithm))))

(defun test-smt-ingested-algorithm-registration ()
  (let ((algorithm (mini-kernel:find-ingested-algorithm :smt-core-runtime)))
    (is-true algorithm)
    (is-equal :smt (mini-kernel:ingested-algorithm-lane algorithm))
    (is-equal :bridge
              (mini-kernel:ingested-algorithm-agreement-theorem-kind algorithm))
    (is-equal :accepted (mini-kernel:ingested-algorithm-status algorithm))
    (is-true (mini-kernel:ingested-algorithm-defir-program algorithm))
    (is-equal :partial-defir
              (getf (mini-kernel:ingested-algorithm-metadata algorithm)
                    :ingestion-status))
    (is-equal '(:normalize-core :boolean-core-lowering :cnf-lowering
                :cnf-lowering-assumptions :bitblast
                :smt-cnf-lowering :smt-cnf-lowering-assumptions
                :sat-core :sat-core-assumptions)
              (getf (mini-kernel:ingested-algorithm-metadata algorithm)
                    :ingested-fragments))
    (is-equal '(:var p (:Bool))
              (mini-kernel:call-defir-function
               (mini-kernel:ingested-algorithm-defir-program algorithm)
               'mini-kernel::normalize-smt-term
               '(:and (:bool t) (:var p (:Bool)))))
    (is-equal (mini-kernel:lower-smt-to-boolean-core
               '(:xor (:var p (:Bool)) (:var q (:Bool))))
              (mini-kernel:call-defir-function
               (mini-kernel:ingested-algorithm-defir-program algorithm)
               'mini-kernel::lower-smt-to-boolean-core
               '(:xor (:var p (:Bool)) (:var q (:Bool)))))
    (let* ((native (mini-kernel:compile-boolean-core-to-cnf
                    '(:or (:var p (:Bool)) (:not (:var p (:Bool))))))
           (defir (mini-kernel:call-defir-function
                   (mini-kernel:ingested-algorithm-defir-program algorithm)
                   'mini-kernel::compile-boolean-core-to-cnf
                   '(:or (:var p (:Bool)) (:not (:var p (:Bool)))))))
      (is-equal (mini-kernel:smt-cnf-var-count native)
                (mini-kernel:smt-cnf-var-count defir))
      (is-equal (mini-kernel:smt-cnf-clauses native)
                (mini-kernel:smt-cnf-clauses defir))
      (is-equal (mini-kernel:smt-cnf-root-literal native)
                (mini-kernel:smt-cnf-root-literal defir)))))

(defun test-stage1-ingested-algorithm-registration ()
  (let ((algorithm (mini-kernel:find-ingested-algorithm :stage1-transition-family)))
    (is-true algorithm)
    (is-equal :ts (mini-kernel:ingested-algorithm-lane algorithm))
    (is-equal :soundness
              (mini-kernel:ingested-algorithm-agreement-theorem-kind algorithm))
    (is-equal :accepted (mini-kernel:ingested-algorithm-status algorithm))
    (is-equal nil (mini-kernel:ingested-algorithm-defir-program algorithm))
    (is-true (getf (mini-kernel:ingested-algorithm-metadata algorithm)
                   :program-summary))))

(defun test-ingested-algorithm-listing ()
  (mini-kernel:initialize-ingested-algorithm-registry)
  (is-equal '(:kernel-frozen-core :smt-core-runtime :stage1-transition-family)
            (mapcar #'mini-kernel:ingested-algorithm-name
                    (mini-kernel:list-ingested-algorithms))))

(defun test-ingested-algorithm-operations ()
  (is-equal '(mini-kernel::shiftIndex mini-kernel::shift mini-kernel::subst
               mini-kernel::instantiate mini-kernel::lookup
               mini-kernel::reduceNatRec mini-kernel::reduceEqRec
               mini-kernel::whnf mini-kernel::conv mini-kernel::checkSort
               mini-kernel::infer mini-kernel::check)
            (mini-kernel:ingested-algorithm-operations :kernel-frozen-core))
  (is-equal '(mini-kernel::normalize-smt-term
               mini-kernel::lower-smt-to-boolean-core
               mini-kernel::compile-boolean-core-to-cnf
               mini-kernel::compile-boolean-core-to-cnf-with-assumptions
               mini-kernel::bitblast-smt-term
               mini-kernel::compile-smt-to-cnf
               mini-kernel::compile-smt-to-cnf-with-assumptions
               mini-kernel::solve-cnf-dpll
               mini-kernel::solve-cnf-under-assumptions-dpll)
            (mini-kernel:ingested-algorithm-operations :smt-core-runtime))
  (is-equal '(mini-kernel::boot-scenario mini-kernel::step-runtime
               mini-kernel::run-scenario mini-kernel::promotion-summaries
               mini-kernel::metacircular-summaries mini-kernel::demo)
            (mini-kernel:ingested-algorithm-operations :stage1-transition-family)))

(defun test-execute-ingested-kernel-operation ()
  (is-equal
   '(:lam (:const mini-kernel::nat ()) (:var 0))
   (mini-kernel:execute-ingested-algorithm
    :kernel-frozen-core
    'mini-kernel::shift
    1
    0
    '(:lam (:const mini-kernel::nat ()) (:var 0)))))

(defun test-execute-ingested-smt-operation ()
  (is-equal
   '(:or (:var p (:Bool)) (:var q (:Bool)))
   (mini-kernel:execute-ingested-algorithm
    :smt-core-runtime
    'mini-kernel::normalize-smt-term
    '(:or (:bool nil) (:or (:var p (:Bool)) (:var q (:Bool)))))))

(defun test-execute-ingested-smt-cnf-operation ()
  (let ((cnf (mini-kernel:execute-ingested-algorithm
              :smt-core-runtime
              'mini-kernel::compile-boolean-core-to-cnf
              '(:or (:var p (:Bool)) (:not (:var p (:Bool)))))))
    (is-true (typep cnf 'mini-kernel:smt-cnf))
    (is-true (mini-kernel:solve-cnf-dpll cnf))))

(defun test-execute-ingested-smt-cnf-assumptions-operation ()
  (let ((cnf (mini-kernel:execute-ingested-algorithm
              :smt-core-runtime
              'mini-kernel::compile-boolean-core-to-cnf-with-assumptions
              '((a1 (:var p (:Bool)))
                (a2 (:not (:var p (:Bool)))))
              '(:bool t))))
    (is-true (typep cnf 'mini-kernel:smt-cnf))
    (is-equal '((a1 2) (a2 -2))
              (mini-kernel::smt-cnf-assumptions cnf))))

(defun test-execute-ingested-smt-bitblast-operation ()
  (is-equal
   '(:and (:= (:bool nil) (:var (x 1) (:Bool)))
          (:= (:bool t) (:var (x 0) (:Bool))))
   (mini-kernel:execute-ingested-algorithm
    :smt-core-runtime
    'mini-kernel::bitblast-smt-term
    '(:= (:var x (:BV 2)) (:bv-lit 2 1)))))

(defun test-execute-ingested-smt-compile-smt-to-cnf-operation ()
  (let ((cnf (mini-kernel:execute-ingested-algorithm
              :smt-core-runtime
              'mini-kernel::compile-smt-to-cnf
              (mini-kernel:bitblast-smt-term
               '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                      (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))))
    (is-true (typep cnf 'mini-kernel:smt-cnf))
    (is-true (mini-kernel:solve-cnf-dpll cnf))))

(defun test-execute-ingested-smt-compile-smt-to-cnf-with-assumptions-operation ()
  (let ((cnf (mini-kernel:execute-ingested-algorithm
              :smt-core-runtime
              'mini-kernel::compile-smt-to-cnf-with-assumptions
              '((a1 (:var p (:Bool)))
                (a2 (:not (:var p (:Bool)))))
              '(:bool t))))
    (is-true (typep cnf 'mini-kernel:smt-cnf))
    (is-equal '((a1 2) (a2 -2))
              (mini-kernel::smt-cnf-assumptions cnf))))

(defun test-execute-ingested-smt-solver-operation ()
  (let* ((cnf (mini-kernel:compile-boolean-core-to-cnf
               '(:or (:var p (:Bool)) (:var q (:Bool)))))
         (assignment (mini-kernel:execute-ingested-algorithm
                      :smt-core-runtime
                      'mini-kernel::solve-cnf-dpll
                      cnf)))
    (is-true assignment)
    (is-true (mini-kernel:eval-cnf cnf assignment))))

(defun test-execute-ingested-smt-solver-assumptions-operation ()
  (let* ((cnf (mini-kernel:compile-boolean-core-to-cnf-with-assumptions
               '((a1 (:var p (:Bool)))
                 (a2 (:not (:var p (:Bool)))))
               '(:bool t)))
         (assumptions (mapcar #'second (mini-kernel::smt-cnf-assumptions cnf)))
         (assignment (mini-kernel:execute-ingested-algorithm
                      :smt-core-runtime
                      'mini-kernel::solve-cnf-under-assumptions-dpll
                      cnf
                      assumptions)))
    (is-equal nil assignment)))

(defun test-execute-ingested-stage1-operation-rejects ()
  (signals-kernel-error
   (mini-kernel:execute-ingested-algorithm
    :stage1-transition-family
    'mini-kernel::run-scenario
    :c0-to-c1-to-c2-to-c3)))

(defun test-compare-ingested-kernel-operation ()
  (let ((result (mini-kernel:compare-ingested-algorithm-operation
                 :kernel-frozen-core
                 'mini-kernel::instantiate
                 (list '(:var 0)
                       '(:const mini-kernel::zero ())))))
    (is-true (getf result :matches))
    (is-equal '(:ok (:const mini-kernel::zero ()))
              (getf result :actual))))

(defun test-compare-ingested-smt-operation ()
  (let ((result (mini-kernel:compare-ingested-algorithm-operation
                 :smt-core-runtime
                 'mini-kernel::lower-smt-to-boolean-core
                 (list '(:xor (:var p (:Bool)) (:var q (:Bool)))))))
    (is-true (getf result :matches))
    (is-equal (getf result :expected)
              (getf result :actual))))

(defun test-compare-ingested-smt-cnf-operation ()
  (let ((result (mini-kernel:compare-ingested-algorithm-operation
                 :smt-core-runtime
                 'mini-kernel::compile-boolean-core-to-cnf
                 (list '(:or (:var p (:Bool)) (:not (:var p (:Bool))))))))
    (is-true (getf result :matches))
    (is-true (typep (second (getf result :actual)) 'mini-kernel:smt-cnf))))

(defun test-compare-ingested-smt-cnf-assumptions-operation ()
  (let ((result (mini-kernel:compare-ingested-algorithm-operation
                 :smt-core-runtime
                 'mini-kernel::compile-boolean-core-to-cnf-with-assumptions
                 (list '((a1 (:var p (:Bool)))
                         (a2 (:not (:var p (:Bool)))))
                       '(:bool t)))))
    (is-true (getf result :matches))
    (is-true (typep (second (getf result :actual)) 'mini-kernel:smt-cnf))))

(defun test-compare-ingested-smt-bitblast-operation ()
  (let ((result (mini-kernel:compare-ingested-algorithm-operation
                 :smt-core-runtime
                 'mini-kernel::bitblast-smt-term
                 (list '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                              (:ult (:var x (:BV 2)) (:bv-lit 2 2)))))))
    (is-true (getf result :matches))
    (is-equal (getf result :expected)
              (getf result :actual))))

(defun test-compare-ingested-smt-compile-smt-to-cnf-operation ()
  (let ((result (mini-kernel:compare-ingested-algorithm-operation
                 :smt-core-runtime
                 'mini-kernel::compile-smt-to-cnf
                 (list (mini-kernel:bitblast-smt-term
                        '(:and (:= (:var x (:BV 2)) (:bv-lit 2 1))
                               (:ult (:var x (:BV 2)) (:bv-lit 2 2))))))))
    (is-true (getf result :matches))
    (is-true (typep (second (getf result :actual)) 'mini-kernel:smt-cnf))))

(defun test-compare-ingested-smt-compile-smt-to-cnf-with-assumptions-operation ()
  (let ((result (mini-kernel:compare-ingested-algorithm-operation
                 :smt-core-runtime
                 'mini-kernel::compile-smt-to-cnf-with-assumptions
                 (list '((a1 (:var p (:Bool)))
                         (a2 (:not (:var p (:Bool)))))
                       '(:bool t)))))
    (is-true (getf result :matches))
    (is-true (typep (second (getf result :actual)) 'mini-kernel:smt-cnf))))

(defun test-compare-ingested-smt-solver-operation ()
  (let* ((cnf (mini-kernel:compile-boolean-core-to-cnf
               '(:or (:var p (:Bool)) (:var q (:Bool)))))
         (result (mini-kernel:compare-ingested-algorithm-operation
                  :smt-core-runtime
                  'mini-kernel::solve-cnf-dpll
                  (list cnf))))
    (is-true (getf result :matches))
    (is-true (typep (second (getf result :actual)) 'vector))))

(defun test-compare-ingested-smt-solver-assumptions-operation ()
  (let* ((cnf (mini-kernel:compile-boolean-core-to-cnf-with-assumptions
               '((a1 (:var p (:Bool)))
                 (a2 (:not (:var p (:Bool)))))
               '(:bool t)))
         (assumptions (mapcar #'second (mini-kernel::smt-cnf-assumptions cnf)))
         (result (mini-kernel:compare-ingested-algorithm-operation
                  :smt-core-runtime
                  'mini-kernel::solve-cnf-under-assumptions-dpll
                  (list cnf assumptions))))
    (is-true (getf result :matches))
    (is-equal '(:ok nil) (getf result :actual))))

(defun test-advisory-backend-registration ()
  (let ((backend (mini-kernel:find-backend 'mini-kernel::smt-check)))
    (is-true backend)
    (is-equal :advisory (mini-kernel:backend-trust-class backend))
    (is-equal '(:alpha) (mini-kernel:backend-reads backend))
    (is-equal '(:alpha) (mini-kernel:backend-writes backend))
    (is-equal '(:model) (mini-kernel:backend-proposes backend))))

(defun test-model-backend-registration ()
  (let ((backend (mini-kernel:find-backend 'mini-kernel::model-check)))
    (is-true backend)
    (is-equal :advisory (mini-kernel:backend-trust-class backend))
    (is-equal '(:rho) (mini-kernel:backend-reads backend))
    (is-equal '(:alpha) (mini-kernel:backend-writes backend))
    (is-equal '(:trace) (mini-kernel:backend-proposes backend))))

(defun test-audit-backend-registration ()
  (let ((backend (mini-kernel:find-backend 'mini-kernel::audit-check)))
    (is-true backend)
    (is-equal :checked (mini-kernel:backend-trust-class backend))
    (is-equal '(:delta :alpha :rho) (mini-kernel:backend-reads backend))
    (is-equal '(:rho) (mini-kernel:backend-writes backend))
    (is-equal '(:candidate) (mini-kernel:backend-proposes backend))))

(defun test-negative-nonkernel-cannot-write-delta ()
  (signals-kernel-error
   (mini-kernel::register-backend
    (mini-kernel::make-backend
     :id 'bad-checked-backend
     :layer :surface
     :trust-class :checked
     :candidate-kind :surface-term
     :spec-kind :lowering-spec
     :evidence-kind :lowered-term
     :statuses '(:accepted)
     :reads '(:omega)
     :writes '(:delta)
     :proposes '(:core-term)))))

(defun test-negative-advisory-cannot-read-delta ()
  (signals-kernel-error
   (mini-kernel::register-backend
    (mini-kernel::make-backend
     :id 'bad-advisory-backend
     :layer :solver
     :trust-class :advisory
     :candidate-kind :formula
     :spec-kind :solver-spec
     :evidence-kind :model
     :statuses '(:accepted :unknown)
     :reads '(:delta :alpha)
     :writes '(:alpha)
     :proposes '(:model)))))

(defun test-negative-only-kernel-is-trusted ()
  (signals-kernel-error
   (mini-kernel::register-backend
    (mini-kernel::make-backend
     :id 'bad-trusted-backend
     :layer :surface
     :trust-class :trusted
     :candidate-kind :surface-term
     :spec-kind :lowering-spec
     :evidence-kind :lowered-term
     :statuses '(:accepted)
     :reads '(:gamma)
     :writes '()
     :proposes '(:core-term)))))

(defun test-advisory-artifact-store ()
  (let* ((store (mini-kernel:make-advisory-store))
         (artifact (mini-kernel::make-advisory-artifact
                    :backend-id 'mini-kernel::smt-check
                    :kind :model
                    :payload '((x . 1))
                    :metadata '(:query-id q1))))
    (mini-kernel:advisory-store-add store artifact)
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :model)))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-backend store 'mini-kernel::smt-check)))))

(defun test-emit-advisory-artifact ()
  (let ((store (mini-kernel:make-advisory-store)))
    (mini-kernel:emit-advisory-artifact
     store
     'mini-kernel::smt-check
     :counterexample
     '((branch . false))
     '(:query-id q2))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :counterexample)))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-backend store 'mini-kernel::smt-check)))))

(defun test-negative-nonadvisory-cannot-emit-advisory-artifact ()
  (signals-kernel-error
   (mini-kernel:emit-advisory-artifact
    (mini-kernel:make-advisory-store)
    'mini-kernel::frontend-lower
    :report
    'bad
    '())))

(defun test-negative-invalid-advisory-kind ()
  (signals-kernel-error
   (mini-kernel:emit-advisory-artifact
    (mini-kernel:make-advisory-store)
    'mini-kernel::smt-check
    :not-a-kind
    'bad
    '())))

(defun test-smt-stub-sat-result ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check store '(:sat ((x . 1))))))
    (is-equal 'mini-kernel::smt-check (mini-kernel:backend-result-backend-id result))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '(:model) (mini-kernel:backend-result-evidence result))
    (is-equal 1 (length (mini-kernel:backend-result-artifacts result)))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :model)))))

(defun test-smt-stub-unsat-result ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check store '(:unsat-core (c1 c2)))))
    (is-equal :rejected (mini-kernel:backend-result-status result))
    (is-equal '(:unsat-core) (mini-kernel:backend-result-evidence result))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :unsat-core)))))

(defun test-smt-stub-unknown-result ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-smt-check store :unknown)))
    (is-equal :unknown (mini-kernel:backend-result-status result))
    (is-equal '() (mini-kernel:backend-result-artifacts result))
    (is-equal 0 (length (mini-kernel:advisory-store-find-by-backend store 'mini-kernel::smt-check)))))

(defun test-model-check-invariant-result ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-model-check store '(:invariant (:activation ok)))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '(:invariant) (mini-kernel:backend-result-evidence result))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :invariant)))))

(defun test-model-check-counterexample-result ()
  (let* ((store (mini-kernel:make-advisory-store))
         (result (mini-kernel:run-model-check store '(:counterexample (:bad-transition s0 s1)))))
    (is-equal :counterexample (mini-kernel:backend-result-status result))
    (is-equal '(:trace) (mini-kernel:backend-result-evidence result))
    (is-equal 1 (length (mini-kernel:advisory-store-find-by-kind store :trace)))))

(defun test-stage-corpus-agreement ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (result (mini-kernel:check-stage-corpus-agreement stage)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (mini-kernel:backend-result-artifacts result))))

(defun test-stage-manifest-and-explicit-certificates ()
  (let* ((entries (list (first (mini-kernel-corpus:accepted-certificates))
                        (second (mini-kernel-corpus:accepted-certificates))))
         (manifest (mini-kernel:make-stage-manifest
                    :stage-id 'stage-explicit
                    :env-digest :bootstrap-v1
                    :config-digest mini-kernel::*current-config-digest*
                    :certificate-ids (mapcar #'mini-kernel-corpus:corpus-entry-id entries)
                    :provenance '(:stage explicit)))
         (stage (mini-kernel:make-stage :id 'stage-explicit
                                        :manifest manifest
                                        :certificates entries))
         (result (mini-kernel:check-stage-certificates stage)))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal '() (mini-kernel:backend-result-artifacts result))))

(defun test-certificate-to-corpus-entry ()
  (let* ((certificate (mini-kernel:make-typing-certificate
                       '()
                       '(:const mini-kernel::zero ())
                       '(:const mini-kernel::nat ())
                       :bootstrap-v1
                       :checker-ids '(kl)
                       :metadata '(:certificate-id :zero-stage-cert)))
         (entry (mini-kernel:certificate->corpus-entry certificate)))
    (is-equal :zero-stage-cert (mini-kernel-corpus:corpus-entry-id entry))
    (is-equal certificate (mini-kernel-corpus:corpus-entry-certificate entry))))

(defun test-stage-normalizes-raw-certificates ()
  (let* ((certificates
           (list
            (mini-kernel:make-typing-certificate
             '()
             '(:const mini-kernel::zero ())
             '(:const mini-kernel::nat ())
             :bootstrap-v1
             :checker-ids '(kl)
             :metadata '(:certificate-id :zero-stage-cert))
            (mini-kernel:make-typing-certificate
             '()
             '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
             '(:const mini-kernel::nat ())
             :bootstrap-v1
             :checker-ids '(kl)
             :metadata '(:certificate-id :succ-stage-cert))))
         (stage (mini-kernel:make-stage :id 'stage-raw
                                        :certificates certificates))
         (result (mini-kernel:check-stage-certificates stage)))
    (is-equal '(:zero-stage-cert :succ-stage-cert)
              (mapcar #'mini-kernel-corpus:corpus-entry-id
                      (mini-kernel:stage-certificates stage)))
    (is-equal :accepted (mini-kernel:backend-result-status result))))

(defun test-stage-bounded-obligations-pass ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (result (mini-kernel:check-stage-bounded-obligations stage '((:unsat-core (c1 c2))))))
    (is-equal :accepted (mini-kernel:backend-result-status result))))

(defun test-stage-bounded-obligations-block ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (result (mini-kernel:check-stage-bounded-obligations stage '((:sat ((x . 1)))))))
    (is-equal :counterexample (mini-kernel:backend-result-status result))
    (is-equal 2 (length (mini-kernel:backend-result-artifacts result)))))

(defun test-stage-bounded-admitted-bridge-pass ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (result (mini-kernel:check-stage-bounded-obligations
                  stage
                  '((:admitted-bridge :o-affine-int-contradiction
                     (:and (:int-ge (:var x (:Int)) (:int-lit 0))
                           (:int-lt (:var x (:Int)) (:int-lit 0))))))))
    (is-equal :accepted (mini-kernel:backend-result-status result))
    (is-equal :o-affine-int-contradiction
              (getf (first (mini-kernel:backend-result-artifacts result)) :bridge))))

(defun test-stage-activation-protocol-pass ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (result (mini-kernel:check-stage-activation-protocol stage '(:invariant (:activation ok)))))
    (is-equal :accepted (mini-kernel:backend-result-status result))))

(defun test-stage-activation-protocol-block ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (result (mini-kernel:check-stage-activation-protocol stage '(:counterexample (:bad-transition s0 s1)))))
    (is-equal :counterexample (mini-kernel:backend-result-status result))))

(defun test-ingest-lsip-closure-report ()
  (let ((bundle (mini-kernel:ingest-lsip-closure-report
                 "/home/user0/LSIP/generated/closure_stack_report.json")))
    (is-equal :accepted (mini-kernel:external-report-bundle-status bundle))
    (is-equal :lsip-closure-report (mini-kernel:external-report-bundle-report-kind bundle))))

(defun test-ingest-mir-report ()
  (let ((bundle (mini-kernel:ingest-mir-report
                 "/home/user0/MIR/formal/out/stage1_selector_witness.json"
                 :artifact-id :mir-selector)))
    (is-equal :accepted (mini-kernel:external-report-bundle-status bundle))
    (is-equal :mir-report (mini-kernel:external-report-bundle-report-kind bundle))))

(defun test-activate-stage-if-verified ()
  (let ((stage (mini-kernel:make-stage :id 'stage-1)))
    (mini-kernel:activate-stage-if-verified
     stage
     :obligations '((:unsat-core (c1 c2)))
    :protocol-query '(:invariant (:activation ok)))
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-activate-stage-with-external-bundles ()
  (let ((stage (mini-kernel:make-stage
                :id 'stage-ext
                :external-bundles
                (list
                 (mini-kernel:ingest-lsip-closure-report
                  "/home/user0/LSIP/generated/closure_stack_report.json")
                 (mini-kernel:ingest-mir-report
                  "/home/user0/MIR/formal/out/stage1_selector_witness.json"
                  :artifact-id :mir-selector)))))
    (mini-kernel:activate-stage-if-verified
     stage
     :obligations '((:unsat-core (c1 c2)))
     :protocol-query '(:invariant (:activation ok)))
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-verify-stage-bundle ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok)))))
    (is-equal 'stage-1 (mini-kernel:stage-verification-bundle-stage-id bundle))
    (is-equal :accepted
              (mini-kernel:backend-result-status
               (mini-kernel:stage-verification-bundle-agreement bundle)))
    (is-equal :accepted
              (mini-kernel:backend-result-status
               (mini-kernel:stage-verification-bundle-bounded bundle)))
    (is-equal :accepted
              (mini-kernel:backend-result-status
               (mini-kernel:stage-verification-bundle-protocol bundle)))))

(defun test-activate-stage-from-bundle ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok)))))
    (mini-kernel:activate-stage-from-bundle stage bundle)
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-activate-stage-from-bundle-with-smt-replay ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-smt))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:and (:var p (:Bool))
                                       (:not (:var p (:Bool)))))
                  :protocol-query '(:invariant (:activation ok)))))
    (mini-kernel:activate-stage-from-bundle stage bundle)
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-activate-stage-from-bundle-with-protocol-replay ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-proto))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok)))))
    (mini-kernel:activate-stage-from-bundle stage bundle)
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-emit-stage-verification-bundle ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok))))
         (store (mini-kernel:make-proposal-store))
         (proposal (mini-kernel:emit-stage-verification-bundle
                    store stage bundle '(:source replayable-gate))))
    (is-equal 'mini-kernel::audit-check (mini-kernel:checked-proposal-backend-id proposal))
    (is-equal :candidate (mini-kernel:checked-proposal-kind proposal))
    (is-equal 1 (length (mini-kernel:proposal-store-find-by-backend store 'mini-kernel::audit-check)))))

(defun test-activate-stage-from-proposal ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok))))
         (proposal (mini-kernel:emit-stage-verification-bundle
                    (mini-kernel:make-proposal-store)
                    stage
                    bundle
                    '(:source replayable-gate))))
    (mini-kernel:activate-stage-from-proposal stage proposal)
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-activate-explicit-stage-if-verified ()
  (let* ((entries (list (first (mini-kernel-corpus:accepted-certificates))
                        (second (mini-kernel-corpus:accepted-certificates))))
         (manifest (mini-kernel:make-stage-manifest
                    :stage-id 'stage-explicit
                    :env-digest :bootstrap-v1
                    :config-digest mini-kernel::*current-config-digest*
                    :certificate-ids (mapcar #'mini-kernel-corpus:corpus-entry-id entries)
                    :provenance '(:stage explicit)))
         (stage (mini-kernel:make-stage :id 'stage-explicit
                                        :manifest manifest
                                        :certificates entries)))
    (mini-kernel:activate-stage-if-verified
     stage
     :obligations '((:unsat-core (c1 c2)))
     :protocol-query '(:invariant (:activation ok)))
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-activate-stage-from-compiled-surface-certificates ()
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
                       n)))
              (:id :zero-has-nat
               :term mini-kernel::zero
               :type mini-kernel::nat))
            :env (mini-kernel:make-bootstrap-env)))
         (stage (mini-kernel:make-stage :id 'stage-surface
                                        :certificates certificates)))
    (mini-kernel:activate-stage-if-verified
     stage
     :obligations '((:unsat-core (c1 c2)))
     :protocol-query '(:invariant (:activation ok)))
    (is-true (mini-kernel:stage-activatedp stage))))

(defun test-make-stage-from-surface-specs ()
  (let ((stage (mini-kernel:make-stage-from-surface-specs
                :id 'stage-auto
                :surface-specs
                '((:id :zero-has-nat
                   :term mini-kernel::zero
                   :type mini-kernel::nat)))))
    (is-equal 'stage-auto (mini-kernel:stage-id stage))
    (is-equal '(:stage mini-kernel::surface-compiled)
              (mini-kernel:stage-manifest-provenance
               (mini-kernel::stage-manifest stage)))
    (is-equal '(:zero-has-nat)
              (mini-kernel:stage-manifest-certificate-ids
               (mini-kernel::stage-manifest stage)))))

(defun test-verify-stage-from-surface-specs ()
  (multiple-value-bind (stage bundle)
      (mini-kernel:verify-stage-from-surface-specs
       :id 'stage-auto
       :surface-specs
       '((:id :zero-has-nat
          :term mini-kernel::zero
          :type mini-kernel::nat))
       :obligations '((:unsat-core (c1 c2)))
       :protocol-query '(:invariant (:activation ok)))
    (is-equal 'stage-auto (mini-kernel:stage-id stage))
    (is-equal :accepted
              (mini-kernel:backend-result-status
               (mini-kernel:stage-verification-bundle-agreement bundle)))
    (is-equal :accepted
              (mini-kernel:backend-result-status
               (mini-kernel:stage-verification-bundle-bounded bundle)))
    (is-equal :accepted
              (mini-kernel:backend-result-status
               (mini-kernel:stage-verification-bundle-protocol bundle)))))

(defun test-emit-verified-stage-proposal ()
  (let ((store (mini-kernel:make-proposal-store)))
    (multiple-value-bind (stage bundle proposal)
        (mini-kernel:emit-verified-stage-proposal
         store
         :id 'stage-auto
         :surface-specs
         '((:id :zero-has-nat
            :term mini-kernel::zero
            :type mini-kernel::nat))
         :obligations '((:unsat-core (c1 c2)))
         :protocol-query '(:invariant (:activation ok)))
      (declare (ignore bundle))
      (mini-kernel:activate-stage-from-proposal stage proposal)
      (is-true (mini-kernel:stage-activatedp stage))
      (is-equal 1
                (length
                 (mini-kernel:proposal-store-find-by-backend
                  store 'mini-kernel::audit-check))))))

(defun test-checked-proposal-store ()
  (let* ((store (mini-kernel:make-proposal-store))
         (proposal (mini-kernel::make-checked-proposal
                    :backend-id 'mini-kernel::frontend-lower
                    :kind :core-term
                    :payload '(:const mini-kernel::zero ())
                    :metadata '(:source test))))
    (mini-kernel:proposal-store-add store proposal)
    (is-equal 1 (length (mini-kernel:proposal-store-find-by-kind store :core-term)))
    (is-equal 1 (length (mini-kernel:proposal-store-find-by-backend store 'mini-kernel::frontend-lower)))))

(defun test-emit-checked-proposal ()
  (let ((store (mini-kernel:make-proposal-store)))
    (mini-kernel:emit-checked-proposal
     store
     'mini-kernel::frontend-lower
     :core-term
     '(:const mini-kernel::nat ())
     '(:source frontend))
    (is-equal 1 (length (mini-kernel:proposal-store-find-by-kind store :core-term)))
    (is-equal 1 (length (mini-kernel:proposal-store-find-by-backend store 'mini-kernel::frontend-lower)))))

(defun test-negative-smt-stub-query ()
  (signals-kernel-error
   (mini-kernel:run-smt-check
    (mini-kernel:make-advisory-store)
    '(:bogus t))))

(defun test-negative-advisory-cannot-emit-checked-proposal ()
  (signals-kernel-error
   (mini-kernel:emit-checked-proposal
    (mini-kernel:make-proposal-store)
    'mini-kernel::smt-check
    :model
    'bad
    '())))

(defun test-negative-frontend-cannot-propose-proof-term ()
  (signals-kernel-error
   (mini-kernel:emit-checked-proposal
    (mini-kernel:make-proposal-store)
    'mini-kernel::frontend-lower
    :proof-term
    'bad
    '())))

(defun test-negative-activate-stage-on-solver-counterexample ()
  (signals-kernel-error
   (mini-kernel:activate-stage-if-verified
    (mini-kernel:make-stage :id 'stage-bad)
    :obligations '((:sat ((x . 1))))
    :protocol-query '(:invariant (:activation ok)))))

(defun test-negative-activate-stage-on-model-counterexample ()
  (signals-kernel-error
   (mini-kernel:activate-stage-if-verified
    (mini-kernel:make-stage :id 'stage-bad)
    :obligations '((:unsat-core (c1 c2)))
    :protocol-query '(:counterexample (:bad-transition s0 s1)))))

(defun test-negative-activate-stage-from-tampered-bundle ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok)))))
    (setf (mini-kernel:stage-verification-bundle-config-digest bundle) '(:config-id :wrong))
    (signals-kernel-error
     (mini-kernel:activate-stage-from-bundle stage bundle))))

(defun test-negative-activate-stage-from-tampered-smt-bundle ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-smt))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:and (:var p (:Bool))
                                       (:not (:var p (:Bool)))))
                  :protocol-query '(:invariant (:activation ok))))
         (bounded-artifacts
           (mini-kernel:backend-result-artifacts
            (mini-kernel:stage-verification-bundle-bounded bundle)))
         (smt-bundle
           (find-if (lambda (artifact)
                      (typep artifact 'mini-kernel:smt-obligation-bundle))
                    bounded-artifacts)))
    (setf (mini-kernel:smt-obligation-bundle-input smt-bundle)
          '(:or (:var p (:Bool)) (:not (:var p (:Bool)))))
    (signals-kernel-error
     (mini-kernel:activate-stage-from-bundle stage bundle))))

(defun test-negative-activate-stage-from-tampered-protocol-bundle ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-proto))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok))))
         (protocol-artifacts
           (mini-kernel:backend-result-artifacts
            (mini-kernel:stage-verification-bundle-protocol bundle)))
         (protocol-bundle
           (find-if (lambda (artifact)
                      (typep artifact 'mini-kernel:protocol-check-bundle))
                    protocol-artifacts)))
    (setf (mini-kernel:protocol-check-bundle-query protocol-bundle)
          '(:counterexample (:activation bad)))
    (signals-kernel-error
     (mini-kernel:activate-stage-from-bundle stage bundle))))

(defun test-negative-activate-stage-from-tampered-external-bundle ()
  (let* ((stage (mini-kernel:make-stage
                 :id 'stage-ext
                 :external-bundles
                 (list
                  (mini-kernel:ingest-lsip-closure-report
                   "/home/user0/LSIP/generated/closure_stack_report.json"))))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok))))
         (external-bundle (first (mini-kernel:stage-external-bundles stage))))
    (setf (mini-kernel:external-report-bundle-source-path external-bundle)
          "/home/user0/MIR/formal/out/stage1_selector_witness.json")
    (signals-kernel-error
     (mini-kernel:activate-stage-from-bundle stage bundle))))

(defun test-negative-activate-stage-from-tampered-proposal ()
  (let* ((stage (mini-kernel:make-stage :id 'stage-1))
         (bundle (mini-kernel:verify-stage
                  stage
                  :obligations '((:unsat-core (c1 c2)))
                  :protocol-query '(:invariant (:activation ok))))
         (proposal (mini-kernel:emit-stage-verification-bundle
                    (mini-kernel:make-proposal-store)
                    stage
                    bundle
                    '(:source replayable-gate))))
    (setf (getf (mini-kernel:checked-proposal-payload proposal) :config-digest) '(:config-id :wrong))
    (signals-kernel-error
     (mini-kernel:activate-stage-from-proposal stage proposal))))

(defun test-negative-stage-missing-manifest-certificate ()
  (let* ((entries (list (first (mini-kernel-corpus:accepted-certificates))))
         (manifest (mini-kernel:make-stage-manifest
                    :stage-id 'stage-missing
                    :env-digest :bootstrap-v1
                    :config-digest mini-kernel::*current-config-digest*
                    :certificate-ids '(:proof-demo :zero-has-nat)
                    :provenance '(:stage explicit)))
         (stage (mini-kernel:make-stage :id 'stage-missing
                                        :manifest manifest
                                        :certificates entries)))
    (signals-kernel-error
     (mini-kernel:activate-stage-if-verified
      stage
      :obligations '((:unsat-core (c1 c2)))
      :protocol-query '(:invariant (:activation ok))))))

(defun test-negative-stage-manifest-config-mismatch ()
  (let ((stage (mini-kernel:make-stage
                :id 'stage-mismatch
                :manifest (mini-kernel:make-stage-manifest
                           :stage-id 'stage-mismatch
                           :env-digest :bootstrap-v1
                           :config-digest '(:config-id :wrong)
                           :certificate-ids '()
                           :provenance '(:stage explicit)))))
    (signals-kernel-error
     (mini-kernel:activate-stage-if-verified
      stage
     :obligations '((:unsat-core (c1 c2)))
     :protocol-query '(:invariant (:activation ok))))))

(defun test-negative-stage-normalization-bad-item ()
  (signals-kernel-error
   (mini-kernel:make-stage :id 'stage-bad
                           :certificates '(not-a-certificate))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "kernel-backend-registration" #'test-kernel-backend-registration)
            (cons "frontend-backend-registration" #'test-frontend-backend-registration)
            (cons "advisory-backend-registration" #'test-advisory-backend-registration)
            (cons "model-backend-registration" #'test-model-backend-registration)
            (cons "audit-backend-registration" #'test-audit-backend-registration)
            (cons "backend-listing" #'test-backend-listing)
            (cons "kernel-ingested-algorithm-registration"
                  #'test-kernel-ingested-algorithm-registration)
            (cons "smt-ingested-algorithm-registration"
                  #'test-smt-ingested-algorithm-registration)
            (cons "stage1-ingested-algorithm-registration"
                  #'test-stage1-ingested-algorithm-registration)
            (cons "ingested-algorithm-listing" #'test-ingested-algorithm-listing)
            (cons "ingested-algorithm-operations" #'test-ingested-algorithm-operations)
            (cons "execute-ingested-kernel-operation"
                  #'test-execute-ingested-kernel-operation)
            (cons "execute-ingested-smt-operation"
                  #'test-execute-ingested-smt-operation)
            (cons "execute-ingested-smt-cnf-operation"
                  #'test-execute-ingested-smt-cnf-operation)
            (cons "execute-ingested-smt-cnf-assumptions-operation"
                  #'test-execute-ingested-smt-cnf-assumptions-operation)
            (cons "execute-ingested-smt-bitblast-operation"
                  #'test-execute-ingested-smt-bitblast-operation)
            (cons "execute-ingested-smt-compile-smt-to-cnf-operation"
                  #'test-execute-ingested-smt-compile-smt-to-cnf-operation)
            (cons "execute-ingested-smt-compile-smt-to-cnf-with-assumptions-operation"
                  #'test-execute-ingested-smt-compile-smt-to-cnf-with-assumptions-operation)
            (cons "execute-ingested-smt-solver-operation"
                  #'test-execute-ingested-smt-solver-operation)
            (cons "execute-ingested-smt-solver-assumptions-operation"
                  #'test-execute-ingested-smt-solver-assumptions-operation)
            (cons "execute-ingested-stage1-operation-rejects"
                  #'test-execute-ingested-stage1-operation-rejects)
            (cons "compare-ingested-kernel-operation"
                  #'test-compare-ingested-kernel-operation)
            (cons "compare-ingested-smt-operation"
                  #'test-compare-ingested-smt-operation)
            (cons "compare-ingested-smt-cnf-operation"
                  #'test-compare-ingested-smt-cnf-operation)
            (cons "compare-ingested-smt-cnf-assumptions-operation"
                  #'test-compare-ingested-smt-cnf-assumptions-operation)
            (cons "compare-ingested-smt-bitblast-operation"
                  #'test-compare-ingested-smt-bitblast-operation)
            (cons "compare-ingested-smt-compile-smt-to-cnf-operation"
                  #'test-compare-ingested-smt-compile-smt-to-cnf-operation)
            (cons "compare-ingested-smt-compile-smt-to-cnf-with-assumptions-operation"
                  #'test-compare-ingested-smt-compile-smt-to-cnf-with-assumptions-operation)
            (cons "compare-ingested-smt-solver-operation"
                  #'test-compare-ingested-smt-solver-operation)
            (cons "compare-ingested-smt-solver-assumptions-operation"
                  #'test-compare-ingested-smt-solver-assumptions-operation)
            (cons "advisory-artifact-store" #'test-advisory-artifact-store)
            (cons "emit-advisory-artifact" #'test-emit-advisory-artifact)
            (cons "smt-stub-sat-result" #'test-smt-stub-sat-result)
            (cons "smt-stub-unsat-result" #'test-smt-stub-unsat-result)
            (cons "smt-stub-unknown-result" #'test-smt-stub-unknown-result)
            (cons "model-check-invariant-result" #'test-model-check-invariant-result)
            (cons "model-check-counterexample-result" #'test-model-check-counterexample-result)
            (cons "stage-corpus-agreement" #'test-stage-corpus-agreement)
            (cons "stage-manifest-and-explicit-certificates"
                  #'test-stage-manifest-and-explicit-certificates)
            (cons "certificate-to-corpus-entry" #'test-certificate-to-corpus-entry)
            (cons "stage-normalizes-raw-certificates" #'test-stage-normalizes-raw-certificates)
            (cons "stage-bounded-obligations-pass" #'test-stage-bounded-obligations-pass)
            (cons "stage-bounded-obligations-block" #'test-stage-bounded-obligations-block)
            (cons "stage-bounded-admitted-bridge-pass" #'test-stage-bounded-admitted-bridge-pass)
            (cons "stage-activation-protocol-pass" #'test-stage-activation-protocol-pass)
            (cons "stage-activation-protocol-block" #'test-stage-activation-protocol-block)
            (cons "ingest-lsip-closure-report" #'test-ingest-lsip-closure-report)
            (cons "ingest-mir-report" #'test-ingest-mir-report)
            (cons "activate-stage-if-verified" #'test-activate-stage-if-verified)
            (cons "activate-stage-with-external-bundles"
                  #'test-activate-stage-with-external-bundles)
            (cons "verify-stage-bundle" #'test-verify-stage-bundle)
            (cons "activate-stage-from-bundle" #'test-activate-stage-from-bundle)
            (cons "activate-stage-from-bundle-with-smt-replay"
                  #'test-activate-stage-from-bundle-with-smt-replay)
            (cons "activate-stage-from-bundle-with-protocol-replay"
                  #'test-activate-stage-from-bundle-with-protocol-replay)
            (cons "emit-stage-verification-bundle" #'test-emit-stage-verification-bundle)
            (cons "activate-stage-from-proposal" #'test-activate-stage-from-proposal)
            (cons "activate-explicit-stage-if-verified" #'test-activate-explicit-stage-if-verified)
            (cons "activate-stage-from-compiled-surface-certificates"
                  #'test-activate-stage-from-compiled-surface-certificates)
            (cons "make-stage-from-surface-specs" #'test-make-stage-from-surface-specs)
            (cons "verify-stage-from-surface-specs" #'test-verify-stage-from-surface-specs)
            (cons "emit-verified-stage-proposal" #'test-emit-verified-stage-proposal)
            (cons "checked-proposal-store" #'test-checked-proposal-store)
            (cons "emit-checked-proposal" #'test-emit-checked-proposal)
            (cons "negative-nonkernel-cannot-write-delta" #'test-negative-nonkernel-cannot-write-delta)
            (cons "negative-advisory-cannot-read-delta" #'test-negative-advisory-cannot-read-delta)
            (cons "negative-only-kernel-is-trusted" #'test-negative-only-kernel-is-trusted)
            (cons "negative-invalid-advisory-kind" #'test-negative-invalid-advisory-kind)
            (cons "negative-smt-stub-query" #'test-negative-smt-stub-query)
            (cons "negative-activate-stage-on-solver-counterexample"
                  #'test-negative-activate-stage-on-solver-counterexample)
            (cons "negative-activate-stage-on-model-counterexample"
                  #'test-negative-activate-stage-on-model-counterexample)
            (cons "negative-activate-stage-from-tampered-bundle"
                  #'test-negative-activate-stage-from-tampered-bundle)
            (cons "negative-activate-stage-from-tampered-smt-bundle"
                  #'test-negative-activate-stage-from-tampered-smt-bundle)
            (cons "negative-activate-stage-from-tampered-protocol-bundle"
                  #'test-negative-activate-stage-from-tampered-protocol-bundle)
            (cons "negative-activate-stage-from-tampered-external-bundle"
                  #'test-negative-activate-stage-from-tampered-external-bundle)
            (cons "negative-activate-stage-from-tampered-proposal"
                  #'test-negative-activate-stage-from-tampered-proposal)
            (cons "negative-stage-missing-manifest-certificate"
                  #'test-negative-stage-missing-manifest-certificate)
            (cons "negative-stage-manifest-config-mismatch"
                  #'test-negative-stage-manifest-config-mismatch)
            (cons "negative-stage-normalization-bad-item"
                  #'test-negative-stage-normalization-bad-item)
            (cons "negative-advisory-cannot-emit-checked-proposal"
                  #'test-negative-advisory-cannot-emit-checked-proposal)
            (cons "negative-frontend-cannot-propose-proof-term"
                  #'test-negative-frontend-cannot-propose-proof-term)
            (cons "negative-nonadvisory-cannot-emit-advisory-artifact"
                  #'test-negative-nonadvisory-cannot-emit-advisory-artifact)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "backend protocol test suite failed"))
    t))
