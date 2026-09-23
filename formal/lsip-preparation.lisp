(in-package :mini-kernel)

(defstruct lsip-stratum
  id
  band
  meaning
  current-carrier
  main-implementation
  explicit-status
  shared-lane-status
  rust-legacy-status
  afsm-lane-status
  note)

(defstruct lsip-lowering-edge
  id
  source-strata
  target-strata
  lowering-family
  invariant-families
  future-gate-kind
  status
  note)

(defstruct lsip-edge-contract
  id
  edge-id
  contract-family
  obligation-classes
  candidate-constraint-classes
  required-evidence
  blocking-gaps
  note)

(defstruct lsip-stratum-object
  id
  stratum-id
  object-id
  summary
  payload
  digest
  metadata)

(defstruct lsip-relation
  id
  edge-id
  source-objects
  target-objects
  facts
  metadata)

(defstruct lsip-law
  id
  edge-id
  obligation-class
  relation-kind
  required-facts
  predicate
  evidence-kind
  note)

(defstruct lsip-law-result
  law-id
  edge-id
  relation-id
  status
  evidence-kind
  payload
  diagnostics)

(defstruct lsip-edge-gate
  edge-id
  contract-id
  operation-id
  supported-law-ids
  supported-obligation-classes
  missing-obligation-classes
  available-constraint-classes
  coverage-status
  note)

(defstruct lsip-edge-capability-surface
  edge-id
  contract-id
  candidate-constraint-classes
  available-constraint-classes
  missing-constraint-classes
  supported-law-ids
  missing-obligation-classes
  coverage-status
  note)

(defstruct lsip-edge-search-alignment
  edge-id
  contract-id
  family
  search-ir-id
  projection-lane
  candidate-constraint-classes
  matched-constraint-classes
  required-obligation-classes
  supported-obligation-classes
  missing-obligation-classes
  coverage-status
  note)

(defstruct lsip-search-preparation-manifest
  edge-count
  alignment-count
  ready-edge-count
  partial-edge-count
  edge-search-alignments
  summary)

(defstruct lsip-formal-preparation-report
  stratum-count
  edge-count
  contract-count
  capability-surface-count
  blocking-gaps
  edge-summaries
  summary)

