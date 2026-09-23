(in-package :lab.math)

(defun %test-assert (condition control &rest args)
  (unless condition
    (error (apply #'format nil control args))))

(defun run-formal-math-tests ()
  (let* ((x (make-math-expression-v1 :variable :name "x"))
         (y (make-math-expression-v1 :variable :name "y"))
         (left (make-math-expression-v1 :add x y))
         (right (make-math-expression-v1 :add y x))
         (claim (make-math-claim-v1 :id "claim:test" :statement "x+y=y+x" :expression left)))
    (%test-assert (string= (math-expression-key left) (math-expression-key right))
                  "Commutative expression normalization failed")
    (%test-assert (eq :open (math-claim-status claim)) "Claim status mismatch")
    (let ((imported
            (research-proof-object->math-object
             '(("schema" . "ProofObjectV1")
               ("object_id" . "sha256:test")
               ("object_type" . "FormalLemma")
               ("statement_canonical" . "A")
               ("status" . "PROVED")
               ("dependencies")
               ("metadata" . (("logical_id" . "claim:external")))))))
      (%test-assert (eq :trusted-external (math-claim-status imported))
                    "External proved status crossed the Lab authority boundary"))
    (clear-math-formal-projection-laws)
    (let ((native
            (make-math-formal-native-claim-v1
             :id "claim:native"
             :statement "native formal check"
             :formal-operation-id :check-smt-spec
             :formal-args (list :spec :placeholder)
             :target-proposition '(:smt-spec-valid))))
      (register-default-math-formal-projection-laws)
      (let ((native-projection (project-math-claim native :law-id :lab-formal-native)))
        (%test-assert (math-formal-projection-supported-p native-projection)
                      "Native FORMAL claim did not project")
        (%test-assert (eq :check-smt-spec
                          (getf (math-formal-projection-payload native-projection)
                                :operation-id))
                      "Native FORMAL operation was not preserved")))
    (let ((rejected nil))
      (handler-case
          (make-math-formal-native-claim-v1
           :id "claim:forged"
           :statement "forged"
           :formal-operation-id :arbitrary-operation
           :formal-args '())
        (error () (setf rejected t)))
      (%test-assert rejected "Unadmitted FORMAL operation was accepted"))
    (clear-math-formal-projection-laws)
    (register-math-formal-projection-law
     (make-math-formal-projection-law
      :id :test-law
      :source-claim-class 'math-claim
      :supported-domain nil
      :target-backend :lab-formal-capability
      :translator (lambda (source)
                    (declare (ignore source))
                    (list :operation-id :evaluate-search-admission-law :args '()))
      :target-proposition-builder (lambda (source payload)
                                    (declare (ignore source))
                                    (list :formal-proposition payload))
      :trusted-boundary :formal-capability
      :reconstruction-description "test projection"
      :unsupported-behavior :remain-open
      :version 1))
    (let ((projection (project-math-claim claim :law-id :test-law)))
      (%test-assert (math-formal-projection-supported-p projection)
                    "Projection unexpectedly unsupported")
      (%test-assert (eq :lab-formal-capability
                        (math-formal-projection-target-backend projection))
                    "Projection backend mismatch"))
    (let ((unsupported (make-math-claim-v1 :id "claim:unsupported" :statement "open" :domain-ref "other")))
      (clear-math-formal-projection-laws)
      (%test-assert (not (math-formal-projection-supported-p (project-math-claim unsupported)))
                    "Unsupported claim acquired a projection"))
    (let* ((wire-claim
             (make-math-formal-native-claim-v1
              :id "claim:wire"
              :statement "wire claim"
              :formal-operation-id :check-smt-spec
              :formal-args (list :kind :smt-spec :id "spec:wire")
              :target-proposition '(:wire-proposition)))
           (wire-row
             (math-claim->lsip-search-wire-v1
              wire-claim
              :allowed-operator-family-refs '(:rewrite)
              :representation :native)))
      (%test-assert (eq :lab-math-claim-v1 (getf wire-row :schema))
                    "LSIP claim wire schema mismatch")
      (%test-assert (eq :check-smt-spec (getf wire-row :formal-operation-id))
                    "LSIP claim wire lost FORMAL operation")
      (%test-assert (equal '(:rewrite) (getf wire-row :allowed-operator-family-refs))
                    "LSIP claim wire lost operator family"))
    (let* ((problem
             (make-math-proof-problem-v1
              :id "problem:wire"
              :target-claim
              (make-math-claim-v1
               :id "claim:problem"
               :statement "problem target")
              :representation :symbolic
              :allowed-operator-classes '(:expand :rewrite)
              :policy (list :search-authority :lsip)))
           (row (math-proof-problem->lsip-search-wire-v1 problem)))
      (%test-assert (eq :lab-math-proof-problem-v1 (getf row :schema))
                    "LSIP proof-problem wire schema mismatch")
      (%test-assert (equal '(:expand :rewrite)
                           (getf row :allowed-operator-family-refs))
                    "LSIP proof-problem wire lost operator classes"))
    (initialize-default-math-providers)
    (%test-assert (find-math-provider :lean-provider) "Lean provider declaration missing")
    (%test-assert (null (math-provider-executor (find-math-provider :lean-provider)))
                  "Declared provider should remain capability-missing until bound")
    t))
