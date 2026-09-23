(defpackage :mini-kernel-constitutional-runtime-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-constitutional-runtime-tests)

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

(defun test-runtime-constitution-rehydration ()
  (mini-kernel:reset-runtime-constitution-registry)
  (let* ((lhs (mini-kernel:current-runtime-constitution))
         (rhs (mini-kernel:current-runtime-constitution))
         (constitutions (mini-kernel:list-runtime-constitutions)))
    (is-true (typep lhs 'mini-kernel:runtime-constitution))
    (is-true (eq lhs rhs))
    (is-equal 1 (length constitutions))
    (is-equal (mini-kernel:runtime-constitution-id lhs)
              (mini-kernel:runtime-constitution-id-for-state))
    (is-equal (length (mini-kernel:list-kernel-core-algorithms))
              (length (mini-kernel:runtime-constitution-kernel-core-algorithms lhs)))
    (is-equal (length (mini-kernel:list-smt-core-algorithms))
              (length (mini-kernel:runtime-constitution-smt-core-algorithms lhs)))
    (is-equal (length (mini-kernel:list-admitted-obligation-classes))
              (length (mini-kernel:runtime-constitution-admitted-obligations lhs)))
    (is-equal 5 (length (mini-kernel:runtime-constitution-manifests lhs)))
    (is-equal :registry-manifest
              (getf (mini-kernel:runtime-constitution-rehydration-state lhs)
                    :rehydration-kind))
    (is-equal :registry-snapshot
              (getf (mini-kernel:runtime-constitution-synchronization-state lhs)
                    :synchronization-kind))
    (is-equal (length mini-kernel:*closure-backlog*)
              (length (mini-kernel:runtime-constitution-closure-backlog lhs)))))

(defun test-runtime-capability-surface ()
  (let* ((constitution (mini-kernel:current-runtime-constitution))
         (capability (first (mini-kernel:runtime-constitution-capability-classes constitution)))
         (rows (mini-kernel:runtime-constitution-callable-rows constitution))
         (names (mapcar #'mini-kernel:runtime-callable-row-name rows)))
    (is-true (typep capability 'mini-kernel:runtime-capability-class))
    (is-equal :formal-runtime (mini-kernel:runtime-capability-class-id capability))
    (is-equal :formal (mini-kernel:runtime-capability-class-lane capability))
    (is-equal :constitutional
              (mini-kernel:runtime-capability-class-authority-kind capability))
    (is-true (member "constitution/runtime-constitution-witness-object"
                     names :test #'string=))
    (is-true (member "kernel/check" names :test #'string=))
    (is-true (member "smt/run-smt-check" names :test #'string=))
    (is-true (member "lsip/check-lsip-edge-gate" names :test #'string=))
    (is-true (member "cegis/run-cegis-trace" names :test #'string=))
    (is-true (member "cegis/run-compiler-mutation-cegis" names :test #'string=))
    (is-true (member "cegis/list-cegis-search-irs" names :test #'string=))
    (is-true (member "cegis/describe-cegis-search-ir" names :test #'string=))
    (is-true (member "compiler/list-families" names :test #'string=))
    (is-true (member "compiler/describe-family" names :test #'string=))
    (is-true (member "compiler/list-obligation-kinds" names :test #'string=))
    (is-true (member "compiler/check-schema" names :test #'string=))
    (is-true (member "compiler/check-control-determinism" names :test #'string=))
    (is-true (member "compiler/check-lowering-totality" names :test #'string=))
    (is-true (member "compiler/check-installed-generation" names :test #'string=))
    (is-true (member "compiler/check-layout" names :test #'string=))
    (is-true (member "compiler/check-roundtrip" names :test #'string=))
    (is-true (member "compiler/check-image-closure" names :test #'string=))
    (is-true (member "compiler/check-trace-parity" names :test #'string=))
    (is-true (member "search/list-evidence-statuses" names :test #'string=))
    (is-true (member "search/list-legality-clauses" names :test #'string=))
    (is-true (member "search/list-operator-classes" names :test #'string=))
    (is-true (member "search/build-operator-instance" names :test #'string=))
    (is-true (member "search/list-formal-obligation-kinds" names :test #'string=))
    (is-true (member "search/build-formal-obligation" names :test #'string=))
    (is-true (member "search/project-formal-obligation" names :test #'string=))
    (is-true (member "search/evaluate-bridge-totality" names :test #'string=))
    (is-true (member "search/build-formal-evidence" names :test #'string=))
    (is-true (member "search/apply-evidence-update" names :test #'string=))
    (is-true (member "search/evaluate-evidence-monotonicity" names :test #'string=))
    (is-true (member "search/evaluate-evidence-frontier" names :test #'string=))
    (is-true (member "search/evaluate-supersession-consistency" names :test #'string=))
    (is-true (member "search/evaluate-legal-transition" names :test #'string=))
    (is-true (member "search/evaluate-admission-law" names :test #'string=))
    (is-true (member "bridge/o-affine-int-contradiction" names :test #'string=))
    (is-true (member "audit/smt-bridge-affine-int-contradiction" names :test #'string=))
    (is-true (> (length rows)
                (+ (length (mini-kernel:list-kernel-core-algorithms))
                   (length (mini-kernel:list-smt-core-algorithms))
                   (length (mini-kernel:list-admitted-obligation-classes))
                   (length (mini-kernel:list-theorem-bridge-bindings)))))))

(defun test-runtime-constitution-json-object ()
  (let* ((constitution (mini-kernel:current-runtime-constitution))
         (object (mini-kernel:runtime-constitution-json-object constitution))
         (manifests (mini-kernel:json-object-get object "manifests"))
         (capabilities (mini-kernel:json-object-get object "capability_classes"))
         (callable-rows (mini-kernel:json-object-get object "callable_rows")))
    (is-equal (mini-kernel:runtime-constitution-id constitution)
              (mini-kernel:json-object-get object "id"))
    (is-equal (mini-kernel:runtime-constitution-registry-digest constitution)
              (mini-kernel:json-object-get object "registry_digest"))
    (is-equal (mini-kernel:runtime-constitution-authority-state constitution)
              (mini-kernel:json-object-get object "authority_state"))
    (is-equal (mini-kernel:runtime-constitution-live-state constitution)
              (mini-kernel:json-object-get object "live_state"))
    (is-equal 5 (length manifests))
    (is-equal 1 (length capabilities))
    (is-equal (length (mini-kernel:runtime-constitution-callable-rows constitution))
              (length callable-rows))
    (is-equal (length mini-kernel:*closure-backlog*)
              (length (mini-kernel:json-object-get object "closure_backlog_ids")))
    (is-true
     (member "kernel/check"
             (mapcar (lambda (row)
                       (mini-kernel:json-object-get row "name"))
                     callable-rows)
             :test #'string=))))

(defun test-runtime-constitution-witness-object ()
  (let* ((constitution (mini-kernel:current-runtime-constitution))
         (witness (mini-kernel:runtime-constitution-witness-object constitution))
         (omega-shape (mini-kernel:json-object-get witness "omega_shape"))
         (omega-addr (mini-kernel:json-object-get witness "omega_addr"))
         (omega-trans (mini-kernel:json-object-get witness "omega_trans")))
    (is-equal (mini-kernel:runtime-constitution-id constitution)
              (mini-kernel:json-object-get witness "constitution_id"))
    (is-equal (mini-kernel:runtime-constitution-registry-digest constitution)
              (mini-kernel:json-object-get witness "registry_digest"))
    (is-equal 5 (length omega-shape))
    (is-equal (length (mini-kernel:runtime-constitution-callable-rows constitution))
              (length omega-addr))
    (is-equal (mini-kernel:runtime-constitution-rehydration-state constitution)
              (mini-kernel:json-object-get omega-trans "rehydration_state"))))

(defun test-formal-capability-class ()
  (let* ((capability (mini-kernel:current-formal-capability-class))
         (constraint-ids (mapcar #'mini-kernel:formal-constraint-class-id
                                 (mini-kernel:formal-capability-class-constraint-classes
                                  capability)))
         (operation-ids (mapcar #'mini-kernel:formal-capability-operation-id
                                (mini-kernel:formal-capability-class-operations
                                 capability)))
         (callable-names (mapcar #'mini-kernel:runtime-callable-row-name
                                 (mini-kernel:formal-capability-class-callable-rows
                                  capability)))
         (policy (mini-kernel:formal-capability-class-admission-policy capability)))
    (is-equal :formal (mini-kernel:formal-capability-class-id capability))
    (is-true (member :kernel-judgment-check constraint-ids))
    (is-true (member :kernel-lane-parity constraint-ids))
    (is-true (member :smt-admitted-bridge constraint-ids))
    (is-true (member :compiler-mutation-cegis constraint-ids))
    (is-true (member :structural-lsip-law constraint-ids))
    (is-true (member :closure-profile-check constraint-ids))
    (is-true (member :compiler-family-schema constraint-ids))
    (is-true (member :compiler-control-determinism constraint-ids))
    (is-true (member :compiler-lowering-totality constraint-ids))
    (is-true (member :compiler-installed-generation-soundness constraint-ids))
    (is-true (member :compiler-layout-monotonicity constraint-ids))
    (is-true (member :compiler-encode-decode-roundtrip constraint-ids))
    (is-true (member :compiler-image-closure constraint-ids))
    (is-true (member :compiler-bounded-trace-parity constraint-ids))
    (is-true (member :search-obligation-formation constraint-ids))
    (is-true (member :search-obligation-projection constraint-ids))
    (is-true (member :search-bridge-totality constraint-ids))
    (is-true (member :search-evidence-closure constraint-ids))
    (is-true (member :search-evidence-monotonicity constraint-ids))
    (is-true (member :search-evidence-frontier constraint-ids))
    (is-true (member :search-supersession-consistency constraint-ids))
    (is-true (member :search-legal-transition constraint-ids))
    (is-true (member :search-admission-evaluation constraint-ids))
    (is-true (member :check-kernel-spec-kr operation-ids))
    (is-true (member :j-smt-admitted-obligation-bridge operation-ids))
    (is-true (member :check-lsip-edge-gate operation-ids))
    (is-true (member :run-cegis-trace operation-ids))
    (is-true (member :run-compiler-mutation-cegis operation-ids))
    (is-true (member :check-compiler-schema operation-ids))
    (is-true (member :check-compiler-control-determinism operation-ids))
    (is-true (member :check-compiler-lowering-totality operation-ids))
    (is-true (member :check-compiler-installed-generation operation-ids))
    (is-true (member :check-compiler-layout operation-ids))
    (is-true (member :check-compiler-roundtrip operation-ids))
    (is-true (member :check-compiler-image-closure operation-ids))
    (is-true (member :check-compiler-trace-parity operation-ids))
    (is-true (member "capability/current-formal-capability-class"
                     callable-names :test #'string=))
    (is-true (member :bridge-status
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :lsip-law-result
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :compiler-check-result
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :cegis-trace
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :search-bridge-totality
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :search-evidence-monotonicity
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :search-evidence-frontier
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :search-supersession-consistency
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :search-legal-transition
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-true (member :search-admission-result
                     (mini-kernel:formal-capability-class-evidence-kinds capability)))
    (is-equal :formal-capability-admission
              (mini-kernel:formal-admission-policy-id policy))
    (is-true (member :kernel-check
                     (mini-kernel:formal-admission-policy-allowed-invocations policy)))
    (is-true (member :lsip-structural-check
                     (mini-kernel:formal-admission-policy-allowed-invocations policy)))
    (is-true (member :cegis-trace
                     (mini-kernel:formal-admission-policy-allowed-invocations policy)))
    (is-true (member :kernel-core-semantics
                     (mini-kernel:formal-admission-policy-forbidden-mutations policy)))))

(defun test-formal-capability-report ()
  (let* ((capability (mini-kernel:current-formal-capability-class))
         (report (mini-kernel:evaluate-formal-capability-report capability)))
    (is-equal :formal (mini-kernel:formal-capability-report-capability-id report))
    (is-equal (length (mini-kernel:formal-capability-class-callable-rows capability))
              (mini-kernel:formal-capability-report-callable-count report))
    (is-equal (length (mini-kernel:formal-capability-class-operations capability))
              (mini-kernel:formal-capability-report-operation-count report))
    (is-equal (length (mini-kernel:formal-capability-class-constraint-classes capability))
              (mini-kernel:formal-capability-report-constraint-count report))
    (is-equal :formal-capability-admission
              (mini-kernel:formal-capability-report-admission-policy-id report))
    (is-true (member :closure
                     (mini-kernel:formal-capability-report-trusted-boundaries report)))))

(defun test-formal-capability-consistency ()
  (is-true (mini-kernel:check-formal-capability-consistency)))

(defun test-invoke-formal-capability-kernel ()
  (let* ((spec (mini-kernel:make-frozen-kernel-core-spec))
         (result (mini-kernel:invoke-formal-capability
                  :check-kernel-spec-kr
                  :spec spec)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :kernel-status
              (mini-kernel:formal-capability-result-evidence-kind result))
    (is-true (listp (mini-kernel:formal-capability-result-payload result)))
    (is-true (plusp (length (mini-kernel:formal-capability-result-payload result))))))

(defun test-invoke-formal-capability-bridge ()
  (let ((result
          (mini-kernel:invoke-formal-capability
           :j-smt-admitted-obligation-bridge
           :obligation-id :o-closed-boolean-unsat
           :formula '(:and (:bool t) (:not (:bool t))))))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :bridge-status
              (mini-kernel:formal-capability-result-evidence-kind result))
    (is-true (mini-kernel:formal-capability-result-payload result))))

(defun test-invoke-formal-capability-lsip-edge-gate ()
  (let* ((runtime-program
           (mini-kernel:compile-lsip-stratum-object
            :x2
            '(:runtime-program :linkset-id "link-1")))
         (runtime-state
           (mini-kernel:compile-lsip-stratum-object
            :r0
            '(:runtime-state :machine-id "machine-a")))
         (authority-artifact
           (mini-kernel:compile-lsip-stratum-object
            :a0
            '(:authority-bundle :linkset-id "link-1")))
         (relation
           (mini-kernel:compile-lsip-relation
            :x2-r0-to-a0
            :source-objects (list runtime-program runtime-state)
            :target-objects (list authority-artifact)
            :facts (list :resident-machine-id "machine-a"
                         :foreign-machine-id "machine-b"
                         :separated-p t
                         :pre-runtime-digest "runtime-1"
                         :post-runtime-digest "runtime-1"
                         :inert-p t
                         :runtime-linkset-id "link-1"
                         :authority-linkset-id "link-1"
                         :admission-before-sync-p t
                         :registration-before-dispatch-p t
                         :no-partial-callable-visibility-p t)))
         (result
           (mini-kernel:invoke-formal-capability
            :check-lsip-edge-gate
            :caller-class :compiler
            :edge-id :x2-r0-to-a0
            :relation relation)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :lsip-law-result
              (mini-kernel:formal-capability-result-evidence-kind result))
    (is-equal :accepted
              (mini-kernel:lsip-edge-gate-result-status
               (mini-kernel:formal-capability-result-payload result)))))

(defun test-plan-formal-capability-invocation ()
  (let ((plan (mini-kernel:plan-formal-capability-invocation
               :check-kernel-spec-kr
               :caller-class :synth
               :args (list :spec (mini-kernel:make-frozen-kernel-core-spec)))))
    (is-true (typep plan 'mini-kernel:formal-capability-plan))
    (is-equal t (mini-kernel:formal-capability-plan-admissible-p plan))
    (is-equal :admitted (mini-kernel:formal-capability-plan-reason plan))))

(defun test-formal-capability-constraint-routing ()
  (let ((operations
          (mini-kernel:formal-capability-operations-for-constraint-class
           :kernel-lane-parity)))
    (is-true (plusp (length operations)))
    (is-true
     (member :compare-kernel-spec-kr-kl-defir
             (mapcar #'mini-kernel:formal-capability-operation-id operations)))))

(defun test-invoke-formal-constraint-class ()
  (let ((result
          (mini-kernel:invoke-formal-constraint-class
           :smt-admitted-bridge
           :caller-class :synth
           :obligation-id :o-closed-boolean-unsat
           :formula '(:and (:bool t) (:not (:bool t))))))
    (is-equal :accepted (mini-kernel:formal-capability-result-status result))
    (is-equal :bridge-status
              (mini-kernel:formal-capability-result-evidence-kind result))))

(defun test-reject-formal-capability-caller-class ()
  (let ((result
          (mini-kernel:invoke-formal-capability
           :check-kernel-spec-kr
           :caller-class :frontend
           :spec (mini-kernel:make-frozen-kernel-core-spec))))
    (is-equal :rejected (mini-kernel:formal-capability-result-status result))
    (is-equal :caller-class-not-admitted
              (mini-kernel:formal-capability-result-rejection-reason result))))

(defun test-reject-formal-capability-schema-mismatch ()
  (let ((result
          (mini-kernel:invoke-formal-capability
           :check-kernel-spec-kr
           :caller-class :synth)))
    (is-equal :rejected (mini-kernel:formal-capability-result-status result))
    (is-equal :missing-required-arguments
              (mini-kernel:formal-capability-result-rejection-reason result))))

(defun test-reject-formal-capability-unknown-argument ()
  (let ((result
          (mini-kernel:invoke-formal-capability
           :check-kernel-spec-kr
           :caller-class :synth
           :spec (mini-kernel:make-frozen-kernel-core-spec)
           :query '(:bool t))))
    (is-equal :rejected (mini-kernel:formal-capability-result-status result))
    (is-equal :unknown-argument-key
              (mini-kernel:formal-capability-result-rejection-reason result))))

(defun test-reject-formal-capability-mutation ()
  (let ((result
          (mini-kernel:invoke-formal-capability
           :check-kernel-spec-kr
           :mutation-kind :kernel-core-semantics
           :spec (mini-kernel:make-frozen-kernel-core-spec))))
    (is-equal :rejected (mini-kernel:formal-capability-result-status result))
    (is-equal :forbidden-mutation
              (mini-kernel:formal-capability-result-rejection-reason result))))

(defun test-formal-capability-manifest ()
  (let* ((manifest (mini-kernel:formal-capability-manifest-object))
         (operations (mini-kernel:json-object-get manifest "operations"))
         (spaces (mini-kernel:json-object-get manifest "cegis_spaces"))
         (search-irs (mini-kernel:json-object-get manifest "cegis_search_irs"))
         (compiler-families (mini-kernel:json-object-get manifest "compiler_families"))
         (compiler-obligations (mini-kernel:json-object-get manifest "compiler_obligation_kinds"))
         (evidence-statuses (mini-kernel:json-object-get manifest "search_evidence_statuses"))
         (frontier-ops (mini-kernel:json-object-get manifest "search_evidence_frontier_ops"))
         (legality-clauses (mini-kernel:json-object-get manifest "search_legality_clauses"))
         (operator-classes (mini-kernel:json-object-get manifest "search_operator_classes"))
         (search-obligations (mini-kernel:json-object-get manifest "search_obligation_kinds"))
         (admission-laws (mini-kernel:json-object-get manifest "search_admission_laws"))
         (kernel-op
           (find "check-kernel-spec-kr"
                 operations
                 :key (lambda (entry)
                        (mini-kernel:json-object-get entry "id"))
                 :test #'string=)))
    (is-equal "formal"
              (mini-kernel:json-object-get manifest "id"))
    (is-true (plusp (length operations)))
    (is-true
     (member "check-kernel-spec-kr"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     operations)
             :test #'string=))
    (is-true kernel-op)
    (is-equal 3 (length spaces))
    (is-equal 3 (length search-irs))
    (is-equal 1 (length compiler-families))
    (is-equal 8 (length compiler-obligations))
    (is-equal 5 (length evidence-statuses))
    (is-equal 2 (length frontier-ops))
    (is-equal 5 (length legality-clauses))
    (is-equal 2 (length operator-classes))
    (is-equal 3 (length search-obligations))
    (is-equal 1 (length admission-laws))
    (is-true
     (member :compiler-mutation
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "family"))
                     spaces)))
    (is-true
     (member :compiler-mutation
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "family"))
                     search-irs)))
    (is-true
     (member "stage1-mir-compiler"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     compiler-families)
             :test #'string=))
    (is-true
     (member "compiler-control-determinism"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     compiler-obligations)
             :test #'string=))
    (is-true
     (member "compiler-installed-generation-soundness"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     compiler-obligations)
             :test #'string=))
    (is-true
     (member "compiler-image-closure"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     compiler-obligations)
             :test #'string=))
    (is-true
     (member "compiler-bounded-trace-parity"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     compiler-obligations)
             :test #'string=))
    (is-true
     (member "fresh-pass"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     evidence-statuses)
             :test #'string=))
    (is-true
     (member "search/evaluate-evidence-frontier" frontier-ops :test #'string=))
    (is-true
     (member "bridge-totality"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     legality-clauses)
             :test #'string=))
    (is-true
     (member "compiler-mutation"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     operator-classes)
             :test #'string=))
    (is-true
     (member "spec"
             (mini-kernel:json-object-get kernel-op "argument_keys")
             :test #'string=))))

(defun test-invoke-formal-capability-compiler-family-slice ()
  (let* ((families-result
           (mini-kernel:invoke-formal-capability
            :list-compiler-families
            :caller-class :synth))
         (describe-result
           (mini-kernel:invoke-formal-capability
            :describe-compiler-family
            :caller-class :synth
            :family :stage1-mir-compiler))
         (obligations-result
           (mini-kernel:invoke-formal-capability
            :list-compiler-obligation-kinds
            :caller-class :synth))
         (schema-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-schema
            :caller-class :synth
            :family :stage1-mir-compiler))
         (determinism-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-control-determinism
            :caller-class :synth
            :family :stage1-mir-compiler))
         (totality-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-lowering-totality
            :caller-class :synth
            :family :stage1-mir-compiler))
         (installed-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-installed-generation
            :caller-class :synth
            :family :stage1-mir-compiler))
         (layout-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-layout
            :caller-class :synth
            :family :stage1-mir-compiler))
         (roundtrip-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-roundtrip
            :caller-class :synth
            :family :stage1-mir-compiler))
         (image-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-image-closure
            :caller-class :synth
            :family :stage1-mir-compiler))
         (trace-result
           (mini-kernel:invoke-formal-capability
            :check-compiler-trace-parity
            :caller-class :synth
            :family :stage1-mir-compiler
            :limit 3))
         (roundtrip-payload (mini-kernel:formal-capability-result-payload roundtrip-result))
         (mismatches (getf (mini-kernel:compiler-check-result-diagnostics roundtrip-payload)
                           :mismatches)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status families-result))
    (is-equal :audit-result
              (mini-kernel:formal-capability-result-evidence-kind families-result))
    (is-true
     (member "stage1-mir-compiler"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     (mini-kernel:formal-capability-result-payload families-result))
             :test #'string=))
    (is-equal :accepted (mini-kernel:formal-capability-result-status describe-result))
    (is-equal "stage1-mir-compiler"
              (mini-kernel:json-object-get
               (mini-kernel:formal-capability-result-payload describe-result)
               "id"))
    (is-equal :accepted (mini-kernel:formal-capability-result-status obligations-result))
    (is-true
     (member "compiler-layout-monotonicity"
             (mapcar (lambda (entry)
                       (mini-kernel:json-object-get entry "id"))
                     (mini-kernel:formal-capability-result-payload obligations-result))
             :test #'string=))
    (dolist (result (list schema-result
                          determinism-result
                          totality-result
                          installed-result
                          layout-result
                          roundtrip-result
                          image-result
                          trace-result))
      (is-equal :accepted (mini-kernel:formal-capability-result-status result))
      (is-equal :compiler-check-result
                (mini-kernel:formal-capability-result-evidence-kind result)))
    (is-equal :passed
              (mini-kernel:compiler-check-result-status
               (mini-kernel:formal-capability-result-payload schema-result)))
    (is-equal :passed
              (mini-kernel:compiler-check-result-status
               (mini-kernel:formal-capability-result-payload determinism-result)))
    (is-equal :passed
              (mini-kernel:compiler-check-result-status
               (mini-kernel:formal-capability-result-payload totality-result)))
    (is-equal :passed
              (mini-kernel:compiler-check-result-status
               (mini-kernel:formal-capability-result-payload installed-result)))
    (is-equal :passed
              (mini-kernel:compiler-check-result-status
               (mini-kernel:formal-capability-result-payload layout-result)))
    (is-equal :passed
              (mini-kernel:compiler-check-result-status
               (mini-kernel:formal-capability-result-payload image-result)))
    (is-equal :passed
              (mini-kernel:compiler-check-result-status
               (mini-kernel:formal-capability-result-payload trace-result)))
    (is-true
     (member (mini-kernel:compiler-check-result-status roundtrip-payload)
             '(:passed :failed)
             :test #'eq))
    (is-equal (if mismatches :failed :passed)
              (mini-kernel:compiler-check-result-status roundtrip-payload))))

(defun test-invoke-formal-capability-search-kernel-slice ()
  (let* ((instance-result
           (mini-kernel:invoke-formal-capability
            :build-search-operator-instance
            :caller-class :synth
            :operator-class :compiler-mutation
            :target-zone :x1-to-x2
            :source-operation :run-compiler-mutation-cegis
            :replay-token :trace-1))
         (instance (mini-kernel:formal-capability-result-payload instance-result))
         (obligation-result
           (mini-kernel:invoke-formal-capability
            :build-search-formal-obligation
            :caller-class :synth
            :kind :bridge-totality
            :scope '(:zone :x1-to-x2)
            :projection-seed '(:family :compiler-mutation)
            :source-operation :run-compiler-mutation-cegis))
         (obligation (mini-kernel:formal-capability-result-payload obligation-result))
         (projection-result
           (mini-kernel:invoke-formal-capability
           :project-search-formal-obligation
           :caller-class :synth
           :obligation obligation))
         (bridge-totality-result
           (mini-kernel:invoke-formal-capability
            :evaluate-search-bridge-totality
            :caller-class :synth
            :obligation obligation))
         (evidence-result
           (mini-kernel:invoke-formal-capability
            :build-search-formal-evidence
            :caller-class :synth
            :obligation obligation
            :judgment :pass
            :certificate '(:trace "ok")
            :freshness-status :fresh))
         (evidence (mini-kernel:formal-capability-result-payload evidence-result))
         (update-result
           (mini-kernel:invoke-formal-capability
            :apply-search-evidence-update
            :caller-class :synth
            :state-id :candidate-1
            :evidence (list evidence)))
         (update (mini-kernel:formal-capability-result-payload update-result))
         (monotonicity-result
           (mini-kernel:invoke-formal-capability
            :evaluate-search-evidence-monotonicity
            :caller-class :synth
            :current update))
         (frontier-result
           (mini-kernel:invoke-formal-capability
            :evaluate-search-evidence-frontier
            :caller-class :synth
            :state update))
         (supersession-result
           (mini-kernel:invoke-formal-capability
            :evaluate-search-supersession-consistency
            :caller-class :synth
            :state update))
         (legal-transition-result
           (mini-kernel:invoke-formal-capability
            :evaluate-search-legal-transition
            :caller-class :synth
            :operator-instance instance
            :state-id :candidate-1))
         (admission-result
           (mini-kernel:invoke-formal-capability
            :evaluate-search-admission-law
            :caller-class :synth
            :law :baseline-search-admission
            :state-id :candidate-1
            :evidence-update update
            :touched-obligation-kinds '(:bridge-totality))))
    (is-equal :accepted (mini-kernel:formal-capability-result-status instance-result))
    (is-equal :search-operator-instance
              (mini-kernel:formal-capability-result-evidence-kind instance-result))
    (is-equal :accepted (mini-kernel:formal-capability-result-status obligation-result))
    (is-equal :search-obligation
              (mini-kernel:formal-capability-result-evidence-kind obligation-result))
    (is-equal :accepted (mini-kernel:formal-capability-result-status projection-result))
    (is-equal :search-projection
              (mini-kernel:formal-capability-result-evidence-kind projection-result))
    (is-equal :total
              (mini-kernel:search-obligation-projection-totality-class
               (mini-kernel:formal-capability-result-payload projection-result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status bridge-totality-result))
    (is-equal :search-bridge-totality
              (mini-kernel:formal-capability-result-evidence-kind bridge-totality-result))
    (is-equal :total
              (mini-kernel:search-bridge-totality-result-status
               (mini-kernel:formal-capability-result-payload bridge-totality-result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status evidence-result))
    (is-equal :search-formal-evidence
              (mini-kernel:formal-capability-result-evidence-kind evidence-result))
    (is-equal :fresh-pass
              (mini-kernel:search-formal-evidence-status evidence))
    (is-equal :accepted (mini-kernel:formal-capability-result-status update-result))
    (is-equal :search-evidence-update
              (mini-kernel:formal-capability-result-evidence-kind update-result))
    (is-equal 0 (mini-kernel:search-evidence-update-hard-debt update))
    (is-equal :fresh-pass
              (mini-kernel:search-evidence-update-status update))
    (is-equal :accepted (mini-kernel:formal-capability-result-status monotonicity-result))
    (is-equal :search-evidence-monotonicity
              (mini-kernel:formal-capability-result-evidence-kind monotonicity-result))
    (is-equal :monotone
              (mini-kernel:search-evidence-monotonicity-result-status
               (mini-kernel:formal-capability-result-payload monotonicity-result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status frontier-result))
    (is-equal :search-evidence-frontier
              (mini-kernel:formal-capability-result-evidence-kind frontier-result))
    (is-equal 1
              (length
               (mini-kernel:search-evidence-frontier-live-frontier
                (mini-kernel:formal-capability-result-payload frontier-result))))
    (is-equal :accepted (mini-kernel:formal-capability-result-status supersession-result))
    (is-equal :search-supersession-consistency
              (mini-kernel:formal-capability-result-evidence-kind supersession-result))
    (is-equal :consistent
              (mini-kernel:search-supersession-consistency-result-status
               (mini-kernel:formal-capability-result-payload supersession-result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status legal-transition-result))
    (is-equal :search-legal-transition
              (mini-kernel:formal-capability-result-evidence-kind legal-transition-result))
    (is-equal :legal
              (mini-kernel:search-legal-transition-status
               (mini-kernel:formal-capability-result-payload legal-transition-result)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status admission-result))
    (is-equal :search-admission-result
              (mini-kernel:formal-capability-result-evidence-kind admission-result))
    (is-equal :admit
              (mini-kernel:search-admission-result-status
               (mini-kernel:formal-capability-result-payload admission-result)))))

(defun test-invoke-formal-capability-illegal-transition ()
  (let* ((instance-result
           (mini-kernel:invoke-formal-capability
            :build-search-operator-instance
            :caller-class :synth
            :operator-class :compiler-mutation
            :target-zone :x1-to-x2
            :source-operation :run-compiler-mutation-cegis))
         (instance (mini-kernel:formal-capability-result-payload instance-result))
         (legal-transition-result
           (mini-kernel:invoke-formal-capability
            :evaluate-search-legal-transition
            :caller-class :synth
            :operator-instance instance
            :state-id :candidate-2
            :replay-ok-p nil)))
    (is-equal :accepted (mini-kernel:formal-capability-result-status legal-transition-result))
    (is-equal :illegal
              (mini-kernel:search-legal-transition-status
               (mini-kernel:formal-capability-result-payload legal-transition-result)))
    (is-true
     (member :replay-defined
             (mini-kernel:search-legal-transition-failing-clauses
              (mini-kernel:formal-capability-result-payload legal-transition-result))))))

(defun test-search-admission-status-lattice ()
  (let* ((open-update
           (mini-kernel:apply-search-evidence-update
            :candidate-open
            '()
            0
            0
            nil))
         (open-admission
           (mini-kernel:evaluate-search-admission-law
            :baseline-search-admission
            :candidate-open
            open-update
            '(:bridge-totality)))
         (stale-obligation
           (mini-kernel:build-search-formal-obligation
            :bridge-totality
            '(:zone :stale)
            '(:family :compiler-mutation)
            :run-compiler-mutation-cegis))
         (stale-evidence
           (mini-kernel:build-search-formal-evidence
            stale-obligation
            :pass
            '(:trace "stale")
            :stale))
         (stale-update
           (mini-kernel:apply-search-evidence-update
            :candidate-stale
            (list stale-evidence)))
         (stale-admission
           (mini-kernel:evaluate-search-admission-law
            :baseline-search-admission
            :candidate-stale
            stale-update
            '(:bridge-totality)))
         (fail-obligation
           (mini-kernel:build-search-formal-obligation
            :bridge-totality
            '(:zone :fail)
            '(:family :compiler-mutation)
            :run-compiler-mutation-cegis))
         (fail-evidence
           (mini-kernel:build-search-formal-evidence
            fail-obligation
            :fail
            '(:trace "fail")
            :fresh))
         (fail-update
           (mini-kernel:apply-search-evidence-update
            :candidate-fail
            (list fail-evidence)))
         (fail-admission
           (mini-kernel:evaluate-search-admission-law
            :baseline-search-admission
            :candidate-fail
            fail-update
            '(:bridge-totality)))
         (adv-obligation
           (mini-kernel:build-search-formal-obligation
            :evidence-monotonicity
            '(:zone :adv)
            '(:family :compiler-mutation)
            :run-compiler-mutation-cegis))
         (adv-evidence
           (mini-kernel:build-search-formal-evidence
            adv-obligation
            :advisory-fail
            '(:trace "adv")
            :fresh))
         (adv-update
           (mini-kernel:apply-search-evidence-update
            :candidate-adv
            (list adv-evidence)))
         (adv-admission
           (mini-kernel:evaluate-search-admission-law
            :baseline-search-admission
            :candidate-adv
            adv-update
            '(:evidence-monotonicity))))
    (is-equal :open (mini-kernel:search-evidence-update-status open-update))
    (is-equal :quarantine (mini-kernel:search-admission-result-status open-admission))
    (is-equal :stale (mini-kernel:search-evidence-update-status stale-update))
    (is-equal :quarantine (mini-kernel:search-admission-result-status stale-admission))
    (is-equal :fresh-fail (mini-kernel:search-evidence-update-status fail-update))
    (is-equal :reject (mini-kernel:search-admission-result-status fail-admission))
    (is-equal :fresh-fail (mini-kernel:search-evidence-update-status adv-update))
    (is-equal :quarantine (mini-kernel:search-admission-result-status adv-admission))))

(defun test-search-evidence-monotonicity-audit ()
  (let* ((obligation
           (mini-kernel:build-search-formal-obligation
            :bridge-totality
            '(:zone :mono)
            '(:family :compiler-mutation)
            :run-compiler-mutation-cegis))
         (evidence-a
           (mini-kernel:build-search-formal-evidence
            obligation
            :pass
            '(:trace "a")
            :fresh))
         (update-a
           (mini-kernel:apply-search-evidence-update
            :candidate-mono
            (list evidence-a)))
         (state-a (mini-kernel:build-search-evidence-state-from-update update-a))
         (evidence-b
           (mini-kernel:build-search-formal-evidence
            obligation
            :pass
            '(:trace "b")
            :fresh))
         (update-b
           (mini-kernel:apply-search-evidence-update
            :candidate-mono
            (list evidence-b)
            0
            0
            state-a))
         (monotone
           (mini-kernel:evaluate-search-evidence-monotonicity update-b update-a))
         (bad-state
           (mini-kernel:make-search-evidence-state
            :state-id :candidate-mono
            :obligation-statuses (mini-kernel:search-evidence-update-obligation-statuses update-a)
            :live-evidence-ids '()
            :supersession-links '()
            :hard-debt 0
            :advisory-debt 0
            :coverage-summary (mini-kernel:search-evidence-update-coverage-summary update-a)
            :freshness-summary (mini-kernel:search-evidence-update-freshness-summary update-a)
            :status :fresh-pass
            :metadata '()))
         (violated
           (mini-kernel:evaluate-search-evidence-monotonicity bad-state update-a)))
    (is-equal :monotone
              (mini-kernel:search-evidence-monotonicity-result-status monotone))
    (is-equal 1
              (length
               (mini-kernel:search-evidence-monotonicity-result-appended-evidence-ids
                monotone)))
    (is-equal :violated
              (mini-kernel:search-evidence-monotonicity-result-status violated))))

(defun test-search-evidence-update-preserves-untouched-live-evidence ()
  (let* ((bridge-obligation
           (mini-kernel:build-search-formal-obligation
            :bridge-totality
            '(:zone :mono)
            '(:family :compiler-mutation)
            :run-compiler-mutation-cegis))
         (kernel-obligation
           (mini-kernel:build-search-formal-obligation
            :replay-defined
            '(:zone :mono)
            '(:family :compiler-mutation)
            :run-compiler-mutation-cegis))
         (bridge-a
           (mini-kernel:build-search-formal-evidence
            bridge-obligation
            :pass
            '(:trace "bridge-a")
            :fresh))
         (kernel-a
           (mini-kernel:build-search-formal-evidence
            kernel-obligation
            :pass
            '(:trace "kernel-a")
            :fresh))
         (update-a
           (mini-kernel:apply-search-evidence-update
            :candidate-preserve
            (list bridge-a kernel-a)))
         (state-a (mini-kernel:build-search-evidence-state-from-update update-a))
         (bridge-b
           (mini-kernel:build-search-formal-evidence
            bridge-obligation
            :pass
            '(:trace "bridge-b")
            :fresh))
         (update-b
           (mini-kernel:apply-search-evidence-update
            :candidate-preserve
            (list bridge-b)
            0
            0
            state-a))
         (live-ids (mini-kernel:search-evidence-update-live-evidence-ids update-b))
         (links (mini-kernel:search-evidence-update-supersession-links update-b)))
    (is-equal 2 (length live-ids))
    (is-true (member (mini-kernel:search-formal-evidence-id kernel-a) live-ids
                     :test #'equal))
    (is-true (not (member (mini-kernel:search-formal-evidence-id bridge-a) live-ids
                          :test #'equal)))
    (is-true (find (mini-kernel:search-formal-evidence-id bridge-a)
                   links
                   :key (lambda (entry) (getf entry :prior-evidence-id))
                   :test #'equal))
    (is-equal :fresh-pass
              (mini-kernel:search-evidence-update-status update-b))))

(defun test-search-supersession-consistency-audit ()
  (let* ((obligation
           (mini-kernel:build-search-formal-obligation
            :bridge-totality
            '(:zone :mono)
            '(:family :compiler-mutation)
            :run-compiler-mutation-cegis))
         (evidence-a
           (mini-kernel:build-search-formal-evidence
            obligation
            :pass
            '(:trace "a")
            :fresh))
         (update-a
           (mini-kernel:apply-search-evidence-update
            :candidate-supersession
            (list evidence-a)))
         (state-a (mini-kernel:build-search-evidence-state-from-update update-a))
         (evidence-b
           (mini-kernel:build-search-formal-evidence
            obligation
            :pass
            '(:trace "b")
            :fresh))
         (update-b
           (mini-kernel:apply-search-evidence-update
            :candidate-supersession
            (list evidence-b)
            0
            0
            state-a))
         (consistent
           (mini-kernel:evaluate-search-supersession-consistency update-b))
         (bad-state
           (mini-kernel:make-search-evidence-state
            :state-id :candidate-supersession
            :obligation-statuses (mini-kernel:search-evidence-update-obligation-statuses update-b)
            :live-evidence-ids '()
            :supersession-links (mini-kernel:search-evidence-update-supersession-links update-b)
            :hard-debt 0
            :advisory-debt 0
            :coverage-summary (mini-kernel:search-evidence-update-coverage-summary update-b)
            :freshness-summary (mini-kernel:search-evidence-update-freshness-summary update-b)
            :status :fresh-pass
            :metadata (list :evidence-entry-index
                            (getf (mini-kernel:search-evidence-state-metadata state-a)
                                  :evidence-entry-index))))
         (inconsistent
           (mini-kernel:evaluate-search-supersession-consistency bad-state)))
    (is-equal :consistent
              (mini-kernel:search-supersession-consistency-result-status consistent))
    (is-equal :inconsistent
              (mini-kernel:search-supersession-consistency-result-status inconsistent))
    (is-equal 1
              (length
               (mini-kernel:search-supersession-consistency-result-uncovered-obligation-ids
                inconsistent)))))

(defun test-formal-synthesis-scenario ()
  (let ((summary (mini-kernel:evaluate-formal-synthesis-scenario)))
    (is-equal t (getf summary :kernel-plan))
    (is-equal t (getf summary :bridge-plan))
    (is-equal :accepted (getf summary :kernel-status))
    (is-equal :accepted (getf summary :bridge-status))
    (is-equal :check-kernel-spec-kr (getf summary :kernel-operation))
    (is-equal :j-smt-admitted-obligation-bridge (getf summary :bridge-operation))
    (is-equal t (getf summary :admissiblep))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "runtime-constitution-rehydration" #'test-runtime-constitution-rehydration)
            (cons "runtime-capability-surface" #'test-runtime-capability-surface)
            (cons "runtime-constitution-json-object" #'test-runtime-constitution-json-object)
            (cons "runtime-constitution-witness-object" #'test-runtime-constitution-witness-object)
            (cons "formal-capability-class" #'test-formal-capability-class)
            (cons "formal-capability-report" #'test-formal-capability-report)
            (cons "formal-capability-consistency" #'test-formal-capability-consistency)
            (cons "plan-formal-capability-invocation" #'test-plan-formal-capability-invocation)
            (cons "formal-capability-constraint-routing" #'test-formal-capability-constraint-routing)
            (cons "invoke-formal-constraint-class" #'test-invoke-formal-constraint-class)
            (cons "invoke-formal-capability-kernel" #'test-invoke-formal-capability-kernel)
            (cons "invoke-formal-capability-bridge" #'test-invoke-formal-capability-bridge)
            (cons "invoke-formal-capability-lsip-edge-gate"
                  #'test-invoke-formal-capability-lsip-edge-gate)
            (cons "reject-formal-capability-caller-class" #'test-reject-formal-capability-caller-class)
            (cons "reject-formal-capability-schema-mismatch" #'test-reject-formal-capability-schema-mismatch)
            (cons "reject-formal-capability-unknown-argument" #'test-reject-formal-capability-unknown-argument)
            (cons "reject-formal-capability-mutation" #'test-reject-formal-capability-mutation)
            (cons "formal-capability-manifest" #'test-formal-capability-manifest)
            (cons "invoke-formal-capability-compiler-family-slice"
                  #'test-invoke-formal-capability-compiler-family-slice)
            (cons "invoke-formal-capability-search-kernel-slice"
                  #'test-invoke-formal-capability-search-kernel-slice)
            (cons "invoke-formal-capability-illegal-transition"
                  #'test-invoke-formal-capability-illegal-transition)
            (cons "search-admission-status-lattice"
                  #'test-search-admission-status-lattice)
            (cons "search-evidence-monotonicity-audit"
                  #'test-search-evidence-monotonicity-audit)
            (cons "search-evidence-update-preserves-untouched-live-evidence"
                  #'test-search-evidence-update-preserves-untouched-live-evidence)
            (cons "search-supersession-consistency-audit"
                  #'test-search-supersession-consistency-audit)
            (cons "formal-synthesis-scenario" #'test-formal-synthesis-scenario)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "constitutional runtime test suite failed"))
    t))