(defparameter *lsip-strata*
  (list
   (make-lsip-stratum
    :id :j0
    :band :j
    :meaning "DDS-addressed repository authority surface."
    :current-carrier "JSON / typed-tree witness rows / authority rows"
    :main-implementation '("constitutional.lisp" "addressing.lisp" "runtime_sync.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Repository authority surface.")
   (make-lsip-stratum
    :id :s0
    :band :s
    :meaning "Raw authored surface forms."
    :current-carrier "payload/control forms, builder DSL"
    :main-implementation '("builders.lisp" "constitutional.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Source authoring layer.")
   (make-lsip-stratum
    :id :s1
    :band :s
    :meaning "Expanded surface-form graph."
    :current-carrier "node tree"
    :main-implementation '("constitutional.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Materialized surface tree.")
   (make-lsip-stratum
    :id :t0
    :band :t
    :meaning "Canonical typed tree with DDS/CAL/tokens/operator metadata."
    :current-carrier "typed-node"
    :main-implementation '("constitutional.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Recognized typed tree.")
   (make-lsip-stratum
    :id :t1
    :band :t
    :meaning "Callable-normalized typed surface."
    :current-carrier "typed-node"
    :main-implementation '("callable helpers" "rust typed emit assumptions")
    :explicit-status :no
    :shared-lane-status :partial
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Hidden/fused callable normalization layer.")
   (make-lsip-stratum
    :id :o0
    :band :o
    :meaning "Operator-contract-resolved typed surface."
    :current-carrier "resolved typed-node tree"
    :main-implementation '("resolve-typed-operator-contracts")
    :explicit-status :no
    :shared-lane-status :partial
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Hidden operator-contract resolution layer.")
   (make-lsip-stratum
    :id :b0
    :band :b
    :meaning "Binding/use canonicalization."
    :current-carrier "typed meta + links"
    :main-implementation '("annotate-binding-use-links" "token/scope machinery")
    :explicit-status :partial
    :shared-lane-status :yes
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Binding and scope normalization.")
   (make-lsip-stratum
    :id :c0
    :band :c
    :meaning "Closure/call normalization."
    :current-carrier "typed meta + IR2 lowering rules"
    :main-implementation '("ir2.lisp")
    :explicit-status :partial
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Closure/call normalization fused into IR2 today.")
   (make-lsip-stratum
    :id :p0
    :band :p
    :meaning "Slot graph before real expansion."
    :current-carrier "synth-slot-plan atoms/scopes/slots/edges"
    :main-implementation '("synth_slots.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Initial slot planning layer.")
   (make-lsip-stratum
    :id :p1
    :band :p
    :meaning "Expanded slot bundles / multi-lane arity."
    :current-carrier "bundles / policies / placements"
    :main-implementation '("synth_slots.lisp")
    :explicit-status :partial
    :shared-lane-status :partial
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Placeholder expanded slot bundle layer.")
   (make-lsip-stratum
    :id :p2
    :band :p
    :meaning "Target-aware slot placement plan."
    :current-carrier "slot obligations and placements"
    :main-implementation '("synth_slots.lisp" "ir1_plan.lisp")
    :explicit-status :partial
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Target-aware slot placement.")
   (make-lsip-stratum
    :id :x0
    :band :x
    :meaning "Structural executable normalization."
    :current-carrier "ir2-node graph"
    :main-implementation '("ir2.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Structural executable normalization.")
   (make-lsip-stratum
    :id :x1
    :band :x
    :meaning "Executable VM IR / tranche-1 ISA."
    :current-carrier "compiler-ir-node"
    :main-implementation '("compiler_ir.lisp" "lower_surface_to_ir.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "CompilerIR executable VM IR.")
   (make-lsip-stratum
    :id :x2
    :band :x
    :meaning "Rehydrated executable program object."
    :current-carrier "runtime-program"
    :main-implementation '("runtime_rehydration.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Runtime-program object.")
   (make-lsip-stratum
    :id :e0
    :band :e
    :meaning "Target-aware emission plan."
    :current-carrier "ir1-plan"
    :main-implementation '("ir1_plan.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Target-aware emission planning.")
   (make-lsip-stratum
    :id :e1
    :band :e
    :meaning "Backend-shaped carrier generation."
    :current-carrier "placement fragments / Rust text emitter shaping"
    :main-implementation '("ir1_plan.lisp" "lower_ir_to_lisp.lisp" "lower_ir_to_rust.lisp" "rustgen.lisp")
    :explicit-status :partial
    :shared-lane-status :yes
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Backend carrier shaping.")
   (make-lsip-stratum
    :id :r0
    :band :r
    :meaning "Runtime heap and step state."
    :current-carrier "eval-state, env/store/kont, trace registries"
    :main-implementation '("compiler_ir_semantics.lisp" "runtime_state.lisp" "runtime_trace_registry.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :no
    :afsm-lane-status :no
    :note "Live runtime execution state.")
   (make-lsip-stratum
    :id :a0
    :band :a
    :meaning "Admitted/synced authority artifacts."
    :current-carrier "runtime sync bundles, evaluator admission objects, emitted artifacts"
    :main-implementation '("transactions.lisp" "admission.lisp" "runtime_sync.lisp")
    :explicit-status :yes
    :shared-lane-status :yes
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Authority sync/admission artifact layer.")
   (make-lsip-stratum
    :id :k0
    :band :k
    :meaning "Raw AFSM kernel spec."
    :current-carrier ":states/:events/:guards/:transitions plist"
    :main-implementation '("afsm-kernel->rust-form caller input")
    :explicit-status :yes
    :shared-lane-status :no
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Raw AFSM kernel surface.")
   (make-lsip-stratum
    :id :k1
    :band :k
    :meaning "Normalized AFSM kernel."
    :current-carrier "normalized kernel rows"
    :main-implementation '("afsm-kernel-normalize")
    :explicit-status :yes
    :shared-lane-status :no
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Normalized AFSM kernel rows.")
   (make-lsip-stratum
    :id :k2
    :band :k
    :meaning "Validated/indexed AFSM transition graph."
    :current-carrier "normalized kernel + guard/event/transition tables"
    :main-implementation '("afsm-kernel-validate" "afsm-kernel-transition-index")
    :explicit-status :partial
    :shared-lane-status :no
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "Validated and indexed AFSM graph.")
   (make-lsip-stratum
    :id :k3
    :band :k
    :meaning "AFSM typed expansion surface."
    :current-carrier "builder DSL forms for enums/fns/impls"
    :main-implementation '("afsm-kernel-step-body-form" "afsm-kernel->rust-form")
    :explicit-status :yes
    :shared-lane-status :indirect
    :rust-legacy-status :yes
    :afsm-lane-status :yes
    :note "AFSM expansion back into typed surface.")))

(defparameter *lsip-lowering-edges*
  (list
   (make-lsip-lowering-edge
    :id :s1-to-t0
    :source-strata '(:s1)
    :target-strata '(:t0)
    :lowering-family :recognition
    :invariant-families '(:shape-preservation
                          :constitutional-class-preservation
                          :token-metadata-preservation)
    :future-gate-kind :structural-lsip-law
    :status :preparation
    :note "Recognition edge from expanded surface to canonical typed tree.")
   (make-lsip-lowering-edge
    :id :t0-to-x0
    :source-strata '(:t0)
    :target-strata '(:x0)
    :lowering-family :structural-executable-normalization
    :invariant-families '(:binding-preservation
                          :closure-normalization
                          :operator-metadata-preservation)
    :future-gate-kind :structural-lsip-law
    :status :preparation
    :note "Typed tree to structural executable normalization.")
   (make-lsip-lowering-edge
    :id :x0-to-x1
    :source-strata '(:x0)
    :target-strata '(:x1)
    :lowering-family :compiler-ir-lowering
    :invariant-families '(:callable-surface-preservation
                          :structural-lowering-determinism
                          :vm-ir-well-formedness)
    :future-gate-kind :structural-lsip-law
    :status :preparation
    :note "Structural executable normalization to CompilerIR.")
   (make-lsip-lowering-edge
    :id :x1-to-x2
    :source-strata '(:x1)
    :target-strata '(:x2)
    :lowering-family :runtime-rehydration
    :invariant-families '(:rehydration-stability
                          :callable-table-preservation
                          :machine-local-identity)
    :future-gate-kind :structural-lsip-law
    :status :preparation
    :note "CompilerIR to runtime-program rehydration.")
   (make-lsip-lowering-edge
    :id :x2-r0-to-a0
    :source-strata '(:x2 :r0)
    :target-strata '(:a0)
    :lowering-family :runtime-authority-sync
    :invariant-families '(:authority-linkset-preservation
                          :machine-residency-separation
                          :admission-ordering
                          :runtime-inertness)
    :future-gate-kind :structural-lsip-law
    :status :preparation
    :note "Runtime-program/runtime-state to admitted authority artifacts.")))

(defparameter *lsip-edge-contracts*
  (list
   (make-lsip-edge-contract
    :id :s1-to-t0-contract
    :edge-id :s1-to-t0
    :contract-family :recognition-contract
    :obligation-classes '(:shape-preservation
                          :constitutional-class-preservation
                          :typed-tree-recognition-totality)
    :candidate-constraint-classes '(:structural-lsip-law)
    :required-evidence '(:typed-tree-shape-evidence)
    :blocking-gaps '(:structural-lsip-law-capability
                     :typed-surface-recognition-contract)
    :note "Future FORMAL gate for recognition from S1 to T0.")
   (make-lsip-edge-contract
    :id :t0-to-x0-contract
    :edge-id :t0-to-x0
    :contract-family :structural-executable-normalization-contract
    :obligation-classes '(:binding-preservation
                          :closure-normalization
                          :operator-metadata-preservation)
    :candidate-constraint-classes '(:structural-lsip-law)
    :required-evidence '(:ir2-normalization-evidence)
    :blocking-gaps '(:structural-lsip-law-capability
                     :binding-closure-normalization-contract)
    :note "Future FORMAL gate for T0 to X0.")
   (make-lsip-edge-contract
    :id :x0-to-x1-contract
    :edge-id :x0-to-x1
    :contract-family :compiler-ir-lowering-contract
    :obligation-classes '(:callable-surface-preservation
                          :compiler-ir-well-formedness
                          :lowering-determinism)
    :candidate-constraint-classes '(:kernel-lane-parity :structural-lsip-law)
    :required-evidence '(:compiler-ir-lowering-evidence :parity-report)
    :blocking-gaps '(:structural-lsip-law-capability
                     :compiler-ir-lowering-contract)
    :note "Future FORMAL gate for X0 to X1.")
   (make-lsip-edge-contract
    :id :x1-to-x2-contract
    :edge-id :x1-to-x2
    :contract-family :runtime-rehydration-contract
    :obligation-classes '(:rehydration-stability
                          :callable-table-preservation
                          :machine-local-identity)
    :candidate-constraint-classes '(:kernel-lane-parity
                                    :closure-profile-check
                                    :structural-lsip-law)
    :required-evidence '(:rehydration-stability-evidence
                         :audit-result
                         :parity-report)
    :blocking-gaps '(:structural-lsip-law-capability
                     :runtime-program-rehydration-contract)
    :note "Future FORMAL gate for X1 to X2.")
   (make-lsip-edge-contract
    :id :x2-r0-to-a0-contract
    :edge-id :x2-r0-to-a0
    :contract-family :runtime-authority-sync-contract
    :obligation-classes '(:authority-linkset-preservation
                          :machine-residency-separation
                          :runtime-inertness
                          :admission-ordering)
    :candidate-constraint-classes '(:smt-admitted-bridge
                                    :closure-profile-check
                                    :structural-lsip-law)
    :required-evidence '(:authority-linkage-evidence
                         :bridge-status
                         :audit-result)
    :blocking-gaps '(:structural-lsip-law-capability
                     :runtime-authority-sync-contract
                     :admission-ordering-contract)
    :note "Future FORMAL gate for X2/R0 to A0.")))

