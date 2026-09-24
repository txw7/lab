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

    (let* ((x (make-math-expression-v1 :variable :name "x"))
           (three (make-math-expression-v1 :constant :value 3))
           (zero (make-math-expression-v1 :constant :value 0))
           (stronger (make-math-expression-v1 :gt x three))
           (weaker (make-math-expression-v1 :gt x zero))
           (subsumption (math-subsumption-v1 stronger weaker))
           (match
             (match-math-theorem-v1
              :theorem-ref "theorem:positive"
              :theorem-conclusion stronger
              :target-ref "claim:positive"
              :target-expression weaker
              :required-hypotheses (list weaker)
              :available-hypotheses (list stronger))))
      (%test-assert (eq :subsumes
                        (math-subsumption-result-v1-status subsumption))
                    "Exact bound subsumption failed")
      (%test-assert (eq :none
                        (math-subsumption-result-v1-proof-effect subsumption))
                    "Subsumption acquired proof authority")
      (%test-assert (eq :matched
                        (math-theorem-match-v1-conclusion-status match))
                    "Theorem conclusion match failed")
      (%test-assert
       (eq :already-discharged
           (getf (first (math-theorem-match-v1-hypothesis-statuses match))
                 :status))
       "Theorem hypothesis subsumption failed")
      (let* ((unknown-required
               (make-math-expression-v1 :application
                                        (make-math-expression-v1 :variable :name "P")
                                        x))
             (unknown-match
               (match-math-theorem-v1
                :theorem-ref "theorem:unknown-hypothesis"
                :theorem-conclusion stronger
                :target-ref "claim:positive"
                :target-expression weaker
                :required-hypotheses (list unknown-required)
                :available-hypotheses (list stronger)))
             (new-subgoal-match
               (match-math-theorem-v1
                :theorem-ref "theorem:new-subgoal"
                :theorem-conclusion stronger
                :target-ref "claim:positive"
                :target-expression weaker
                :required-hypotheses (list weaker)
                :available-hypotheses '())))
        (%test-assert
         (eq :unknown
             (getf
              (first
               (math-theorem-match-v1-hypothesis-statuses
                unknown-match))
              :status))
         "Unsupported hypothesis shape was not classified unknown")
        (%test-assert
         (eq :new-subgoal
             (getf
              (first
               (math-theorem-match-v1-hypothesis-statuses
                new-subgoal-match))
              :status))
         "Missing theorem hypothesis was not emitted as new subgoal")))

    (let* ((relation
             (make-math-asymptotic-relation-v1
              :kind :uniform-big-o
              :lhs "error(T,r)"
              :rhs "main(T,r)"
              :limit-variable "T"
              :limit-direction :infinity
              :parameter-domain "r>0"
              :uniformity-variables '("r")
              :constant-dependencies '("epsilon")))
           (balance
             (make-dominant-balance-v1
              :source-expression-ref "expr:gaussian-tail"
              :candidate-scale "1/(16 log log T)"
              :relation :asymptotic-equivalent
              :assumptions '("T sufficiently large")))
           (experiment
             (complete-math-experiment-v1
              (make-math-experiment-v1
               :class :extremizer-search
               :hypothesis "contact rigidity"
               :expected-result "one-cluster extremizer"
               :configuration '(:samples 64))
              '(:extremizer :two-cluster)
              :counterexample-candidate)))
      (%test-assert (eq :none
                        (math-asymptotic-relation-v1-proof-effect relation))
                    "Asymptotic relation acquired proof authority")
      (%test-assert (eq :candidate (dominant-balance-v1-status balance))
                    "Dominant balance status mismatch")
      (%test-assert (eq :none (math-experiment-v1-proof-effect experiment))
                    "Experiment acquired proof authority"))

    (flet ((no-counterexample-provider (claim context provider)
             (declare (ignore context))
             (make-math-falsification-result-v1
              :claim-ref (math-object-id claim)
              :provider-ref
              (math-falsification-provider-v1-provider-ref provider)
              :status :no-counterexample-found
              :tested-domain '(:small-exact 0 4)))
           (counterexample-provider (claim context provider)
             (declare (ignore context))
             (make-math-falsification-result-v1
              :claim-ref (math-object-id claim)
              :provider-ref
              (math-falsification-provider-v1-provider-ref provider)
              :status :counterexample
              :witness '(:x 2 :failure "two-cluster"))))
      (register-math-falsification-provider-v1
       (make-math-falsification-provider-v1
        :provider-ref :small-exact
        :supported-classes '(:math-claim)
        :executor #'no-counterexample-provider
        :cost-class :cheap))
      (register-math-falsification-provider-v1
       (make-math-falsification-provider-v1
        :provider-ref :synthetic-adversarial
        :supported-classes '(:math-claim)
        :executor #'counterexample-provider
        :cost-class :cheap))
      (multiple-value-bind (result trace)
          (run-math-falsification-pipeline-v1
           (make-math-claim-v1
            :id "claim:false-rigidity"
            :statement "all contact phases form one cluster")
           '(:small-exact :synthetic-adversarial))
        (%test-assert (= 2 (length trace))
                      "Falsification pipeline did not retain provider trace")
        (%test-assert
         (eq :counterexample
             (math-falsification-result-v1-status result))
         "Falsification pipeline missed counterexample")
        (%test-assert (eq :none
                          (math-falsification-result-v1-proof-effect result))
                      "Counterexample pipeline acquired theorem authority")))
    (let* ((repair-a
             (make-repair-condition-candidate-v1
              :feature-kind :phase-concentration
              :condition-row '(:clusters 1)
              :counterexample-exclusion 3
              :positive-example-preservation 3
              :mathematical-simplicity 2
              :theorem-compatibility 2
              :formalizability 2))
           (repair-b
             (make-repair-condition-candidate-v1
              :feature-kind :spectral-gap
              :condition-row '(:gap :positive)
              :counterexample-exclusion 2
              :positive-example-preservation 2
              :mathematical-simplicity 1
              :theorem-compatibility 1
              :formalizability 1))
           (analysis
             (analyze-math-counterexample-v1
              :target-claim-ref "claim:false-rigidity"
              :counterexample-ref "counterexample:two-cluster"
              :positive-example-refs '("example:one-cluster")
              :feature-observations
              '((:feature :phase-concentration :counterexample :two-cluster
                 :positive :one-cluster))
              :repair-candidates (list repair-b repair-a))))
      (%test-assert
       (eq :phase-concentration
           (repair-condition-candidate-v1-feature-kind
            (first (counterexample-analysis-v1-repair-candidates analysis))))
       "Counterexample repair ranking failed")
      (%test-assert (eq :none (counterexample-analysis-v1-proof-effect analysis))
                    "Counterexample analysis acquired proof authority"))
    t))
