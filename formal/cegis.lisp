(in-package :mini-kernel)

(defstruct cegis-problem
  id
  family
  max-iterations
  metadata)

(defstruct (smt-cegis-problem
            (:include cegis-problem)
            (:constructor make-smt-cegis-problem
                (&key id
                      (family :smt-constraint)
                      (logic :qf_bool)
                      (vars '())
                      (base-assumptions '())
                      goal
                      (expected-status :rejected)
                      (initial-constraints '())
                      (max-iterations 8)
                      metadata)))
  logic
  vars
  base-assumptions
  goal
  expected-status
  initial-constraints)

(defstruct (lsip-edge-policy-cegis-problem
            (:include cegis-problem)
            (:constructor make-lsip-edge-policy-cegis-problem
                (&key id
                      (family :lsip-edge-policy)
                      edge-id
                      relation
                      (required-obligation-classes '())
                      (initial-law-ids '())
                      (fallback-policy :reject-on-failure)
                      (evidence-threshold :all-required)
                      (expected-status :accepted)
                      (max-iterations 8)
                      metadata)))
  edge-id
  relation
  required-obligation-classes
  initial-law-ids
  fallback-policy
  evidence-threshold
  expected-status)

(defstruct (compiler-mutation-cegis-problem
            (:include cegis-problem)
            (:constructor make-compiler-mutation-cegis-problem
                (&key id
                      (family :compiler-mutation)
                      (initial-payload '())
                      (counterexamples '())
                      (expected-status :accepted)
                      (max-iterations 8)
                      metadata)))
  initial-payload
  counterexamples
  expected-status)

(defstruct (cegis-candidate
            (:constructor make-cegis-candidate
                (&key id family payload metadata)))
  id
  family
  payload
  metadata)

(defstruct (cegis-counterexample
            (:constructor make-cegis-counterexample
                (&key id
                      problem-id
                      family
                      kind
                      source-operation
                      failing-obligation
                      witness-kind
                      witness
                      replay-payload
                      diagnostics)))
  id
  problem-id
  family
  kind
  source-operation
  failing-obligation
  witness-kind
  witness
  replay-payload
  diagnostics)

(defstruct (cegis-refinement
            (:constructor make-cegis-refinement
                (&key id
                      problem-id
                      kind
                      payload
                      replay-payload
                      summary
                      metadata)))
  id
  problem-id
  kind
  payload
  replay-payload
  summary
  metadata)

(defstruct (cegis-step-result
            (:constructor make-cegis-step-result
                (&key iteration
                      candidate
                      check-result
                      acceptedp
                      counterexample
                      refinement
                      next-candidate
                      status
                      diagnostics)))
  iteration
  candidate
  check-result
  acceptedp
  counterexample
  refinement
  next-candidate
  status
  diagnostics)

(defstruct (cegis-run-state
            (:constructor make-cegis-run-state
                (&key problem-id
                      iteration
                      status
                      current-candidate
                      accepted-candidate
                      history
                      last-counterexample
                      last-refinement
                      max-iterations
                      metadata)))
  problem-id
  iteration
  status
  current-candidate
  accepted-candidate
  history
  last-counterexample
  last-refinement
  max-iterations
  metadata)

(defstruct (cegis-refinement-kind
            (:constructor make-cegis-refinement-kind
                (&key id
                      family
                      counterexample-kind
                      replay-form
                      summary
                      terminalp
                      note)))
  id
  family
  counterexample-kind
  replay-form
  summary
  terminalp
  note)

(defstruct (cegis-family-manifest
            (:constructor make-cegis-family-manifest
                (&key id
                      problem-type
                      candidate-payload-schema
                      counterexample-kinds
                      refinement-kinds
                      operation-id
                      constraint-class
                      accepted-statuses
                      stuck-statuses
                      note)))
  id
  problem-type
  candidate-payload-schema
  counterexample-kinds
  refinement-kinds
  operation-id
  constraint-class
  accepted-statuses
  stuck-statuses
  note)

(defstruct (cegis-object
            (:constructor make-cegis-object
                (&key id family kind payload metadata)))
  id
  family
  kind
  payload
  metadata)

(defstruct (cegis-space
            (:constructor make-cegis-space
                (&key id
                      family
                      candidate-schema
                      constraint-schema
                      refinement-kinds
                      metadata)))
  id
  family
  candidate-schema
  constraint-schema
  refinement-kinds
  metadata)

(defstruct (cegis-obligation-class
            (:constructor make-cegis-obligation-class
                (&key id
                      family
                      lane
                      predicate
                      projection
                      counterexample-shape
                      refinement-action
                      soundness-note
                      metadata)))
  id
  family
  lane
  predicate
  projection
  counterexample-shape
  refinement-action
  soundness-note
  metadata)

(defstruct (cegis-search-ir
            (:constructor make-cegis-search-ir
                (&key id
                      family
                      candidate-schema
                      obligation-classes
                      projection-schema
                      replay-schema
                      metadata)))
  id
  family
  candidate-schema
  obligation-classes
  projection-schema
  replay-schema
  metadata)

(defstruct (cegis-constraint
            (:constructor make-cegis-constraint
                (&key id family kind expression source metadata)))
  id
  family
  kind
  expression
  source
  metadata)

(defstruct (cegis-refinement-rule
            (:constructor make-cegis-refinement-rule
                (&key id
                      family
                      kind
                      counterexample-kind
                      replay-form
                      terminalp
                      metadata)))
  id
  family
  kind
  counterexample-kind
  replay-form
  terminalp
  metadata)

(defstruct (cegis-evaluation
            (:constructor make-cegis-evaluation
                (&key id
                      family
                      candidate
                      status
                      hard-failures
                      soft-failures
                      constraint-count
                      candidate-cost
                      novelty
                      score
                      evidence
                      metadata)))
  id
  family
  candidate
  status
  hard-failures
  soft-failures
  constraint-count
  candidate-cost
  novelty
  score
  evidence
  metadata)

(defstruct (cegis-trace-step
            (:constructor make-cegis-trace-step
                (&key id
                      iteration
                      candidate
                      check-summary
                      counterexample
                      refinement
                      next-candidate
                      evaluation
                      status
                      metadata)))
  id
  iteration
  candidate
  check-summary
  counterexample
  refinement
  next-candidate
  evaluation
  status
  metadata)

(defstruct (cegis-trace
            (:constructor make-cegis-trace
                (&key id
                      problem-id
                      family
                      status
                      steps
                      final-state
                      evaluation
                      metadata)))
  id
  problem-id
  family
  status
  steps
  final-state
  evaluation
  metadata)

(defgeneric propose-candidate (problem run-state))
(defgeneric check-candidate (problem candidate))
(defgeneric extract-counterexample (problem candidate check-result))
(defgeneric refine-candidate (problem candidate counterexample))
(defgeneric accept-candidate-p (problem check-result))

(defparameter *cegis-refinement-kinds*
  (list
   (make-cegis-refinement-kind
    :id :conjoin-constraint
    :family :smt-constraint
    :counterexample-kind :model-counterexample
    :replay-form '(:append-constraint :constraint)
    :summary :exclude-model
    :terminalp nil
    :note "Add a formula that eliminates the solver-provided model.")
   (make-cegis-refinement-kind
    :id :require-law
    :family :lsip-edge-policy
    :counterexample-kind :missing-obligation-class
    :replay-form '(:append-law :law-id :for-obligation :obligation-class)
    :summary :add-required-law
    :terminalp nil
    :note "Add the LSIP law that discharges a missing edge obligation class.")
   (make-cegis-refinement-kind
    :id :tighten-guard
    :family :generic
    :counterexample-kind :guard-counterexample
    :replay-form '(:replace-guard :guard)
    :summary :narrow-admissible-inputs
    :terminalp nil
    :note "Reserved generic refinement for compiler-search guard specialization.")
   (make-cegis-refinement-kind
    :id :restrict-branch-domain
    :family :generic
    :counterexample-kind :branch-counterexample
    :replay-form '(:restrict-branch-domain :selector :constraint)
    :summary :specialize-branch
    :terminalp nil
    :note "Reserved generic refinement for branch-local search space restriction.")
   (make-cegis-refinement-kind
    :id :disable-mutation
    :family :generic
    :counterexample-kind :mutation-counterexample
    :replay-form '(:disable-mutation :mutation-kind)
    :summary :remove-invalid-mutation
    :terminalp nil
    :note "Reserved generic refinement for disabling a failed compiler-search mutation.")
   (make-cegis-refinement-kind
    :id :no-refinement
    :family :generic
    :counterexample-kind :unrefinable-counterexample
    :replay-form nil
    :summary :stuck
    :terminalp t
    :note "Terminal marker for counterexamples that the current family cannot refine.")))

(defparameter *cegis-family-manifests*
  (list
   (make-cegis-family-manifest
    :id :smt-constraint
    :problem-type 'smt-cegis-problem
    :candidate-payload-schema
    '(:constraints list :meaning "conjoined with base assumptions before SMT checking")
    :counterexample-kinds '(:model-counterexample)
    :refinement-kinds '(:conjoin-constraint :no-refinement)
    :operation-id :run-smt-cegis
    :constraint-class :smt-constraint-cegis
    :accepted-statuses '(:accepted)
    :stuck-statuses '(:stuck :max-iterations)
    :note "CEGIS over Lisp-authored SMT specs in the admitted Bool/BV/Int fragment.")
   (make-cegis-family-manifest
    :id :lsip-edge-policy
    :problem-type 'lsip-edge-policy-cegis-problem
    :candidate-payload-schema
    '(:law-ids list
      :metadata (:fallback-policy :evidence-threshold :score)
      :meaning "selected LSIP laws checked against a compiled lowering relation")
    :counterexample-kinds '(:missing-obligation-class :lsip-law-failure)
    :refinement-kinds '(:require-law :no-refinement)
    :operation-id :run-lsip-edge-policy-cegis
    :constraint-class :lsip-edge-policy-cegis
    :accepted-statuses '(:accepted)
    :stuck-statuses '(:stuck :max-iterations)
    :note "CEGIS over LSIP edge-policy law selections, without owning LSIP lowering semantics.")
   (make-cegis-family-manifest
    :id :compiler-mutation
    :problem-type 'compiler-mutation-cegis-problem
    :candidate-payload-schema
    '(:payload plist
      :keys (:guard :branch-restrictions :disabled-mutations)
      :meaning "generic compiler-search candidate payload refined by replay actions")
    :counterexample-kinds '(:guard-counterexample
                            :branch-counterexample
                            :mutation-counterexample)
    :refinement-kinds '(:tighten-guard
                        :restrict-branch-domain
                        :disable-mutation
                        :no-refinement)
    :operation-id :run-compiler-mutation-cegis
    :constraint-class :compiler-mutation-cegis
    :accepted-statuses '(:accepted)
    :stuck-statuses '(:stuck :max-iterations)
    :note "Generic CEGIS over compiler-search mutation constraints; FORMAL owns replay, not compiler semantics.")))

(defparameter *cegis-obligation-classes*
  (list
   (make-cegis-obligation-class
    :id :smt-model-exclusion
    :family :smt-constraint
    :lane :smt
    :predicate '(:candidate-satisfies-goal-under-base-assumptions)
    :projection '(:smt-query :goal-conjoined-with-candidate-constraints)
    :counterexample-shape '(:kind :model-counterexample :witness :smt-model)
    :refinement-action '(:conjoin-constraint :boolean-model-blocker)
    :soundness-note
    "Unsat of the blocked projection excludes the returned model from later candidates."
    :metadata '(:bridge-target :check-smt-spec))
   (make-cegis-obligation-class
    :id :lsip-obligation-coverage
    :family :lsip-edge-policy
    :lane :lsip
    :predicate '(:selected-laws-cover-required-obligation-classes)
    :projection '(:lsip-law-selection :required-obligation-classes :selected-law-ids)
    :counterexample-shape '(:kind :missing-obligation-class :witness :obligation-class)
    :refinement-action '(:require-law :law-id)
    :soundness-note
    "Selecting a law for the missing obligation class extends the edge-policy candidate toward coverage closure."
    :metadata '(:bridge-target :check-lsip-law))
   (make-cegis-obligation-class
    :id :lsip-law-satisfaction
    :family :lsip-edge-policy
    :lane :lsip
    :predicate '(:selected-laws-hold-on-relation)
    :projection '(:lsip-law-check :relation :selected-law-ids)
    :counterexample-shape '(:kind :lsip-law-failure :witness :lsip-law-result)
    :refinement-action '(:no-refinement :law-failure)
    :soundness-note
    "A failing structural law is terminal for the current LSIP candidate unless the relation changes."
    :metadata '(:bridge-target :check-lsip-law))
   (make-cegis-obligation-class
    :id :compiler-input-domain-guard
    :family :compiler-mutation
    :lane :formal
    :predicate '(:guard-admits-only-safe-inputs)
    :projection '(:guard-projection
                  :kernel-predicate guard-safe-p
                  :smt-projection guard-formula)
    :counterexample-shape '(:kind :guard-counterexample :witness :guard-spec)
    :refinement-action '(:tighten-guard :replace-guard)
    :soundness-note
    "A refined guard narrows the candidate domain so future executions discharge the same input-domain failure."
    :metadata '(:search-lane :compiler))
   (make-cegis-obligation-class
    :id :compiler-branch-domain
    :family :compiler-mutation
    :lane :formal
    :predicate '(:branch-choice-stays-within-admitted-domain)
    :projection '(:branch-domain-projection
                  :selectors (:opcode :addressing-mode :rewrite-choice)
                  :smt-projection branch-domain-formula)
    :counterexample-shape '(:kind :branch-counterexample :witness :branch-domain-spec)
    :refinement-action '(:restrict-branch-domain :selector :constraint)
    :soundness-note
    "A branch-domain refinement eliminates the counterexample branch while preserving the remaining candidate family."
    :metadata '(:search-lane :compiler))
   (make-cegis-obligation-class
    :id :compiler-mutation-admissibility
    :family :compiler-mutation
    :lane :formal
    :predicate '(:mutation-kind-is-admitted-for-current-search-state)
    :projection '(:mutation-admissibility
                  :disabled-mutations
                  :smt-projection mutation-admissibility-formula)
    :counterexample-shape '(:kind :mutation-counterexample :witness :mutation-kind)
    :refinement-action '(:disable-mutation :mutation-kind)
    :soundness-note
    "Disabling a failed mutation kind removes the rejected synthesis move from later proposals."
    :metadata '(:search-lane :compiler))))

(defun list-cegis-refinement-kinds ()
  (copy-list *cegis-refinement-kinds*))

(defun find-cegis-refinement-kind (id &optional family)
  (find-if (lambda (entry)
             (and (eq id (cegis-refinement-kind-id entry))
                  (or (null family)
                      (eq family (cegis-refinement-kind-family entry))
                      (eq :generic (cegis-refinement-kind-family entry)))))
           *cegis-refinement-kinds*))

(defun list-cegis-obligation-classes ()
  (copy-list *cegis-obligation-classes*))

(defun find-cegis-obligation-class (id &optional family)
  (find-if (lambda (entry)
             (and (eq id (cegis-obligation-class-id entry))
                  (or (null family)
                      (eq family (cegis-obligation-class-family entry)))))
           *cegis-obligation-classes*))

(defun cegis-obligation-class-object (entry)
  (let ((class (if (typep entry 'cegis-obligation-class)
                   entry
                   (find-cegis-obligation-class entry))))
    (unless class
      (kernel-error "unknown CEGIS obligation class ~S" entry))
    (list :id (cegis-obligation-class-id class)
          :family (cegis-obligation-class-family class)
          :lane (cegis-obligation-class-lane class)
          :predicate (copy-tree (cegis-obligation-class-predicate class))
          :projection (copy-tree (cegis-obligation-class-projection class))
          :counterexample-shape
          (copy-tree (cegis-obligation-class-counterexample-shape class))
          :refinement-action
          (copy-tree (cegis-obligation-class-refinement-action class))
          :soundness-note (cegis-obligation-class-soundness-note class)
          :metadata (copy-tree (cegis-obligation-class-metadata class)))))

(defun list-cegis-obligation-class-objects ()
  (mapcar #'cegis-obligation-class-object
          (list-cegis-obligation-classes)))

(defun list-cegis-family-manifests ()
  (copy-list *cegis-family-manifests*))

(defun find-cegis-family-manifest (id)
  (find id *cegis-family-manifests*
        :key #'cegis-family-manifest-id
        :test #'eq))

(defun cegis-refinement-kind-object (entry)
  (list :id (cegis-refinement-kind-id entry)
        :family (cegis-refinement-kind-family entry)
        :counterexample-kind (cegis-refinement-kind-counterexample-kind entry)
        :replay-form (cegis-refinement-kind-replay-form entry)
        :summary (cegis-refinement-kind-summary entry)
        :terminalp (cegis-refinement-kind-terminalp entry)
        :note (cegis-refinement-kind-note entry)))

(defun cegis-family-manifest-object (manifest)
  (let ((entry (if (typep manifest 'cegis-family-manifest)
                   manifest
                   (find-cegis-family-manifest manifest))))
    (unless entry
      (kernel-error "unknown CEGIS family manifest ~S" manifest))
    (list :id (cegis-family-manifest-id entry)
          :problem-type (cegis-family-manifest-problem-type entry)
          :candidate-payload-schema
          (copy-tree (cegis-family-manifest-candidate-payload-schema entry))
          :counterexample-kinds
          (copy-list (cegis-family-manifest-counterexample-kinds entry))
          :refinement-kinds
          (copy-list (cegis-family-manifest-refinement-kinds entry))
          :operation-id (cegis-family-manifest-operation-id entry)
          :constraint-class (cegis-family-manifest-constraint-class entry)
          :accepted-statuses
          (copy-list (cegis-family-manifest-accepted-statuses entry))
          :stuck-statuses
          (copy-list (cegis-family-manifest-stuck-statuses entry))
          :note (cegis-family-manifest-note entry))))

(defun list-cegis-family-manifest-objects ()
  (mapcar #'cegis-family-manifest-object
          (list-cegis-family-manifests)))

(defun list-cegis-spaces ()
  (mapcar (lambda (manifest)
            (cegis-family-space (cegis-family-manifest-id manifest)))
          (list-cegis-family-manifests)))

(defun describe-cegis-space (family)
  (cegis-family-space family))

(defun cegis-family-obligation-classes (family)
  (remove-if-not (lambda (entry)
                   (eq family (cegis-obligation-class-family entry)))
                 (list-cegis-obligation-classes)))

(defun %cegis-family-projection-schema (family)
  (case family
    (:smt-constraint
     '(:projection-lane :smt
       :reference-target :check-smt-spec
       :projection-kind :formula
       :result-kind :smt-status))
    (:lsip-edge-policy
     '(:projection-lane :lsip
       :reference-target :check-lsip-law
       :projection-kind :structural-law-selection
       :result-kind :lsip-law-result))
    (:compiler-mutation
     '(:projection-lane :formal
       :reference-target :compiler-search
       :projection-kind :search-constraint
       :projection-views (:kernel-predicate :smt-formula :counterexample-spec)
       :result-kind :cegis-trace))
    (otherwise
     (kernel-error "unknown CEGIS family for projection schema ~S" family))))

(defun %cegis-family-replay-schema (family)
  (case family
    (:smt-constraint
     '(:replay-actions (:append-constraint)
       :replay-target :candidate-constraints))
    (:lsip-edge-policy
     '(:replay-actions (:append-law :no-refinement)
       :replay-target :selected-law-ids))
    (:compiler-mutation
     '(:replay-actions (:replace-guard
                        :restrict-branch-domain
                        :disable-mutation)
       :replay-target :search-constraint-ir))
    (otherwise
     (kernel-error "unknown CEGIS family for replay schema ~S" family))))

(defun cegis-family-search-ir (family)
  (let ((space (cegis-family-space family))
        (classes (cegis-family-obligation-classes family)))
    (make-cegis-search-ir
     :id family
     :family family
     :candidate-schema (copy-tree (cegis-space-candidate-schema space))
     :obligation-classes (copy-list classes)
     :projection-schema (%cegis-family-projection-schema family)
     :replay-schema (%cegis-family-replay-schema family)
     :metadata (append
                (copy-tree (cegis-space-metadata space))
                (list :admission-constraint-classes
                      (case family
                        (:smt-constraint
                         '(:smt-constraint-cegis :smt-admitted-bridge))
                        (:lsip-edge-policy
                         '(:lsip-edge-policy-cegis :structural-lsip-law))
                        (:compiler-mutation
                         '(:compiler-mutation-cegis))
                        (otherwise
                         '())))
                (list :constraint-schema
                      (copy-tree (cegis-space-constraint-schema space)))))))

(defun list-cegis-search-irs ()
  (mapcar (lambda (manifest)
            (cegis-family-search-ir (cegis-family-manifest-id manifest)))
          (list-cegis-family-manifests)))

(defun describe-cegis-search-ir (family)
  (cegis-family-search-ir family))

(defun make-cegis-normalized-score
    (&key
       (hard-failures 0)
       (soft-failures 0)
       (constraint-count 0)
       (candidate-cost 0)
       (novelty 0))
  (list :hard-failures hard-failures
        :soft-failures soft-failures
        :constraint-count constraint-count
        :candidate-cost candidate-cost
        :novelty novelty
        :score (+ (* 1000 hard-failures)
                  (* 100 soft-failures)
                  constraint-count
                  candidate-cost
                  (- novelty))
        :lower-is-better-p t))

(defun cegis-family-space (family)
  (let ((manifest (find-cegis-family-manifest family)))
    (unless manifest
      (kernel-error "unknown CEGIS family ~S" family))
    (make-cegis-space
     :id (cegis-family-manifest-id manifest)
     :family (cegis-family-manifest-id manifest)
     :candidate-schema
     (copy-tree (cegis-family-manifest-candidate-payload-schema manifest))
     :constraint-schema
     (list :counterexample-kinds
           (copy-list (cegis-family-manifest-counterexample-kinds manifest))
           :accepted-statuses
           (copy-list (cegis-family-manifest-accepted-statuses manifest))
           :stuck-statuses
           (copy-list (cegis-family-manifest-stuck-statuses manifest)))
     :refinement-kinds
     (copy-list (cegis-family-manifest-refinement-kinds manifest))
     :metadata (list :operation-id
                     (cegis-family-manifest-operation-id manifest)
                     :constraint-class
                     (cegis-family-manifest-constraint-class manifest)))))

(defun cegis-candidate-object (candidate)
  (make-cegis-object
   :id (cegis-candidate-id candidate)
   :family (cegis-candidate-family candidate)
   :kind :candidate
   :payload (copy-tree (cegis-candidate-payload candidate))
   :metadata (copy-tree (cegis-candidate-metadata candidate))))

(defun cegis-refinement-rule-object (kind &optional family)
  (let ((entry (find-cegis-refinement-kind kind family)))
    (unless entry
      (kernel-error "unknown CEGIS refinement kind ~S for family ~S"
                    kind
                    family))
    (make-cegis-refinement-rule
     :id (cegis-refinement-kind-id entry)
     :family (cegis-refinement-kind-family entry)
     :kind (cegis-refinement-kind-id entry)
     :counterexample-kind (cegis-refinement-kind-counterexample-kind entry)
     :replay-form (copy-tree (cegis-refinement-kind-replay-form entry))
     :terminalp (cegis-refinement-kind-terminalp entry)
     :metadata (list :summary (cegis-refinement-kind-summary entry)
                     :note (cegis-refinement-kind-note entry)))))

(defun cegis-refinement-constraint (refinement)
  (let* ((metadata (cegis-refinement-metadata refinement))
         (kind (cegis-refinement-kind refinement))
         (rule (find-cegis-refinement-kind kind)))
    (make-cegis-constraint
     :id (cegis-refinement-id refinement)
     :family (or (getf metadata :family)
                 (and rule (cegis-refinement-kind-family rule)))
     :kind kind
     :expression (copy-tree (cegis-refinement-payload refinement))
     :source (copy-tree (cegis-refinement-replay-payload refinement))
     :metadata (copy-tree metadata))))

(defun make-initial-cegis-run-state (problem)
  (make-cegis-run-state
   :problem-id (cegis-problem-id problem)
   :iteration 0
   :status :running
   :history '()
   :max-iterations (cegis-problem-max-iterations problem)
   :metadata (copy-tree (cegis-problem-metadata problem))))

(defun %smt-cegis-candidate-constraints (candidate)
  (copy-tree (or (cegis-candidate-payload candidate) '())))

(defun %smt-cegis-candidate-id (problem suffix)
  (format nil "cegis:~(~A~):~A"
          (cegis-problem-id problem)
          suffix))

(defun %smt-cegis-obligation-id (problem iteration)
  (intern (format nil "CEGIS-~A-~D"
                  (string-upcase (string (cegis-problem-id problem)))
                  iteration)
          :keyword))

(defun %smt-cegis-obligation (problem candidate iteration)
  (make-smt-obligation
   :id (%smt-cegis-obligation-id problem iteration)
   :label (format nil "~(~A~)-step-~D" (cegis-problem-id problem) iteration)
   :logic (smt-cegis-problem-logic problem)
   :vars (copy-tree (smt-cegis-problem-vars problem))
   :assumptions (append (copy-tree (smt-cegis-problem-base-assumptions problem))
                        (%smt-cegis-candidate-constraints candidate))
   :goal (copy-tree (smt-cegis-problem-goal problem))
   :polarity :expect-status
   :expected-status (smt-cegis-problem-expected-status problem)
   :semantic-tags '(:cegis :smt-constraint)
   :metadata (list :candidate-id (cegis-candidate-id candidate)
                   :problem-id (cegis-problem-id problem)
                   :iteration iteration)))

(defun %smt-cegis-spec (problem candidate iteration)
  (make-smt-spec
   :id (intern (format nil "CEGIS-SPEC-~A-~D"
                       (string-upcase (string (cegis-problem-id problem)))
                       iteration)
               :keyword)
   :logic (smt-cegis-problem-logic problem)
   :obligations (list (%smt-cegis-obligation problem candidate iteration))
   :semantic-tags '(:cegis)
   :metadata (list :problem-id (cegis-problem-id problem)
                   :candidate-id (cegis-candidate-id candidate)
                   :iteration iteration)))

(defun %smt-cegis-model-artifact (store)
  (first (advisory-store-find-by-kind store :model)))

(defun %smt-cegis-check-report (check-result)
  (getf check-result :report))

(defun %smt-cegis-report-store (check-result)
  (getf (%smt-cegis-check-report check-result) :store))

(defun %smt-cegis-report-query (check-result)
  (getf (%smt-cegis-check-report check-result) :query))

(defun %smt-cegis-report-obligation-id (check-result)
  (getf (%smt-cegis-check-report check-result) :id))

(defun %smt-cegis-model-value (name sort model)
  (cdr (assoc (smt-var name sort) model :test #'equal)))

(defun %boolean-model-blocker (problem model)
  (let ((literals '()))
    (dolist (entry (smt-cegis-problem-vars problem))
      (destructuring-bind (name sort) entry
        (when (equal sort (smt-bool-sort))
          (let ((value (%smt-cegis-model-value name sort model)))
            (when (member value '(t nil))
              (push (if value
                        (smt-not (smt-var name sort))
                        (smt-var name sort))
                    literals))))))
    (cond
      ((null literals) nil)
      ((null (rest literals)) (first literals))
      (t (apply #'smt-or (nreverse literals))))))

(defun %lsip-edge-policy-candidate-law-ids (candidate)
  (copy-list (or (cegis-candidate-payload candidate) '())))

(defun %lsip-edge-policy-candidate-id (problem suffix)
  (format nil "cegis:~(~A~):~A"
          (cegis-problem-id problem)
          suffix))

(defun %lsip-edge-policy-obligation-classes (law-ids)
  (remove-duplicates
   (mapcar (lambda (law-id)
             (let ((law (find-lsip-law law-id)))
               (and law (lsip-law-obligation-class law))))
           law-ids)
   :test #'equal))

(defun %lsip-edge-policy-law-for-obligation (edge-id obligation-class selected-law-ids)
  (let ((candidate
          (find obligation-class
                (list-lsip-laws-for-edge edge-id)
                :key #'lsip-law-obligation-class
                :test #'equal)))
    (and candidate
         (not (member (lsip-law-id candidate) selected-law-ids :test #'equal))
         (lsip-law-id candidate))))

(defun %lsip-edge-policy-candidate-score (problem law-ids)
  (let* ((enabled-obligation-classes
           (%lsip-edge-policy-obligation-classes law-ids))
         (missing-obligation-classes
           (set-difference
            (lsip-edge-policy-cegis-problem-required-obligation-classes problem)
            enabled-obligation-classes
            :test #'equal))
         (selected-count (length law-ids))
         (missing-count (length missing-obligation-classes))
         (score
           (make-cegis-normalized-score
            :hard-failures missing-count
            :soft-failures 0
            :constraint-count selected-count
            :candidate-cost 0
            :novelty 0)))
    (append score
            (list :selected-law-count selected-count
                  :enabled-obligation-count (length enabled-obligation-classes)
                  :missing-obligation-count missing-count))))

(defun %lsip-edge-policy-metadata (problem law-ids)
  (list :fallback-policy
        (lsip-edge-policy-cegis-problem-fallback-policy problem)
        :evidence-threshold
        (lsip-edge-policy-cegis-problem-evidence-threshold problem)
        :score
        (%lsip-edge-policy-candidate-score problem law-ids)))

(defun %compiler-mutation-candidate-id (problem suffix)
  (format nil "cegis:~(~A~):~A"
          (cegis-problem-id problem)
          suffix))

(defun %compiler-mutation-counterexample-spec (problem iteration)
  (nth iteration (compiler-mutation-cegis-problem-counterexamples problem)))

(defun %compiler-mutation-obligation-class-id (kind)
  (ecase kind
    (:guard-counterexample :compiler-input-domain-guard)
    (:branch-counterexample :compiler-branch-domain)
    (:mutation-counterexample :compiler-mutation-admissibility)))

(defun %compiler-mutation-counterexample-replay (kind spec)
  (ecase kind
    (:guard-counterexample
     (list :replace-guard
           (or (getf spec :guard)
               (getf spec :payload))))
    (:branch-counterexample
     (list :restrict-branch-domain
           (getf spec :selector)
           (or (getf spec :constraint)
               (getf spec :payload))))
    (:mutation-counterexample
     (list :disable-mutation
           (or (getf spec :mutation-kind)
               (getf spec :payload))))))

(defun %compiler-mutation-refinement-kind (counterexample-kind)
  (ecase counterexample-kind
    (:guard-counterexample :tighten-guard)
    (:branch-counterexample :restrict-branch-domain)
    (:mutation-counterexample :disable-mutation)))

(defmethod propose-candidate ((problem compiler-mutation-cegis-problem)
                              (run-state cegis-run-state))
  (or (cegis-run-state-current-candidate run-state)
      (make-cegis-candidate
       :id (%compiler-mutation-candidate-id problem 0)
       :family :compiler-mutation
       :payload (copy-tree (compiler-mutation-cegis-problem-initial-payload problem))
       :metadata (list :problem-id (cegis-problem-id problem)
                       :iteration (cegis-run-state-iteration run-state)))))

(defmethod check-candidate ((problem compiler-mutation-cegis-problem)
                            (candidate cegis-candidate))
  (let* ((iteration (or (getf (cegis-candidate-metadata candidate) :iteration)
                        0))
         (counterexample-spec
           (%compiler-mutation-counterexample-spec problem iteration))
         (obligation-class
           (and counterexample-spec
                (%compiler-mutation-obligation-class-id
                 (getf counterexample-spec :kind))))
         (actual-status (if counterexample-spec :rejected :accepted))
         (expected-status (compiler-mutation-cegis-problem-expected-status problem)))
    (list :candidate candidate
          :obligation-class obligation-class
          :actual-status actual-status
          :expected-status expected-status
          :matchedp (eq actual-status expected-status)
          :unknownp nil
          :counterexample-spec counterexample-spec)))

(defmethod accept-candidate-p ((problem compiler-mutation-cegis-problem) check-result)
  (declare (ignore problem))
  (and (eq (getf check-result :actual-status) :accepted)
       (getf check-result :matchedp)))

(defmethod extract-counterexample ((problem compiler-mutation-cegis-problem)
                                   (candidate cegis-candidate)
                                   check-result)
  (when (accept-candidate-p problem check-result)
    (return-from extract-counterexample nil))
  (let* ((spec (getf check-result :counterexample-spec))
         (kind (getf spec :kind)))
    (when (null spec)
      (return-from extract-counterexample nil))
    (unless (member kind '(:guard-counterexample
                          :branch-counterexample
                          :mutation-counterexample)
                    :test #'eq)
      (kernel-error "unsupported compiler mutation counterexample kind ~S" kind))
    (make-cegis-counterexample
     :id (%compiler-mutation-candidate-id
          problem
          (format nil "counterexample-~D"
                  (or (getf (cegis-candidate-metadata candidate) :iteration)
                      0)))
     :problem-id (cegis-problem-id problem)
     :family :compiler-mutation
     :kind kind
     :source-operation :check-compiler-mutation
     :failing-obligation (or (getf check-result :obligation-class)
                             (getf spec :obligation)
                             (getf spec :selector)
                             (getf spec :mutation-kind))
     :witness-kind :compiler-mutation-counterexample
     :witness (copy-tree spec)
     :replay-payload (copy-tree spec)
     :diagnostics (list :candidate-id (cegis-candidate-id candidate)))))

(defmethod refine-candidate ((problem compiler-mutation-cegis-problem)
                             (candidate cegis-candidate)
                             (counterexample cegis-counterexample))
  (let* ((kind (cegis-counterexample-kind counterexample))
         (spec (cegis-counterexample-witness counterexample))
         (refinement-kind (%compiler-mutation-refinement-kind kind))
         (replay (%compiler-mutation-counterexample-replay kind spec))
         (next-iteration
           (1+ (or (getf (cegis-candidate-metadata candidate) :iteration) 0)))
         (refinement
           (make-cegis-refinement
            :id (%compiler-mutation-candidate-id
                 problem
                 (format nil "refinement-~D" next-iteration))
            :problem-id (cegis-problem-id problem)
            :kind refinement-kind
            :payload (rest replay)
            :replay-payload replay
            :summary (cegis-refinement-kind-summary
                      (find-cegis-refinement-kind refinement-kind :compiler-mutation))
            :metadata (list :counterexample (cegis-counterexample-id counterexample)
                            :family :compiler-mutation
                            :candidate-id (cegis-candidate-id candidate))))
         (next-candidate
           (apply-cegis-refinement
            problem
            candidate
            refinement
            :iteration next-iteration)))
    (values next-candidate refinement)))

(defmethod propose-candidate ((problem smt-cegis-problem) (run-state cegis-run-state))
  (or (cegis-run-state-current-candidate run-state)
      (make-cegis-candidate
       :id (%smt-cegis-candidate-id problem 0)
       :family :smt-constraint
       :payload (copy-tree (smt-cegis-problem-initial-constraints problem))
       :metadata (list :problem-id (cegis-problem-id problem)
                       :iteration (cegis-run-state-iteration run-state)))))

(defmethod check-candidate ((problem smt-cegis-problem) (candidate cegis-candidate))
  (let* ((iteration (or (getf (cegis-candidate-metadata candidate) :iteration) 0))
         (spec (%smt-cegis-spec problem candidate iteration))
         (capability-result
           (invoke-formal-capability
            :check-smt-spec
            :caller-class :synth
            :spec spec))
         (payload (formal-capability-result-payload capability-result)))
    (list :spec spec
          :candidate candidate
          :capability-result capability-result
          :report (and (consp payload) (first payload)))))

(defmethod accept-candidate-p ((problem smt-cegis-problem) check-result)
  (declare (ignore problem))
  (let ((report (%smt-cegis-check-report check-result)))
    (and report
         (getf report :matchedp)
         (not (getf report :unknownp)))))

(defun %cegis-refinement-next-iteration (candidate iteration)
  (or iteration
      (1+ (or (getf (cegis-candidate-metadata candidate) :iteration) 0))))

(defun %cegis-refined-candidate-id (problem candidate next-iteration)
  (cond
    ((typep problem 'smt-cegis-problem)
     (%smt-cegis-candidate-id problem next-iteration))
    ((typep problem 'lsip-edge-policy-cegis-problem)
     (%lsip-edge-policy-candidate-id problem next-iteration))
    ((typep problem 'compiler-mutation-cegis-problem)
     (%compiler-mutation-candidate-id problem next-iteration))
    (t
     (format nil "~A:refined-~D"
             (cegis-candidate-id candidate)
             next-iteration))))

(defun %cegis-refined-candidate-metadata
    (problem candidate next-iteration next-payload)
  (cond
    ((typep problem 'smt-cegis-problem)
     (list :problem-id (cegis-problem-id problem)
           :iteration next-iteration
           :refined-from (cegis-candidate-id candidate)))
    ((typep problem 'lsip-edge-policy-cegis-problem)
     (append
      (list :problem-id (cegis-problem-id problem)
            :edge-id (lsip-edge-policy-cegis-problem-edge-id problem)
            :iteration next-iteration
            :refined-from (cegis-candidate-id candidate))
      (%lsip-edge-policy-metadata problem next-payload)))
    ((typep problem 'compiler-mutation-cegis-problem)
     (append
      (%cegis-generic-plist-payload next-payload)
      (list :problem-id (cegis-problem-id problem)
            :iteration next-iteration
            :refined-from (cegis-candidate-id candidate))))
    (t
     (append
      (copy-tree (cegis-candidate-metadata candidate))
      (list :iteration next-iteration
            :refined-from (cegis-candidate-id candidate))))))

(defun %cegis-plist-put (plist key value)
  (let ((result (copy-list (or plist '()))))
    (loop for cursor on result by #'cddr
          when (eq (first cursor) key)
            do (setf (second cursor) value)
               (return-from %cegis-plist-put result))
    (append result (list key value))))

(defun %cegis-plist-append (plist key value)
  (%cegis-plist-put plist key (append (copy-list (getf plist key))
                                      (list value))))

(defun %cegis-generic-plist-payload (payload)
  (if (and (listp payload)
           (or (null payload)
               (keywordp (first payload))))
      (copy-tree payload)
      (list :base-payload (copy-tree payload))))

(defun %cegis-replay-payload (candidate refinement)
  (let* ((replay (cegis-refinement-replay-payload refinement))
         (action (first replay))
         (payload (copy-tree (cegis-candidate-payload candidate))))
    (case action
      (:append-constraint
       (append (or payload '())
               (list (or (second replay)
                         (cegis-refinement-payload refinement)))))
      (:append-law
       (append (or payload '())
               (list (or (second replay)
                         (cegis-refinement-payload refinement)))))
      (:replace-guard
       (%cegis-plist-put (%cegis-generic-plist-payload payload)
                         :guard
                         (or (second replay)
                             (cegis-refinement-payload refinement))))
      (:restrict-branch-domain
       (%cegis-plist-append
        (%cegis-generic-plist-payload payload)
        :branch-restrictions
        (list :selector (second replay)
              :constraint (third replay))))
      (:disable-mutation
       (%cegis-plist-append
        (%cegis-generic-plist-payload payload)
        :disabled-mutations
        (or (second replay)
            (cegis-refinement-payload refinement))))
      (otherwise
       (kernel-error "unsupported CEGIS replay action ~S in ~S"
                     action
                     replay)))))

(defun apply-cegis-refinement
    (problem candidate refinement &key iteration)
  (when (or (null refinement)
            (eq :no-refinement (cegis-refinement-kind refinement))
            (null (cegis-refinement-replay-payload refinement)))
    (return-from apply-cegis-refinement nil))
  (let* ((next-iteration
           (%cegis-refinement-next-iteration candidate iteration))
         (next-payload
           (%cegis-replay-payload candidate refinement))
         (next-id
           (%cegis-refined-candidate-id problem candidate next-iteration))
         (next-metadata
           (%cegis-refined-candidate-metadata
            problem
            candidate
            next-iteration
            next-payload)))
    (make-cegis-candidate
     :id next-id
     :family (cegis-candidate-family candidate)
     :payload next-payload
     :metadata next-metadata)))

(defmethod extract-counterexample ((problem smt-cegis-problem)
                                   (candidate cegis-candidate)
                                   check-result)
  (when (accept-candidate-p problem check-result)
    (return-from extract-counterexample nil))
  (let* ((report (%smt-cegis-check-report check-result))
         (store (%smt-cegis-report-store check-result))
         (model-artifact (%smt-cegis-model-artifact store))
         (witness (if model-artifact
                      (advisory-artifact-payload model-artifact)
                      (%smt-cegis-report-query check-result))))
    (make-cegis-counterexample
     :id (%smt-cegis-candidate-id problem
                                  (format nil "counterexample-~D"
                                          (or (getf (cegis-candidate-metadata candidate)
                                                    :iteration)
                                              0)))
     :problem-id (cegis-problem-id problem)
     :family :smt-constraint
     :kind :model-counterexample
     :source-operation :check-smt-spec
     :failing-obligation (%smt-cegis-report-obligation-id check-result)
     :witness-kind (if model-artifact :smt-model :query)
     :witness witness
     :replay-payload (list :query (%smt-cegis-report-query check-result))
     :diagnostics (list :actual-status (getf report :actual-status)
                        :expected-status (getf report :expected-status)
                        :has-model (not (null model-artifact))))))

(defmethod refine-candidate ((problem smt-cegis-problem)
                             (candidate cegis-candidate)
                             (counterexample cegis-counterexample))
  (let* ((model (cegis-counterexample-witness counterexample))
         (blocker (and (listp model)
                       (%boolean-model-blocker problem model))))
    (when (null blocker)
      (return-from refine-candidate
        (values nil
                (make-cegis-refinement
                 :id (%smt-cegis-candidate-id problem
                                              (format nil "refinement-stuck-~A"
                                                      (cegis-candidate-id candidate)))
                 :problem-id (cegis-problem-id problem)
                 :kind :no-refinement
                 :payload nil
                 :replay-payload nil
                 :summary :missing-boolean-model
                 :metadata (list :reason :missing-boolean-model
                                 :counterexample (cegis-counterexample-id counterexample))))))
    (let* ((next-iteration
             (1+ (or (getf (cegis-candidate-metadata candidate) :iteration) 0)))
           (refinement
             (make-cegis-refinement
             :id (%smt-cegis-candidate-id problem
                                          (format nil "refinement-~D" next-iteration))
              :problem-id (cegis-problem-id problem)
              :kind :conjoin-constraint
              :payload blocker
              :replay-payload (list :append-constraint blocker)
              :summary :exclude-model
              :metadata (list :counterexample (cegis-counterexample-id counterexample)
                              :family :smt-constraint
                              :candidate-id (cegis-candidate-id candidate))))
           (next-candidate
             (apply-cegis-refinement
              problem
              candidate
              refinement
              :iteration next-iteration)))
      (values next-candidate refinement))))

(defmethod propose-candidate ((problem lsip-edge-policy-cegis-problem)
                              (run-state cegis-run-state))
  (or (cegis-run-state-current-candidate run-state)
      (let ((law-ids
              (copy-list (lsip-edge-policy-cegis-problem-initial-law-ids problem))))
        (make-cegis-candidate
         :id (%lsip-edge-policy-candidate-id problem 0)
         :family :lsip-edge-policy
         :payload law-ids
         :metadata (append
                    (list :problem-id (cegis-problem-id problem)
                          :edge-id (lsip-edge-policy-cegis-problem-edge-id problem)
                          :iteration (cegis-run-state-iteration run-state))
                    (%lsip-edge-policy-metadata problem law-ids))))))

(defmethod check-candidate ((problem lsip-edge-policy-cegis-problem)
                            (candidate cegis-candidate))
  (let* ((edge-id (lsip-edge-policy-cegis-problem-edge-id problem))
         (relation (lsip-edge-policy-cegis-problem-relation problem))
         (selected-law-ids (%lsip-edge-policy-candidate-law-ids candidate))
         (capability-results
           (mapcar (lambda (law-id)
                     (invoke-formal-capability
                      :check-lsip-law
                      :caller-class :synth
                      :law-id law-id
                      :relation relation))
                   selected-law-ids))
         (law-results
           (mapcar #'formal-capability-result-payload capability-results))
         (enabled-obligation-classes
           (%lsip-edge-policy-obligation-classes selected-law-ids))
         (missing-obligation-classes
           (set-difference
            (lsip-edge-policy-cegis-problem-required-obligation-classes problem)
            enabled-obligation-classes
            :test #'equal))
         (failing-law-results
           (remove-if-not
            (lambda (entry)
              (and entry
                   (not (eq :accepted (lsip-law-result-status entry)))))
            law-results))
         (actual-status
           (cond
             ((and (null missing-obligation-classes)
                   (null failing-law-results))
              :accepted)
             (t :rejected)))
         (score (%lsip-edge-policy-candidate-score problem selected-law-ids))
         (expected-status (lsip-edge-policy-cegis-problem-expected-status problem)))
    (list :candidate candidate
          :edge-id edge-id
          :relation relation
          :selected-law-ids selected-law-ids
          :enabled-obligation-classes enabled-obligation-classes
          :missing-obligation-classes missing-obligation-classes
          :failing-law-results failing-law-results
          :capability-results capability-results
          :law-results law-results
          :fallback-policy (lsip-edge-policy-cegis-problem-fallback-policy problem)
          :evidence-threshold
          (lsip-edge-policy-cegis-problem-evidence-threshold problem)
          :score score
          :actual-status actual-status
          :expected-status expected-status
          :matchedp (eq expected-status actual-status)
          :unknownp nil)))

(defmethod accept-candidate-p ((problem lsip-edge-policy-cegis-problem) check-result)
  (declare (ignore problem))
  (and (eq (getf check-result :actual-status) :accepted)
       (getf check-result :matchedp)))

(defmethod extract-counterexample ((problem lsip-edge-policy-cegis-problem)
                                   (candidate cegis-candidate)
                                   check-result)
  (when (accept-candidate-p problem check-result)
    (return-from extract-counterexample nil))
  (let ((missing-obligation-classes
          (getf check-result :missing-obligation-classes))
        (failing-law-results
          (getf check-result :failing-law-results)))
    (cond
      (missing-obligation-classes
       (let ((missing (first missing-obligation-classes)))
         (make-cegis-counterexample
          :id (%lsip-edge-policy-candidate-id problem
                                              (format nil "counterexample-~D"
                                                      (or (getf (cegis-candidate-metadata candidate)
                                                                :iteration)
                                                          0)))
          :problem-id (cegis-problem-id problem)
          :family :lsip-edge-policy
          :kind :missing-obligation-class
          :source-operation :check-lsip-law
          :failing-obligation missing
          :witness-kind :obligation-class
          :witness missing
          :replay-payload (list :edge-id (lsip-edge-policy-cegis-problem-edge-id problem)
                                :required-obligation-class missing)
          :diagnostics (list :selected-law-ids (getf check-result :selected-law-ids)
                             :enabled-obligation-classes
                             (getf check-result :enabled-obligation-classes)))))
      (failing-law-results
       (let ((law-result (first failing-law-results)))
         (make-cegis-counterexample
          :id (%lsip-edge-policy-candidate-id problem
                                              (format nil "counterexample-~D"
                                                      (or (getf (cegis-candidate-metadata candidate)
                                                                :iteration)
                                                          0)))
          :problem-id (cegis-problem-id problem)
          :family :lsip-edge-policy
          :kind :lsip-law-failure
          :source-operation :check-lsip-law
          :failing-obligation (lsip-law-result-law-id law-result)
          :witness-kind :lsip-law-result
          :witness law-result
          :replay-payload (list :edge-id (lsip-edge-policy-cegis-problem-edge-id problem)
                                :law-id (lsip-law-result-law-id law-result))
          :diagnostics (list :law-status (lsip-law-result-status law-result)
                             :law-diagnostics (lsip-law-result-diagnostics law-result)))))
      (t
       nil))))

(defmethod refine-candidate ((problem lsip-edge-policy-cegis-problem)
                             (candidate cegis-candidate)
                             (counterexample cegis-counterexample))
  (let ((selected-law-ids (%lsip-edge-policy-candidate-law-ids candidate)))
    (cond
      ((eq (cegis-counterexample-kind counterexample) :missing-obligation-class)
       (let* ((obligation-class (cegis-counterexample-witness counterexample))
              (next-law-id
                (%lsip-edge-policy-law-for-obligation
                 (lsip-edge-policy-cegis-problem-edge-id problem)
                 obligation-class
                 selected-law-ids)))
         (when (null next-law-id)
           (return-from refine-candidate
             (values nil
                     (make-cegis-refinement
                      :id (%lsip-edge-policy-candidate-id problem
                                                          (format nil "refinement-stuck-~A"
                                                                  (cegis-candidate-id candidate)))
                      :problem-id (cegis-problem-id problem)
                      :kind :no-refinement
                      :payload nil
                      :replay-payload nil
                      :summary :missing-law-mapping
                      :metadata (list :reason :missing-law-mapping
                                      :counterexample (cegis-counterexample-id counterexample)
                                      :obligation-class obligation-class)))))
         (let* ((next-iteration
                  (1+ (or (getf (cegis-candidate-metadata candidate) :iteration) 0)))
                (refinement
                  (make-cegis-refinement
                   :id (%lsip-edge-policy-candidate-id problem
                                                       (format nil "refinement-~D" next-iteration))
                   :problem-id (cegis-problem-id problem)
                   :kind :require-law
                   :payload next-law-id
                   :replay-payload (list :append-law next-law-id
                                         :for-obligation obligation-class)
                   :summary :add-required-law
                   :metadata (list :counterexample (cegis-counterexample-id counterexample)
                                   :family :lsip-edge-policy
                                   :candidate-id (cegis-candidate-id candidate))))
                (next-candidate
                  (apply-cegis-refinement
                   problem
                   candidate
                   refinement
                   :iteration next-iteration)))
           (values next-candidate refinement))))
      ((eq (cegis-counterexample-kind counterexample) :lsip-law-failure)
       (values nil
               (make-cegis-refinement
                :id (%lsip-edge-policy-candidate-id problem
                                                    (format nil "refinement-stuck-~A"
                                                            (cegis-candidate-id candidate)))
                :problem-id (cegis-problem-id problem)
                :kind :no-refinement
                :payload nil
                :replay-payload nil
                :summary :law-failed-on-relation
                :metadata (list :reason :law-failed-on-relation
                                :counterexample (cegis-counterexample-id counterexample)
                                :law-id (cegis-counterexample-failing-obligation counterexample)))))
      (t
       (values nil
               (make-cegis-refinement
                :id (%lsip-edge-policy-candidate-id problem
                                                    (format nil "refinement-stuck-~A"
                                                            (cegis-candidate-id candidate)))
                :problem-id (cegis-problem-id problem)
                :kind :no-refinement
                :payload nil
                :replay-payload nil
                :summary :unsupported-counterexample
                :metadata (list :reason :unsupported-counterexample
                                :counterexample (cegis-counterexample-id counterexample))))))))

(defun run-cegis-step (problem &optional (run-state (make-initial-cegis-run-state problem)))
  (when (member (cegis-run-state-status run-state) '(:accepted :stuck :max-iterations) :test #'eq)
    (return-from run-cegis-step
      (values run-state
              (make-cegis-step-result
               :iteration (cegis-run-state-iteration run-state)
               :candidate (cegis-run-state-current-candidate run-state)
               :acceptedp (eq (cegis-run-state-status run-state) :accepted)
               :status (cegis-run-state-status run-state)
               :diagnostics (list :reason :terminal-state)))))
  (let* ((candidate (propose-candidate problem run-state))
         (check-result (check-candidate problem candidate))
         (iteration (1+ (cegis-run-state-iteration run-state))))
    (if (accept-candidate-p problem check-result)
        (let* ((step-result
                 (make-cegis-step-result
                  :iteration iteration
                  :candidate candidate
                  :check-result check-result
                  :acceptedp t
                  :status :accepted
                  :diagnostics (list :problem-id (cegis-problem-id problem))))
               (next-state
                 (make-cegis-run-state
                  :problem-id (cegis-run-state-problem-id run-state)
                  :iteration iteration
                  :status :accepted
                  :current-candidate candidate
                  :accepted-candidate candidate
                  :history (append (cegis-run-state-history run-state)
                                   (list step-result))
                  :last-counterexample nil
                  :last-refinement nil
                  :max-iterations (cegis-run-state-max-iterations run-state)
                  :metadata (copy-tree (cegis-run-state-metadata run-state)))))
          (values next-state step-result))
        (let* ((counterexample (extract-counterexample problem candidate check-result)))
          (multiple-value-bind (next-candidate refinement)
              (and counterexample (refine-candidate problem candidate counterexample))
            (let* ((step-status (cond
                                  ((null counterexample) :stuck)
                                  ((null next-candidate) :stuck)
                                  (t :counterexample)))
                   (step-result
                     (make-cegis-step-result
                      :iteration iteration
                      :candidate candidate
                      :check-result check-result
                      :acceptedp nil
                      :counterexample counterexample
                      :refinement refinement
                      :next-candidate next-candidate
                      :status step-status
                      :diagnostics (list :problem-id (cegis-problem-id problem))))
                   (terminalp (or (null next-candidate)
                                  (>= iteration (cegis-run-state-max-iterations run-state))))
                   (next-state
                     (make-cegis-run-state
                      :problem-id (cegis-run-state-problem-id run-state)
                      :iteration iteration
                      :status (cond
                                ((null next-candidate) :stuck)
                                ((>= iteration (cegis-run-state-max-iterations run-state))
                                 :max-iterations)
                                (t :running))
                      :current-candidate (if terminalp candidate next-candidate)
                      :accepted-candidate nil
                      :history (append (cegis-run-state-history run-state)
                                       (list step-result))
                      :last-counterexample counterexample
                      :last-refinement refinement
                      :max-iterations (cegis-run-state-max-iterations run-state)
                      :metadata (copy-tree (cegis-run-state-metadata run-state)))))
              (values next-state step-result)))))))

(defun %run-cegis-loop (problem &optional state max-iterations)
  (let* ((start-state
           (or state
               (make-initial-cegis-run-state problem)))
         (active-state
           (if max-iterations
               (make-cegis-run-state
                :problem-id (cegis-run-state-problem-id start-state)
                :iteration (cegis-run-state-iteration start-state)
                :status (cegis-run-state-status start-state)
                :current-candidate (cegis-run-state-current-candidate start-state)
                :accepted-candidate (cegis-run-state-accepted-candidate start-state)
                :history (copy-list (cegis-run-state-history start-state))
                :last-counterexample (cegis-run-state-last-counterexample start-state)
                :last-refinement (cegis-run-state-last-refinement start-state)
                :max-iterations max-iterations
                :metadata (copy-tree (cegis-run-state-metadata start-state)))
               start-state)))
    (loop
      while (eq (cegis-run-state-status active-state) :running)
      do (multiple-value-setq (active-state)
           (run-cegis-step problem active-state))
      finally (return active-state))))

(defun run-smt-cegis (problem &optional state max-iterations)
  (unless (typep problem 'smt-cegis-problem)
    (kernel-error "run-smt-cegis expects smt-cegis-problem, got ~S" problem))
  (%run-cegis-loop problem state max-iterations))

(defun run-lsip-edge-policy-cegis (problem &optional state max-iterations)
  (unless (typep problem 'lsip-edge-policy-cegis-problem)
    (kernel-error "run-lsip-edge-policy-cegis expects lsip-edge-policy-cegis-problem, got ~S"
                  problem))
  (%run-cegis-loop problem state max-iterations))

(defun run-compiler-mutation-cegis (problem &optional state max-iterations)
  (unless (typep problem 'compiler-mutation-cegis-problem)
    (kernel-error "run-compiler-mutation-cegis expects compiler-mutation-cegis-problem, got ~S"
                  problem))
  (%run-cegis-loop problem state max-iterations))

(defun run-cegis-family (family problem &optional state max-iterations)
  (let* ((family* (or family (cegis-problem-family problem)))
         (manifest (find-cegis-family-manifest family*)))
    (unless manifest
      (kernel-error "unknown CEGIS family ~S" family*))
    (unless (eq family* (cegis-problem-family problem))
      (kernel-error "CEGIS family ~S does not match problem family ~S"
                    family*
                    (cegis-problem-family problem)))
    (unless (typep problem (cegis-family-manifest-problem-type manifest))
      (kernel-error "CEGIS family ~S expects ~S, got ~S"
                    family*
                    (cegis-family-manifest-problem-type manifest)
                    problem))
    (%run-cegis-loop problem state max-iterations)))

(defun %cegis-candidate-payload-size (candidate)
  (let ((payload (and candidate (cegis-candidate-payload candidate))))
    (cond
      ((null payload) 0)
      ((listp payload) (length payload))
      (t 1))))

(defun %cegis-run-state-refinement-kinds (run-state)
  (remove nil
          (mapcar (lambda (step)
                    (let ((refinement
                            (cegis-step-result-refinement step)))
                      (and refinement
                           (cegis-refinement-kind refinement))))
                  (cegis-run-state-history run-state))))

(defun cegis-run-state-score (run-state)
  (let* ((status (cegis-run-state-status run-state))
         (candidate (or (cegis-run-state-accepted-candidate run-state)
                        (cegis-run-state-current-candidate run-state)))
         (payload-size (%cegis-candidate-payload-size candidate))
         (iterations (cegis-run-state-iteration run-state)))
    (make-cegis-normalized-score
     :hard-failures (case status
                      (:accepted 0)
                      (:running 0)
                      (:max-iterations 1)
                      (:stuck 2)
                      (otherwise 1))
     :soft-failures (if (eq status :running) 1 0)
     :constraint-count payload-size
     :candidate-cost iterations
     :novelty 0)))

(defun cegis-run-state-evaluation (run-state)
  (let* ((score (cegis-run-state-score run-state))
         (candidate (or (cegis-run-state-accepted-candidate run-state)
                        (cegis-run-state-current-candidate run-state))))
    (make-cegis-evaluation
     :id (format nil "cegis-evaluation:~(~A~):~D"
                 (cegis-run-state-problem-id run-state)
                 (cegis-run-state-iteration run-state))
     :family (and candidate (cegis-candidate-family candidate))
     :candidate candidate
     :status (cegis-run-state-status run-state)
     :hard-failures (getf score :hard-failures)
     :soft-failures (getf score :soft-failures)
     :constraint-count (getf score :constraint-count)
     :candidate-cost (getf score :candidate-cost)
     :novelty (getf score :novelty)
     :score (getf score :score)
     :evidence (mapcar (lambda (step)
                         (list :iteration (cegis-step-result-iteration step)
                               :status (cegis-step-result-status step)
                               :counterexample-kind
                               (and (cegis-step-result-counterexample step)
                                    (cegis-counterexample-kind
                                     (cegis-step-result-counterexample step)))
                               :refinement-kind
                               (and (cegis-step-result-refinement step)
                                    (cegis-refinement-kind
                                     (cegis-step-result-refinement step)))))
                       (cegis-run-state-history run-state))
     :metadata (list :problem-id (cegis-run-state-problem-id run-state)
                     :normalized-score score))))

(defun %cegis-check-result-summary (check-result)
  (cond
    ((null check-result)
     nil)
    ((and (listp check-result)
          (getf check-result :report))
     (let ((report (getf check-result :report)))
       (list :kind :smt-spec-check
             :actual-status (getf report :actual-status)
             :expected-status (getf report :expected-status)
             :matchedp (getf report :matchedp)
             :unknownp (getf report :unknownp)
             :query-digest (and (getf report :query)
                                (artifact-digest (getf report :query))))))
    ((listp check-result)
     (list :kind :plist-check
           :actual-status (getf check-result :actual-status)
           :expected-status (getf check-result :expected-status)
           :matchedp (getf check-result :matchedp)
           :unknownp (getf check-result :unknownp)
           :payload-digest (artifact-digest check-result)))
    (t
     (list :kind :opaque-check
           :payload-digest (artifact-digest check-result)))))

(defun cegis-step-result-score (step)
  (let* ((status (cegis-step-result-status step))
         (candidate (or (cegis-step-result-next-candidate step)
                        (cegis-step-result-candidate step))))
    (make-cegis-normalized-score
     :hard-failures (case status
                      (:accepted 0)
                      (:counterexample 1)
                      (:stuck 2)
                      (:max-iterations 1)
                      (otherwise 1))
     :soft-failures (if (eq status :counterexample) 1 0)
     :constraint-count (%cegis-candidate-payload-size candidate)
     :candidate-cost (or (cegis-step-result-iteration step) 0)
     :novelty 0)))

(defun cegis-step-result-evaluation (step)
  (let* ((score (cegis-step-result-score step))
         (candidate (or (cegis-step-result-next-candidate step)
                        (cegis-step-result-candidate step))))
    (make-cegis-evaluation
     :id (format nil "cegis-step-evaluation:~A:~D"
                 (and candidate (cegis-candidate-id candidate))
                 (or (cegis-step-result-iteration step) 0))
     :family (and candidate (cegis-candidate-family candidate))
     :candidate candidate
     :status (cegis-step-result-status step)
     :hard-failures (getf score :hard-failures)
     :soft-failures (getf score :soft-failures)
     :constraint-count (getf score :constraint-count)
     :candidate-cost (getf score :candidate-cost)
     :novelty (getf score :novelty)
     :score (getf score :score)
     :evidence (list :counterexample
                     (cegis-step-result-counterexample step)
                     :refinement
                     (cegis-step-result-refinement step))
     :metadata (list :normalized-score score))))

(defun cegis-step-result-trace-step (step)
  (make-cegis-trace-step
   :id (format nil "cegis-trace-step:~D:~A"
               (or (cegis-step-result-iteration step) 0)
               (cegis-step-result-status step))
   :iteration (cegis-step-result-iteration step)
   :candidate (cegis-step-result-candidate step)
   :check-summary (%cegis-check-result-summary
                   (cegis-step-result-check-result step))
   :counterexample (cegis-step-result-counterexample step)
   :refinement (cegis-step-result-refinement step)
   :next-candidate (cegis-step-result-next-candidate step)
   :evaluation (cegis-step-result-evaluation step)
   :status (cegis-step-result-status step)
   :metadata (copy-tree (cegis-step-result-diagnostics step))))

(defun cegis-trace-from-run-state (run-state &key family)
  (let* ((steps (mapcar #'cegis-step-result-trace-step
                        (cegis-run-state-history run-state)))
         (candidate (or (cegis-run-state-accepted-candidate run-state)
                        (cegis-run-state-current-candidate run-state)))
         (trace-family (or family
                           (and candidate (cegis-candidate-family candidate))))
         (evaluation (cegis-run-state-evaluation run-state))
         (source (list :problem-id (cegis-run-state-problem-id run-state)
                       :family trace-family
                       :status (cegis-run-state-status run-state)
                       :iterations (cegis-run-state-iteration run-state)
                       :step-ids (mapcar #'cegis-trace-step-id steps))))
    (make-cegis-trace
     :id (format nil "cegis-trace:~(~A~):~X"
                 (cegis-run-state-problem-id run-state)
                 (artifact-digest source))
     :problem-id (cegis-run-state-problem-id run-state)
     :family trace-family
     :status (cegis-run-state-status run-state)
     :steps steps
     :final-state run-state
     :evaluation evaluation
     :metadata (list :iterations (cegis-run-state-iteration run-state)
                     :history-length (length steps)
                     :source-digest (artifact-digest source)))))

(defun %cegis-candidate-equal-p (lhs rhs)
  (and (or (and (null lhs) (null rhs))
           (and lhs
                rhs
                (equal (cegis-candidate-id lhs)
                       (cegis-candidate-id rhs))
                (equal (cegis-candidate-family lhs)
                       (cegis-candidate-family rhs))
                (equal (cegis-candidate-payload lhs)
                       (cegis-candidate-payload rhs))
                (equal (cegis-candidate-metadata lhs)
                       (cegis-candidate-metadata rhs))))))

(defun replay-cegis-trace (problem trace)
  (let ((failures '())
        (checked 0))
    (dolist (step (cegis-trace-steps trace))
      (let* ((candidate (cegis-trace-step-candidate step))
             (refinement (cegis-trace-step-refinement step))
             (expected (cegis-trace-step-next-candidate step))
             (actual (and refinement
                          (apply-cegis-refinement problem candidate refinement))))
        (cond
          ((and (null refinement) (null expected))
           (incf checked))
          ((%cegis-candidate-equal-p expected actual)
           (incf checked))
          (t
           (push (list :step-id (cegis-trace-step-id step)
                       :iteration (cegis-trace-step-iteration step)
                       :expected-candidate-id
                       (and expected (cegis-candidate-id expected))
                       :actual-candidate-id
                       (and actual (cegis-candidate-id actual)))
                 failures)))))
    (list :status (if failures :rejected :accepted)
          :validp (null failures)
          :problem-id (cegis-problem-id problem)
          :trace-id (cegis-trace-id trace)
          :checked-steps checked
          :failure-count (length failures)
          :failures (nreverse failures))))

(defun run-cegis-step-artifact (problem &optional state)
  (multiple-value-bind (next-state step)
      (run-cegis-step problem (or state (make-initial-cegis-run-state problem)))
    (list :state next-state
          :step step
          :trace-step (cegis-step-result-trace-step step)
          :state-summary (summarize-cegis-run-state next-state))))

(defun run-cegis-trace (family problem &optional state max-iterations)
  (let ((run-state (run-cegis-family family problem state max-iterations)))
    (cegis-trace-from-run-state run-state
                                :family (or family
                                            (cegis-problem-family problem)))))

(defun %cegis-key-string (key)
  (etypecase key
    (string key)
    (symbol
     (string-downcase
      (substitute #\_ #\- (symbol-name key))))))

(defun %cegis-plist->json-object (plist)
  (loop for (key value) on plist by #'cddr
        collect (cons (%cegis-key-string key) value)))

(defun %cegis-json-object->plist (object)
  (loop for (key . value) in object
        append (list (intern (string-upcase
                              (substitute #\- #\_ key))
                             :keyword)
                     value)))

(defun %cegis-artifact-maybe-plist (value)
  (cond
    ((or (typep value 'cegis-space)
         (typep value 'cegis-obligation-class)
         (typep value 'cegis-search-ir)
         (typep value 'cegis-candidate)
         (typep value 'cegis-constraint)
         (typep value 'cegis-counterexample)
         (typep value 'cegis-refinement)
         (typep value 'cegis-evaluation)
         (typep value 'cegis-trace-step)
         (typep value 'cegis-trace))
     (cegis-artifact-plist value))
    (t
     (copy-tree value))))

(defun %cegis-artifact-evidence-plist (evidence)
  (cond
    ((and (listp evidence)
          (keywordp (first evidence)))
     (loop for (key value) on evidence by #'cddr
           append (list key (%cegis-artifact-maybe-plist value))))
    ((listp evidence)
     (mapcar #'%cegis-artifact-maybe-plist evidence))
    (t
     (%cegis-artifact-maybe-plist evidence))))

(defun cegis-artifact-plist (artifact)
  (cond
    ((typep artifact 'cegis-space)
     (list :type :cegis-space
           :id (cegis-space-id artifact)
           :family (cegis-space-family artifact)
           :candidate-schema (copy-tree (cegis-space-candidate-schema artifact))
           :constraint-schema (copy-tree (cegis-space-constraint-schema artifact))
           :refinement-kinds (copy-list (cegis-space-refinement-kinds artifact))
           :metadata (copy-tree (cegis-space-metadata artifact))))
    ((typep artifact 'cegis-obligation-class)
     (list :type :cegis-obligation-class
           :id (cegis-obligation-class-id artifact)
           :family (cegis-obligation-class-family artifact)
           :lane (cegis-obligation-class-lane artifact)
           :predicate (copy-tree (cegis-obligation-class-predicate artifact))
           :projection (copy-tree (cegis-obligation-class-projection artifact))
           :counterexample-shape
           (copy-tree (cegis-obligation-class-counterexample-shape artifact))
           :refinement-action
           (copy-tree (cegis-obligation-class-refinement-action artifact))
           :soundness-note (cegis-obligation-class-soundness-note artifact)
           :metadata (copy-tree (cegis-obligation-class-metadata artifact))))
    ((typep artifact 'cegis-search-ir)
     (list :type :cegis-search-ir
           :id (cegis-search-ir-id artifact)
           :family (cegis-search-ir-family artifact)
           :candidate-schema (copy-tree (cegis-search-ir-candidate-schema artifact))
           :obligation-classes (mapcar #'cegis-artifact-plist
                                       (cegis-search-ir-obligation-classes artifact))
           :projection-schema (copy-tree (cegis-search-ir-projection-schema artifact))
           :replay-schema (copy-tree (cegis-search-ir-replay-schema artifact))
           :metadata (copy-tree (cegis-search-ir-metadata artifact))))
    ((typep artifact 'cegis-candidate)
     (list :type :cegis-candidate
           :id (cegis-candidate-id artifact)
           :family (cegis-candidate-family artifact)
           :payload (copy-tree (cegis-candidate-payload artifact))
           :metadata (copy-tree (cegis-candidate-metadata artifact))))
    ((typep artifact 'cegis-counterexample)
     (list :type :cegis-counterexample
           :id (cegis-counterexample-id artifact)
           :problem-id (cegis-counterexample-problem-id artifact)
           :family (cegis-counterexample-family artifact)
           :kind (cegis-counterexample-kind artifact)
           :source-operation (cegis-counterexample-source-operation artifact)
           :failing-obligation (cegis-counterexample-failing-obligation artifact)
           :witness-kind (cegis-counterexample-witness-kind artifact)
           :witness (copy-tree (cegis-counterexample-witness artifact))
           :replay-payload (copy-tree (cegis-counterexample-replay-payload artifact))
           :diagnostics (copy-tree (cegis-counterexample-diagnostics artifact))))
    ((typep artifact 'cegis-constraint)
     (list :type :cegis-constraint
           :id (cegis-constraint-id artifact)
           :family (cegis-constraint-family artifact)
           :kind (cegis-constraint-kind artifact)
           :expression (copy-tree (cegis-constraint-expression artifact))
           :source (copy-tree (cegis-constraint-source artifact))
           :metadata (copy-tree (cegis-constraint-metadata artifact))))
    ((typep artifact 'cegis-refinement)
     (list :type :cegis-refinement
           :id (cegis-refinement-id artifact)
           :problem-id (cegis-refinement-problem-id artifact)
           :kind (cegis-refinement-kind artifact)
           :payload (copy-tree (cegis-refinement-payload artifact))
           :replay-payload (copy-tree (cegis-refinement-replay-payload artifact))
           :summary (cegis-refinement-summary artifact)
           :metadata (copy-tree (cegis-refinement-metadata artifact))))
    ((typep artifact 'cegis-evaluation)
     (list :type :cegis-evaluation
           :id (cegis-evaluation-id artifact)
           :family (cegis-evaluation-family artifact)
           :candidate (%cegis-artifact-maybe-plist
                       (cegis-evaluation-candidate artifact))
           :status (cegis-evaluation-status artifact)
           :hard-failures (cegis-evaluation-hard-failures artifact)
           :soft-failures (cegis-evaluation-soft-failures artifact)
           :constraint-count (cegis-evaluation-constraint-count artifact)
           :candidate-cost (cegis-evaluation-candidate-cost artifact)
           :novelty (cegis-evaluation-novelty artifact)
           :score (cegis-evaluation-score artifact)
           :evidence (%cegis-artifact-evidence-plist
                      (cegis-evaluation-evidence artifact))
           :metadata (copy-tree (cegis-evaluation-metadata artifact))))
    ((typep artifact 'cegis-trace-step)
     (list :type :cegis-trace-step
           :id (cegis-trace-step-id artifact)
           :iteration (cegis-trace-step-iteration artifact)
           :candidate (%cegis-artifact-maybe-plist
                       (cegis-trace-step-candidate artifact))
           :check-summary (copy-tree (cegis-trace-step-check-summary artifact))
           :counterexample (%cegis-artifact-maybe-plist
                            (cegis-trace-step-counterexample artifact))
           :refinement (%cegis-artifact-maybe-plist
                        (cegis-trace-step-refinement artifact))
           :next-candidate (%cegis-artifact-maybe-plist
                            (cegis-trace-step-next-candidate artifact))
           :evaluation (%cegis-artifact-maybe-plist
                        (cegis-trace-step-evaluation artifact))
           :status (cegis-trace-step-status artifact)
           :metadata (copy-tree (cegis-trace-step-metadata artifact))))
    ((typep artifact 'cegis-trace)
     (list :type :cegis-trace
           :id (cegis-trace-id artifact)
           :problem-id (cegis-trace-problem-id artifact)
           :family (cegis-trace-family artifact)
           :status (cegis-trace-status artifact)
           :steps (mapcar #'cegis-artifact-plist
                          (cegis-trace-steps artifact))
           :evaluation (%cegis-artifact-maybe-plist
                        (cegis-trace-evaluation artifact))
           :metadata (copy-tree (cegis-trace-metadata artifact))))
    (t
     (kernel-error "unsupported CEGIS artifact for plist serialization: ~S"
                   artifact))))

(defun cegis-artifact-json-object (artifact)
  (%cegis-plist->json-object (cegis-artifact-plist artifact)))

(defun %cegis-artifact-nested-from-plist (value)
  (if (and (listp value)
           (getf value :type))
      (cegis-artifact-from-plist value)
      (copy-tree value)))

(defun cegis-artifact-from-plist (plist)
  (ecase (getf plist :type)
    (:cegis-space
     (make-cegis-space
      :id (getf plist :id)
      :family (getf plist :family)
      :candidate-schema (copy-tree (getf plist :candidate-schema))
      :constraint-schema (copy-tree (getf plist :constraint-schema))
      :refinement-kinds (copy-list (getf plist :refinement-kinds))
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-obligation-class
     (make-cegis-obligation-class
      :id (getf plist :id)
      :family (getf plist :family)
      :lane (getf plist :lane)
      :predicate (copy-tree (getf plist :predicate))
      :projection (copy-tree (getf plist :projection))
      :counterexample-shape (copy-tree (getf plist :counterexample-shape))
      :refinement-action (copy-tree (getf plist :refinement-action))
      :soundness-note (getf plist :soundness-note)
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-search-ir
     (make-cegis-search-ir
      :id (getf plist :id)
      :family (getf plist :family)
      :candidate-schema (copy-tree (getf plist :candidate-schema))
      :obligation-classes (mapcar #'cegis-artifact-from-plist
                                  (getf plist :obligation-classes))
      :projection-schema (copy-tree (getf plist :projection-schema))
      :replay-schema (copy-tree (getf plist :replay-schema))
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-candidate
     (make-cegis-candidate
      :id (getf plist :id)
      :family (getf plist :family)
      :payload (copy-tree (getf plist :payload))
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-counterexample
     (make-cegis-counterexample
      :id (getf plist :id)
      :problem-id (getf plist :problem-id)
      :family (getf plist :family)
      :kind (getf plist :kind)
      :source-operation (getf plist :source-operation)
      :failing-obligation (getf plist :failing-obligation)
      :witness-kind (getf plist :witness-kind)
      :witness (copy-tree (getf plist :witness))
      :replay-payload (copy-tree (getf plist :replay-payload))
      :diagnostics (copy-tree (getf plist :diagnostics))))
    (:cegis-constraint
     (make-cegis-constraint
      :id (getf plist :id)
      :family (getf plist :family)
      :kind (getf plist :kind)
      :expression (copy-tree (getf plist :expression))
      :source (copy-tree (getf plist :source))
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-refinement
     (make-cegis-refinement
      :id (getf plist :id)
      :problem-id (getf plist :problem-id)
      :kind (getf plist :kind)
      :payload (copy-tree (getf plist :payload))
      :replay-payload (copy-tree (getf plist :replay-payload))
      :summary (getf plist :summary)
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-evaluation
     (make-cegis-evaluation
      :id (getf plist :id)
      :family (getf plist :family)
      :candidate (%cegis-artifact-nested-from-plist (getf plist :candidate))
      :status (getf plist :status)
      :hard-failures (getf plist :hard-failures)
      :soft-failures (getf plist :soft-failures)
      :constraint-count (getf plist :constraint-count)
      :candidate-cost (getf plist :candidate-cost)
      :novelty (getf plist :novelty)
      :score (getf plist :score)
      :evidence (copy-tree (getf plist :evidence))
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-trace-step
     (make-cegis-trace-step
      :id (getf plist :id)
      :iteration (getf plist :iteration)
      :candidate (%cegis-artifact-nested-from-plist (getf plist :candidate))
      :check-summary (copy-tree (getf plist :check-summary))
      :counterexample (%cegis-artifact-nested-from-plist (getf plist :counterexample))
      :refinement (%cegis-artifact-nested-from-plist (getf plist :refinement))
      :next-candidate (%cegis-artifact-nested-from-plist (getf plist :next-candidate))
      :evaluation (%cegis-artifact-nested-from-plist (getf plist :evaluation))
      :status (getf plist :status)
      :metadata (copy-tree (getf plist :metadata))))
    (:cegis-trace
     (make-cegis-trace
      :id (getf plist :id)
      :problem-id (getf plist :problem-id)
      :family (getf plist :family)
      :status (getf plist :status)
      :steps (mapcar #'cegis-artifact-from-plist
                     (getf plist :steps))
      :evaluation (%cegis-artifact-nested-from-plist (getf plist :evaluation))
      :metadata (copy-tree (getf plist :metadata))))))

(defun cegis-artifact-from-json-object (object)
  (cegis-artifact-from-plist (%cegis-json-object->plist object)))

(defun summarize-cegis-run-state (run-state)
  (let* ((history (cegis-run-state-history run-state))
         (last-step (and history (car (last history))))
         (accepted (cegis-run-state-accepted-candidate run-state))
         (active-candidate (or accepted
                               (cegis-run-state-current-candidate run-state)))
         (last-counterexample (cegis-run-state-last-counterexample run-state))
         (last-refinement (cegis-run-state-last-refinement run-state)))
    (list :problem-id (cegis-run-state-problem-id run-state)
          :status (cegis-run-state-status run-state)
          :iterations (cegis-run-state-iteration run-state)
          :history-length (length history)
          :score (cegis-run-state-score run-state)
          :accepted-candidate-id (and accepted (cegis-candidate-id accepted))
          :accepted-candidate-family (and accepted (cegis-candidate-family accepted))
          :accepted-candidate-payload-size
          (%cegis-candidate-payload-size accepted)
          :active-candidate-payload-size
          (%cegis-candidate-payload-size active-candidate)
          :refinement-kinds (%cegis-run-state-refinement-kinds run-state)
          :last-step-status (and last-step (cegis-step-result-status last-step))
          :last-counterexample-kind
          (and last-counterexample (cegis-counterexample-kind last-counterexample))
          :last-refinement-kind
          (and last-refinement (cegis-refinement-kind last-refinement))
          :last-refinement-summary
          (and last-refinement (cegis-refinement-summary last-refinement))
          :stuck-reason
          (and (member (cegis-run-state-status run-state)
                       '(:stuck :max-iterations)
                       :test #'eq)
               last-refinement
               (cegis-refinement-summary last-refinement)))))