(defun %lsip-fact-present-p (facts key)
  (loop for (fact-key nil) on facts by #'cddr
        thereis (eq fact-key key)))

(defun %lsip-facts-present-p (facts keys)
  (every (lambda (key)
           (%lsip-fact-present-p facts key))
         keys))

(defun %lsip-rehydration-stability-p (relation)
  (let ((facts (lsip-relation-facts relation)))
    (and (equal (getf facts :source-program-id)
                (getf facts :target-program-id))
         (getf facts :stable-runtime-id-p)
         (getf facts :callable-surface-preserved-p)
         (getf facts :machine-local-identity-p))))

(defun %lsip-machine-residency-separation-p (relation)
  (let ((facts (lsip-relation-facts relation)))
    (and (not (equal (getf facts :resident-machine-id)
                     (getf facts :foreign-machine-id)))
         (getf facts :separated-p))))

(defun %lsip-runtime-inertness-p (relation)
  (let ((facts (lsip-relation-facts relation)))
    (and (equal (getf facts :pre-runtime-digest)
                (getf facts :post-runtime-digest))
         (getf facts :inert-p))))

(defun %lsip-authority-linkset-preservation-p (relation)
  (let ((facts (lsip-relation-facts relation)))
    (equal (getf facts :runtime-linkset-id)
           (getf facts :authority-linkset-id))))

(defun %lsip-admission-ordering-p (relation)
  (let ((facts (lsip-relation-facts relation)))
    (and (getf facts :admission-before-sync-p)
         (getf facts :registration-before-dispatch-p)
         (getf facts :no-partial-callable-visibility-p))))

(defparameter *lsip-laws*
  (list
   (make-lsip-law
    :id :x1-to-x2-rehydration-stability
    :edge-id :x1-to-x2
    :obligation-class :rehydration-stability
    :relation-kind :runtime-rehydration
    :required-facts '(:source-program-id
                      :target-program-id
                      :stable-runtime-id-p
                      :callable-surface-preserved-p
                      :machine-local-identity-p)
    :predicate #'%lsip-rehydration-stability-p
    :evidence-kind :lsip-law-result
    :note "CompilerIR and runtime-program preserve stable program identity and local callable shape.")
   (make-lsip-law
    :id :x2-r0-to-a0-machine-residency-separation
    :edge-id :x2-r0-to-a0
    :obligation-class :machine-residency-separation
    :relation-kind :runtime-authority-sync
    :required-facts '(:resident-machine-id
                      :foreign-machine-id
                      :separated-p)
    :predicate #'%lsip-machine-residency-separation-p
    :evidence-kind :lsip-law-result
    :note "Runtime residency remains machine-local under authority sync.")
   (make-lsip-law
    :id :x2-r0-to-a0-runtime-inertness
    :edge-id :x2-r0-to-a0
    :obligation-class :runtime-inertness
    :relation-kind :runtime-authority-sync
    :required-facts '(:pre-runtime-digest
                      :post-runtime-digest
                      :inert-p)
    :predicate #'%lsip-runtime-inertness-p
    :evidence-kind :lsip-law-result
    :note "Observed runtime linkage remains inert across the checked transition.")
   (make-lsip-law
    :id :x2-r0-to-a0-authority-linkset-preservation
    :edge-id :x2-r0-to-a0
    :obligation-class :authority-linkset-preservation
    :relation-kind :runtime-authority-sync
    :required-facts '(:runtime-linkset-id
                      :authority-linkset-id)
    :predicate #'%lsip-authority-linkset-preservation-p
    :evidence-kind :lsip-law-result
    :note "Authority sync preserves the runtime-program linkset identity.")
   (make-lsip-law
    :id :x2-r0-to-a0-admission-ordering
    :edge-id :x2-r0-to-a0
    :obligation-class :admission-ordering
    :relation-kind :runtime-authority-sync
    :required-facts '(:admission-before-sync-p
                      :registration-before-dispatch-p
                      :no-partial-callable-visibility-p)
    :predicate #'%lsip-admission-ordering-p
    :evidence-kind :lsip-law-result
    :note "Admission completes before sync visibility and before dispatch resumes.")))

(defun find-lsip-stratum (id)
  (find id *lsip-strata* :key #'lsip-stratum-id :test #'equal))

(defun list-lsip-strata ()
  (copy-list *lsip-strata*))

(defun find-lsip-lowering-edge (id)
  (find id *lsip-lowering-edges* :key #'lsip-lowering-edge-id :test #'equal))

(defun list-lsip-lowering-edges ()
  (copy-list *lsip-lowering-edges*))

(defun find-lsip-edge-contract (id)
  (find id *lsip-edge-contracts* :key #'lsip-edge-contract-id :test #'equal))

(defun list-lsip-edge-contracts ()
  (copy-list *lsip-edge-contracts*))

(defun find-lsip-edge-contract-for-edge (edge-id)
  (find edge-id *lsip-edge-contracts*
        :key #'lsip-edge-contract-edge-id
        :test #'equal))

(defun find-lsip-law (id)
  (find id *lsip-laws* :key #'lsip-law-id :test #'equal))

(defun list-lsip-laws ()
  (copy-list *lsip-laws*))

(defun list-lsip-laws-for-edge (edge-id)
  (remove-if-not (lambda (entry)
                   (equal edge-id (lsip-law-edge-id entry)))
                 *lsip-laws*))

(defun compile-lsip-stratum-object (stratum-id payload &key object-id summary metadata)
  (let ((stratum (find-lsip-stratum stratum-id)))
    (unless stratum
      (error "Unknown LSIP stratum ~A." stratum-id))
    (let* ((digest (artifact-digest payload))
           (object-id* (or object-id
                           (format nil "~A-object:~X" stratum-id digest))))
      (make-lsip-stratum-object
       :id (format nil "lsip-stratum-object:~A:~A" stratum-id object-id*)
       :stratum-id stratum-id
       :object-id object-id*
       :summary (or summary
                    (list :stratum-id stratum-id
                          :digest digest))
       :payload payload
       :digest digest
       :metadata metadata))))

(defun %lsip-validate-relation-side (objects expected-strata edge-id side)
  (unless (every (lambda (entry)
                   (typep entry 'lsip-stratum-object))
                 objects)
    (error "LSIP relation ~A ~A objects must be lsip-stratum-object carriers."
           edge-id side))
  (let ((actual (sort (mapcar #'lsip-stratum-object-stratum-id
                              (copy-list objects))
                      #'string<
                      :key #'symbol-name))
        (expected (sort (copy-list expected-strata)
                        #'string<
                        :key #'symbol-name)))
    (unless (equal actual expected)
      (error "LSIP relation ~A ~A strata mismatch. expected ~S, got ~S"
             edge-id side expected actual))))

(defun compile-lsip-relation
    (edge-id &key source-objects target-objects facts metadata)
  (let ((edge (find-lsip-lowering-edge edge-id)))
    (unless edge
      (error "Unknown LSIP lowering edge ~A." edge-id))
    (%lsip-validate-relation-side source-objects
                                  (lsip-lowering-edge-source-strata edge)
                                  edge-id
                                  :source)
    (%lsip-validate-relation-side target-objects
                                  (lsip-lowering-edge-target-strata edge)
                                  edge-id
                                  :target)
    (let ((relation-digest
            (artifact-digest
             (list edge-id
                   (mapcar #'lsip-stratum-object-id source-objects)
                   (mapcar #'lsip-stratum-object-id target-objects)
                   facts
                   metadata))))
      (make-lsip-relation
       :id (format nil "lsip-relation:~A:~X" edge-id relation-digest)
       :edge-id edge-id
       :source-objects (copy-list source-objects)
       :target-objects (copy-list target-objects)
       :facts facts
       :metadata metadata))))

(defun check-lsip-law (law-id relation)
  (let ((law (find-lsip-law law-id)))
    (unless law
      (error "Unknown LSIP law ~A." law-id))
    (unless (typep relation 'lsip-relation)
      (error "LSIP law checks require an lsip-relation carrier."))
    (unless (equal (lsip-law-edge-id law)
                   (lsip-relation-edge-id relation))
      (error "LSIP law ~A expects edge ~A, got relation on ~A."
             law-id
             (lsip-law-edge-id law)
             (lsip-relation-edge-id relation)))
    (let* ((facts (lsip-relation-facts relation))
           (missing-facts
             (remove-if (lambda (key)
                          (%lsip-fact-present-p facts key))
                        (lsip-law-required-facts law)))
           (predicate-ok
             (and (null missing-facts)
                  (funcall (lsip-law-predicate law) relation))))
      (make-lsip-law-result
       :law-id law-id
       :edge-id (lsip-law-edge-id law)
       :relation-id (lsip-relation-id relation)
       :status (if predicate-ok :accepted :rejected)
       :evidence-kind (lsip-law-evidence-kind law)
       :payload (list :obligation-class (lsip-law-obligation-class law)
                      :relation-kind (lsip-law-relation-kind law))
       :diagnostics (list :missing-facts missing-facts
                          :checked-facts (copy-list (lsip-law-required-facts law))
                          :note (lsip-law-note law))))))

(defun %formal-preparation-constraint-classes (&optional capability)
  (let ((capability* (or capability
                         (and (fboundp 'current-formal-capability-class)
                              (ignore-errors
                                (current-formal-capability-class))))))
    (if capability*
        (mapcar #'formal-constraint-class-id
        (formal-capability-class-constraint-classes capability*))
        '())))

(defun %cegis-search-ir-admission-constraint-classes (search-ir)
  (copy-list
   (or (getf (cegis-search-ir-metadata search-ir)
             :admission-constraint-classes)
       '())))

(defun %cegis-search-ir-projection-lane (search-ir)
  (getf (cegis-search-ir-projection-schema search-ir) :projection-lane))

(defun %lsip-edge-law-obligation-classes (edge-id)
  (remove-duplicates
   (mapcar #'lsip-law-obligation-class
           (list-lsip-laws-for-edge edge-id))
   :test #'equal))

(defun %lsip-search-alignment-supported-obligations (family edge-id)
  (case family
    (:lsip-edge-policy
     (%lsip-edge-law-obligation-classes edge-id))
    (otherwise
     '())))

(defun %lsip-search-alignment-coverage-status
    (matched-constraints missing-obligations)
  (cond
    ((null matched-constraints) :none)
    ((null missing-obligations) :complete)
    (t :partial)))

(defun build-lsip-edge-search-alignment (edge-id family)
  (let* ((contract (find-lsip-edge-contract-for-edge edge-id))
         (search-ir (describe-cegis-search-ir family)))
    (unless contract
      (error "Unknown LSIP preparation edge ~A." edge-id))
    (unless search-ir
      (error "Unknown CEGIS search IR family ~A." family))
    (let* ((candidate-constraints
             (copy-list
              (lsip-edge-contract-candidate-constraint-classes contract)))
           (admission-constraints
             (%cegis-search-ir-admission-constraint-classes search-ir))
           (matched-constraints
             (intersection candidate-constraints admission-constraints))
           (required-obligations
             (copy-list (lsip-edge-contract-obligation-classes contract)))
           (supported-obligations
             (%lsip-search-alignment-supported-obligations family edge-id))
           (missing-obligations
             (set-difference required-obligations supported-obligations))
           (coverage-status
             (%lsip-search-alignment-coverage-status
              matched-constraints
              missing-obligations)))
      (make-lsip-edge-search-alignment
       :edge-id edge-id
       :contract-id (lsip-edge-contract-id contract)
       :family family
       :search-ir-id (cegis-search-ir-id search-ir)
       :projection-lane (%cegis-search-ir-projection-lane search-ir)
       :candidate-constraint-classes candidate-constraints
       :matched-constraint-classes matched-constraints
       :required-obligation-classes required-obligations
       :supported-obligation-classes supported-obligations
       :missing-obligation-classes missing-obligations
       :coverage-status coverage-status
       :note
       (case coverage-status
         (:complete
          "Search IR matches the edge contract and covers all currently modeled obligations.")
         (:partial
          "Search IR matches part of the edge contract but still leaves missing obligations or bridge coverage.")
         (otherwise
          "Search IR does not currently attach to this edge contract."))))))

(defun list-lsip-edge-search-alignments (&optional edge-id)
  (let* ((edges (if edge-id
                    (list (or (find-lsip-lowering-edge edge-id)
                              (error "Unknown LSIP preparation edge ~A." edge-id)))
                    (list-lsip-lowering-edges)))
         (families (mapcar #'cegis-family-manifest-id
                           (list-cegis-family-manifests))))
    (mapcan (lambda (edge)
              (mapcar (lambda (family)
                        (build-lsip-edge-search-alignment
                         (lsip-lowering-edge-id edge)
                         family))
                      families))
            edges)))

(defun evaluate-lsip-search-preparation-manifest ()
  (let* ((alignments (list-lsip-edge-search-alignments))
         (ready-edges
           (remove-duplicates
            (mapcar #'lsip-edge-search-alignment-edge-id
                    (remove-if-not (lambda (entry)
                                     (eq :complete
                                         (lsip-edge-search-alignment-coverage-status
                                          entry)))
                                   alignments))
            :test #'equal))
         (partial-edges
           (set-difference
            (remove-duplicates
             (mapcar #'lsip-edge-search-alignment-edge-id
                     (remove-if-not (lambda (entry)
                                      (eq :partial
                                          (lsip-edge-search-alignment-coverage-status
                                           entry)))
                                    alignments))
             :test #'equal)
            ready-edges
            :test #'equal)))
    (make-lsip-search-preparation-manifest
     :edge-count (length *lsip-lowering-edges*)
     :alignment-count (length alignments)
     :ready-edge-count (length ready-edges)
     :partial-edge-count (length partial-edges)
     :edge-search-alignments alignments
     :summary
     (list
      :ready-edges ready-edges
      :partial-edges partial-edges
      :edges-needing-search-bridge
      (set-difference
       (mapcar #'lsip-lowering-edge-id *lsip-lowering-edges*)
       (union ready-edges partial-edges :test #'equal))
      :families-with-edge-coverage
      (remove-duplicates
       (mapcar #'lsip-edge-search-alignment-family
               (remove-if (lambda (entry)
                            (eq :none
                                (lsip-edge-search-alignment-coverage-status entry)))
                          alignments))
       :test #'equal)))))

(defun build-lsip-edge-gate (edge-id &optional capability)
  (let ((contract (find-lsip-edge-contract-for-edge edge-id)))
    (unless contract
      (error "Unknown LSIP preparation edge ~A." edge-id))
    (let* ((candidate-constraints
             (copy-list
              (lsip-edge-contract-candidate-constraint-classes contract)))
           (available-constraints
             (intersection candidate-constraints
                           (%formal-preparation-constraint-classes capability)))
           (laws (list-lsip-laws-for-edge edge-id))
           (supported-law-ids (mapcar #'lsip-law-id laws))
           (supported-obligations
             (remove-duplicates
              (mapcar #'lsip-law-obligation-class laws)
              :test #'equal))
           (missing-obligations
             (set-difference (lsip-edge-contract-obligation-classes contract)
                             supported-obligations))
           (structural-available-p
             (member :structural-lsip-law available-constraints))
           (coverage-status
             (cond
               ((null available-constraints) :none)
               ((and structural-available-p
                     (null missing-obligations)
                     (subsetp candidate-constraints available-constraints))
                :complete)
               ((or available-constraints supported-law-ids)
                :partial)
               (t :none))))
      (make-lsip-edge-gate
       :edge-id edge-id
       :contract-id (lsip-edge-contract-id contract)
       :operation-id :check-lsip-edge-gate
       :supported-law-ids supported-law-ids
       :supported-obligation-classes supported-obligations
       :missing-obligation-classes missing-obligations
       :available-constraint-classes available-constraints
       :coverage-status coverage-status
       :note (case coverage-status
               (:complete "Edge contract has an attached structural law gate and current FORMAL support.")
               (:partial "Edge contract has partial structural law coverage or partial FORMAL support.")
               (otherwise "Edge contract has no current structural law gate coverage."))))))

(defun list-lsip-edge-gates (&optional capability)
  (mapcar (lambda (edge)
            (build-lsip-edge-gate (lsip-lowering-edge-id edge)
                                  capability))
          *lsip-lowering-edges*))

(defstruct lsip-edge-gate-result
  edge-id
  contract-id
  status
  law-results
  missing-obligation-classes
  diagnostics)

(defun check-lsip-edge-gate (edge-id relation &optional capability)
  (let* ((gate (build-lsip-edge-gate edge-id capability))
         (law-results
           (mapcar (lambda (law-id)
                     (check-lsip-law law-id relation))
                   (lsip-edge-gate-supported-law-ids gate)))
         (acceptedp
           (every (lambda (entry)
                    (eq :accepted (lsip-law-result-status entry)))
                  law-results))
         (status
           (cond
             ((null law-results) :rejected)
             ((and acceptedp
                   (null (lsip-edge-gate-missing-obligation-classes gate))
                   (eq :complete (lsip-edge-gate-coverage-status gate)))
              :accepted)
             (acceptedp :partial)
             (t :rejected))))
    (make-lsip-edge-gate-result
     :edge-id edge-id
     :contract-id (lsip-edge-gate-contract-id gate)
     :status status
     :law-results law-results
     :missing-obligation-classes
     (copy-list (lsip-edge-gate-missing-obligation-classes gate))
     :diagnostics
     (list :coverage-status (lsip-edge-gate-coverage-status gate)
           :available-constraint-classes
           (copy-list (lsip-edge-gate-available-constraint-classes gate))
           :supported-law-ids
           (copy-list (lsip-edge-gate-supported-law-ids gate))))))

(defun %capability-coverage-status (candidate available)
  (let ((matched (intersection candidate available)))
    (cond
      ((null matched) :none)
      ((subsetp candidate available) :complete)
      (t :partial))))

(defun build-lsip-edge-capability-surface
    (edge-id &optional capability)
  (let* ((contract (find-lsip-edge-contract-for-edge edge-id))
         (candidate (and contract
                         (copy-list
                          (lsip-edge-contract-candidate-constraint-classes contract))))
         (available (%formal-preparation-constraint-classes capability))
         (missing (set-difference candidate available))
         (gate (build-lsip-edge-gate edge-id capability))
         (coverage-status (lsip-edge-gate-coverage-status gate)))
    (unless contract
      (error "Unknown LSIP preparation edge ~A." edge-id))
    (make-lsip-edge-capability-surface
     :edge-id edge-id
     :contract-id (lsip-edge-contract-id contract)
     :candidate-constraint-classes candidate
     :available-constraint-classes (intersection candidate available)
     :missing-constraint-classes missing
     :supported-law-ids (lsip-edge-gate-supported-law-ids gate)
     :missing-obligation-classes
     (lsip-edge-gate-missing-obligation-classes gate)
     :coverage-status coverage-status
     :note (case coverage-status
             (:complete "Current FORMAL capability surface and structural laws cover this edge contract family.")
             (:partial "Current FORMAL capability surface or structural law coverage is partial for this edge.")
             (otherwise "Current FORMAL capability surface does not yet cover this edge contract family.")))))

(defun list-lsip-edge-capability-surfaces (&optional capability)
  (mapcar (lambda (edge)
            (build-lsip-edge-capability-surface
             (lsip-lowering-edge-id edge)
             capability))
          *lsip-lowering-edges*))

(defun evaluate-lsip-formal-preparation-report (&optional capability)
  (let* ((surfaces (list-lsip-edge-capability-surfaces capability))
         (contracts (list-lsip-edge-contracts))
         (available-constraints (%formal-preparation-constraint-classes capability))
         (blocking-gaps
           (remove-duplicates
            (append
             (mapcan
              (lambda (contract)
                (remove :structural-lsip-law-capability
                        (copy-list (lsip-edge-contract-blocking-gaps contract))))
              contracts)
             (when (not (member :structural-lsip-law available-constraints))
               (list :structural-lsip-law-capability))
             (when (some #'lsip-edge-capability-surface-missing-obligation-classes
                         surfaces)
               (list :structural-lsip-law-coverage)))
            :test #'equal))
         (edge-summaries
           (mapcar (lambda (surface)
                     (let* ((edge (find-lsip-lowering-edge
                                   (lsip-edge-capability-surface-edge-id surface)))
                            (contract (find-lsip-edge-contract
                                       (lsip-edge-capability-surface-contract-id surface))))
                       (list
                        :edge-id (lsip-lowering-edge-id edge)
                        :source-strata (lsip-lowering-edge-source-strata edge)
                        :target-strata (lsip-lowering-edge-target-strata edge)
                        :future-gate-kind (lsip-lowering-edge-future-gate-kind edge)
                        :contract-family (lsip-edge-contract-contract-family contract)
                        :coverage-status
                        (lsip-edge-capability-surface-coverage-status surface)
                        :supported-law-ids
                        (lsip-edge-capability-surface-supported-law-ids surface)
                        :candidate-constraint-classes
                        (lsip-edge-capability-surface-candidate-constraint-classes surface)
                        :available-constraint-classes
                        (lsip-edge-capability-surface-available-constraint-classes surface)
                        :missing-obligation-classes
                        (lsip-edge-capability-surface-missing-obligation-classes
                         surface)
                        :missing-constraint-classes
                        (lsip-edge-capability-surface-missing-constraint-classes surface))))
                   surfaces)))
    (make-lsip-formal-preparation-report
     :stratum-count (length *lsip-strata*)
     :edge-count (length *lsip-lowering-edges*)
     :contract-count (length contracts)
     :capability-surface-count (length surfaces)
     :blocking-gaps blocking-gaps
     :edge-summaries edge-summaries
     :summary (list
               :modeled-strata
               (mapcar #'lsip-stratum-id *lsip-strata*)
               :modeled-edges
               (mapcar #'lsip-lowering-edge-id *lsip-lowering-edges*)
               :edges-with-current-coverage
               (mapcar (lambda (surface)
                         (lsip-edge-capability-surface-edge-id surface))
                       (remove-if (lambda (surface)
                                    (eq :none
                                        (lsip-edge-capability-surface-coverage-status
                                         surface)))
                                  surfaces))
               :edges-needing-new-capability
               (mapcar (lambda (surface)
                         (lsip-edge-capability-surface-edge-id surface))
                       (remove-if-not (lambda (surface)
                                        (member (lsip-edge-capability-surface-coverage-status
                                                 surface)
                                                '(:none :partial)))
                                      surfaces))
               :edges-with-complete-gates
               (mapcar (lambda (surface)
                         (lsip-edge-capability-surface-edge-id surface))
                       (remove-if-not (lambda (surface)
                                        (eq :complete
                                            (lsip-edge-capability-surface-coverage-status
                                             surface)))
                                      surfaces))
               :blocking-gap-count (length blocking-gaps)))))
