(in-package :mini-kernel)

(defstruct runtime-callable-row
  operation-id
  name
  callable
  kind
  lane
  ref-id
  argument-keys
  input-schema
  output-schema
  effect-kind
  evidence-kind
  note)

(defstruct runtime-capability-class
  id
  lane
  authority-kind
  callable-rows
  semantic-contract
  meta)

(defstruct formal-constraint-class
  id
  lane
  kind
  callable
  expected-result-kind
  note)

(defstruct formal-admission-policy
  id
  allowed-invocations
  required-evidence
  trusted-boundaries
  forbidden-mutations
  note)

(defstruct formal-capability-class
  id
  callable-rows
  operations
  constraint-classes
  evidence-kinds
  trusted-boundaries
  admission-policy
  meta)

(defstruct formal-capability-report
  capability-id
  callable-count
  operation-count
  constraint-count
  evidence-kinds
  trusted-boundaries
  admission-policy-id
  summary)

(defstruct formal-capability-operation
  id
  callable-row
  constraint-classes
  trusted-boundaries
  required-evidence
  admissible-caller-classes)

(defstruct formal-capability-invocation
  operation-id
  args
  kwargs)

(defstruct formal-capability-plan
  operation-id
  admissible-p
  reason
  operation
  mutation-kind
  diagnostics)

(defstruct formal-capability-result
  operation-id
  status
  evidence-kind
  payload
  trusted-boundaries
  rejection-reason
  diagnostics)

(defstruct search-kernel-obligation-kind
  id
  severity
  projection-operation
  payload-schema
  freshness-law
  note)

(defstruct search-formal-obligation
  id
  kind
  severity
  scope
  projection-seed
  freshness-law
  source-operation
  status
  metadata)

(defstruct search-obligation-projection
  obligation-id
  kind
  operation-id
  payloads
  totality-class
  metadata)

(defstruct search-formal-evidence
  id
  obligation-id
  obligation-kind
  evidence-kind
  judgment
  status
  certificate
  scope
  freshness-status
  resource-row
  metadata)

(defstruct search-evidence-status
  id
  terminalp
  freshness-class
  polarity
  note)

(defstruct search-evidence-state
  state-id
  obligation-statuses
  live-evidence-ids
  supersession-links
  hard-debt
  advisory-debt
  coverage-summary
  freshness-summary
  status
  metadata)

(defstruct search-evidence-update
  state-id
  evidence-ids
  obligation-statuses
  live-evidence-ids
  supersession-links
  hard-debt
  advisory-debt
  coverage-summary
  freshness-summary
  status
  metadata)

(defstruct search-evidence-monotonicity-result
  state-id
  status
  preserved-evidence-ids
  appended-evidence-ids
  supersession-links
  diagnostics)

(defstruct search-evidence-frontier
  state-id
  live-frontier
  superseded-evidence-ids
  diagnostics)

(defstruct search-supersession-consistency-result
  state-id
  status
  covered-obligation-ids
  uncovered-obligation-ids
  diagnostics)

(defstruct search-admission-law
  id
  hard-obligation-kinds
  advisory-obligation-kinds
  stale-threshold
  reject-on-fail-p
  kernel-requirements
  note)

(defstruct search-admission-result
  law-id
  state-id
  status
  hard-debt
  advisory-debt
  failing-obligation-kinds
  diagnostics)

(defstruct search-legality-clause
  id
  severity
  note)

(defstruct search-operator-class
  id
  subject-kinds
  mandatory-obligation-kinds
  kernel-requirements
  replay-required-p
  note)

(defstruct search-operator-instance
  id
  operator-class-id
  target-zone
  source-operation
  replay-token
  budget-row
  metadata)

(defstruct search-bridge-totality-result
  obligation-id
  obligation-kind
  status
  projection-operation
  payload-count
  route-operation-id
  diagnostics)

(defstruct search-legal-transition
  operator-instance-id
  operator-class-id
  state-id
  status
  satisfied-clauses
  failing-clauses
  bridge-totality-results
  diagnostics)

(defstruct compiler-family
  id
  package-name
  source-path
  dependency-paths
  entrypoints
  artifact-kinds
  note
  metadata)

(defstruct compiler-obligation-kind
  id
  severity
  check-operation
  required-artifacts
  note)

(defstruct compiler-check-result
  family-id
  obligation-kind
  source-id
  control-id
  status
  diagnostics
  metadata)

(defstruct runtime-constitution
  id
  authority-ref
  machine-ref
  registry-digest
  manifests
  authority-state
  live-state
  rehydration-state
  synchronization-state
  capability-classes
  kernel-core-algorithms
  smt-core-algorithms
  admitted-obligations
  theorem-bindings
  closure-backlog
  meta)

(defparameter *search-kernel-obligation-kinds*
  (list
   (make-search-kernel-obligation-kind
    :id :replay-defined
    :severity :hard
    :projection-operation :evaluate-formal-capability-report
    :payload-schema '(:replay-check :source-operation :scope)
    :freshness-law :immediate
    :note "Replay must remain defined for the touched derivation footprint.")
   (make-search-kernel-obligation-kind
    :id :bridge-totality
    :severity :hard
    :projection-operation :current-formal-capability-class
    :payload-schema '(:projection-check :scope :projection-seed)
    :freshness-law :immediate
    :note "Every hard search obligation must lower to a governed FORMAL payload family.")
   (make-search-kernel-obligation-kind
    :id :evidence-monotonicity
    :severity :advisory
    :projection-operation :evaluate-formal-capability-report
    :payload-schema '(:evidence-check :evidence-ids :scope)
    :freshness-law :epoch
    :note "Evidence history is append-only with supersession, not destructive rewrite.")))

(defparameter *search-admission-laws*
  (list
   (make-search-admission-law
    :id :baseline-search-admission
    :hard-obligation-kinds '(:replay-defined :bridge-totality)
    :advisory-obligation-kinds '(:evidence-monotonicity)
    :stale-threshold 0
    :reject-on-fail-p t
    :kernel-requirements '(:replayability :bridge-totality :lineage-monotonicity)
    :note "Baseline law for the first evidence-bearing search-kernel slice.")))

(defparameter *search-evidence-statuses*
  (list
   (make-search-evidence-status
    :id :open
    :terminalp nil
    :freshness-class :unknown
    :polarity :pending
    :note "No evidence has yet closed the obligation.")
   (make-search-evidence-status
    :id :fresh-pass
    :terminalp t
    :freshness-class :fresh
    :polarity :pass
    :note "Fresh passing evidence closes the obligation.")
   (make-search-evidence-status
    :id :fresh-fail
    :terminalp t
    :freshness-class :fresh
    :polarity :fail
    :note "Fresh failing evidence rejects the obligation.")
   (make-search-evidence-status
    :id :stale
    :terminalp nil
    :freshness-class :stale
    :polarity :pending
    :note "Evidence exists but is stale for admission purposes.")
   (make-search-evidence-status
    :id :superseded
    :terminalp nil
    :freshness-class :superseded
    :polarity :historical
    :note "Evidence is retained in append-only history but no longer live.")))

(defparameter *search-legality-clauses*
  (list
   (make-search-legality-clause
    :id :type-domain-ok
    :severity :hard
    :note "Operator instance arguments and target zone satisfy the frozen domain schema.")
   (make-search-legality-clause
    :id :replay-defined
    :severity :hard
    :note "Replay remains defined for the touched derivation footprint.")
   (make-search-legality-clause
    :id :bridge-totality
    :severity :hard
    :note "Every hard emitted search obligation lowers through a governed FORMAL route.")
   (make-search-legality-clause
    :id :budget-ok
    :severity :hard
    :note "Estimated search cost fits inside the current budget row.")
   (make-search-legality-clause
    :id :kernel-preserved
    :severity :hard
    :note "Minimum search-kernel requirements remain present for the candidate transition.")))

(defparameter *search-operator-classes*
  (list
   (make-search-operator-class
    :id :compiler-mutation
    :subject-kinds '(:compiler-candidate :mutation-constraint)
    :mandatory-obligation-kinds '(:replay-defined :bridge-totality)
    :kernel-requirements '(:replayability :bridge-totality)
    :replay-required-p t
    :note "Minimal compiler-mutation operator class for the first legal-transition slice.")
   (make-search-operator-class
    :id :lsip-edge-policy
    :subject-kinds '(:lsip-edge :law-selection)
    :mandatory-obligation-kinds '(:replay-defined :bridge-totality)
    :kernel-requirements '(:replayability :bridge-totality)
    :replay-required-p t
    :note "Minimal LSIP edge-policy operator class for the first legal-transition slice.")))

(defparameter *compiler-obligation-kinds*
  (list
   (make-compiler-obligation-kind
    :id :compiler-schema-well-formed
    :severity :hard
    :check-operation :check-compiler-schema
    :required-artifacts '(:compile-action :asm-prog :compiler-step)
    :note "Carrier schemas, entrypoints, and field-layout contracts are present and executable.")
   (make-compiler-obligation-kind
    :id :compiler-control-determinism
    :severity :hard
    :check-operation :check-compiler-control-determinism
    :required-artifacts '(:compile-action :asm-prog :compiler-step)
    :note "Repeated evaluation of frozen compiler entrypoints yields stable artifacts for the same source/control inputs.")
   (make-compiler-obligation-kind
    :id :compiler-lowering-totality
    :severity :hard
    :check-operation :check-compiler-lowering-totality
    :required-artifacts '(:compile-action :asm-prog :compiler-step :fragment-ir :resident-asm-image-ir)
    :note "The frozen compiler lowering edge chain produces non-null, well-typed artifacts at each declared stage.")
   (make-compiler-obligation-kind
    :id :compiler-installed-generation-soundness
    :severity :hard
    :check-operation :check-compiler-installed-generation
    :required-artifacts '(:compile-action :compiler-step :installed-generation-ir)
    :note "Installed-generation metadata agrees with the source-side action and step artifacts that produced it.")
   (make-compiler-obligation-kind
    :id :compiler-layout-monotonicity
    :severity :hard
    :check-operation :check-compiler-layout
    :required-artifacts '(:asm-prog :asm-layout-ir)
    :note "Lowered assembly layout has monotone PCs, sequential indices, and consistent label PCs.")
   (make-compiler-obligation-kind
    :id :compiler-encode-decode-roundtrip
    :severity :advisory
    :check-operation :check-compiler-roundtrip
    :required-artifacts '(:compile-action :encoded-bytes)
    :note "Decoded action-frame fields agree with the source-side action semantics for a selected carrier.")
   (make-compiler-obligation-kind
    :id :compiler-image-closure
    :severity :hard
    :check-operation :check-compiler-image-closure
    :required-artifacts '(:resident-asm-image-ir :compiler-step)
    :note "Resident compiler image remains closed: root/blob ids are live, cells are unique, and layout/blob artifacts are present.")
   (make-compiler-obligation-kind
    :id :compiler-bounded-trace-parity
    :severity :advisory
    :check-operation :check-compiler-trace-parity
    :required-artifacts '(:compiler-step :installed-generation-ir)
    :note "A bounded compiler trace remains coherent step-to-step and agrees with any registered alternate trace builder.")))

(defparameter *compiler-families*
  (list
   (make-compiler-family
    :id :stage1-mir-compiler
    :package-name :xlisp0-orbit-stage1-01-compiler
    :source-path "/home/user0/MIR/pure_asm_and_or_write/xlisp0-orbit-stage1-01-compiler.lisp"
    :dependency-paths
    '("/home/user0/MIR/pure_asm_and_or_write/xlisp0-kernel-cells.lisp"
      "/home/user0/MIR/pure_asm_and_or_write/xlisp0-orbit-stage1-01-graph.lisp"
      "/home/user0/MIR/pure_asm_and_or_write/xlisp0-orbit-stage1-01-asm-x86.lisp")
    :entrypoints
    (list
     :live-compiler-asts "STAGE1-LIVE-COMPILER-ASTS"
     :ast-source-id "COMPILER-FORM-AST-SOURCE-ID"
     :interpret-source "STAGE1-INTERPRET-SOURCE"
     :action-next-quote "COMPILE-ACTION-NEXT-QUOTE"
     :action-next-symbol "COMPILE-ACTION-NEXT-SYMBOL"
     :action-next-form "COMPILE-ACTION-NEXT-FORM"
     :action-next-entry "COMPILE-ACTION-NEXT-HELPER"
     :action-current-source "COMPILE-ACTION-CURRENT-SOURCE"
     :action-direction "COMPILE-ACTION-DIRECTION"
     :action-target-role "COMPILE-ACTION-TARGET-ROLE"
     :action-emitted-family "COMPILE-ACTION-EMITTED-FAMILY"
     :action-emit-again "COMPILE-ACTION-EMIT-AGAIN"
     :action-terminate-p "COMPILE-ACTION-TERMINATE-P"
     :action-authority "COMPILE-ACTION-AUTHORITY"
     :action-lineage-role "COMPILE-ACTION-LINEAGE-ROLE"
     :lower-source-to-asm-prog "STAGE1-LOWER-SOURCE-TO-ASM-PROG"
     :layout-asm-prog "STAGE1-LAYOUT-ASM-PROG"
     :asm-layout-entries "ASM-LAYOUT-IR-ENTRIES"
     :asm-layout-label-pcs "ASM-LAYOUT-IR-LABEL-PCS"
     :asm-layout-size "ASM-LAYOUT-IR-SIZE"
     :asm-layout-entry-index "ASM-LAYOUT-ENTRY-IR-INDEX"
     :asm-layout-entry-pc "ASM-LAYOUT-ENTRY-IR-PC"
     :asm-layout-entry-width "ASM-LAYOUT-ENTRY-IR-WIDTH"
     :asm-layout-entry-opcode "ASM-LAYOUT-ENTRY-IR-OPCODE"
     :asm-layout-entry-operands "ASM-LAYOUT-ENTRY-IR-OPERANDS"
     :encode-source-to-bytes "STAGE1-ENCODE-SOURCE-TO-BYTES"
     :decode-bytes "DECODE-ACTION-FRAME-BYTES"
     :assemble-step "STAGE1-ASSEMBLE-COMPILER-STEP"
     :live-ir-chain "STAGE1-LIVE-COMPILER-IR-CHAIN"
     :live-ir-chain-directed "STAGE1-LIVE-COMPILER-IR-CHAIN-DIRECTED"
     :step-source-id "COMPILER-STEP-SOURCE-ID"
     :step-asm-prog "COMPILER-STEP-ASM-PROG"
     :step-bytes "COMPILER-STEP-BYTES"
     :step-fragment "COMPILER-STEP-FRAGMENT-IR"
     :step-installed-generation "COMPILER-STEP-INSTALLED-GENERATION"
     :fragment-image "EMITTED-FRAGMENT-IR-RESIDENT-ASM-IMAGE"
     :installed-root-source "INSTALLED-GENERATION-IR-ROOT-SOURCE"
     :installed-root-entry "INSTALLED-GENERATION-IR-ROOT-ENTRY"
     :installed-root-family "INSTALLED-GENERATION-IR-ROOT-FAMILY"
     :installed-target-source "INSTALLED-GENERATION-IR-TARGET-SOURCE"
     :installed-successor-source "INSTALLED-GENERATION-IR-SUCCESSOR-SOURCE"
     :installed-direction "INSTALLED-GENERATION-IR-DIRECTION"
     :installed-target-role "INSTALLED-GENERATION-IR-TARGET-ROLE"
     :installed-emit-again "INSTALLED-GENERATION-IR-EMIT-AGAIN"
     :installed-terminate-p "INSTALLED-GENERATION-IR-TERMINATE-P"
     :installed-authority "INSTALLED-GENERATION-IR-AUTHORITY"
     :installed-lineage-role "INSTALLED-GENERATION-IR-LINEAGE-ROLE"
     :image-root-id "RESIDENT-ASM-IMAGE-IR-ROOT-ID"
     :image-blob-id "RESIDENT-ASM-IMAGE-IR-BLOB-ID"
     :image-cells "RESIDENT-ASM-IMAGE-IR-CELLS"
     :image-blob "RESIDENT-ASM-IMAGE-IR-BLOB"
     :image-layout "RESIDENT-ASM-IMAGE-IR-LAYOUT"
     :output-field-layout "*STAGE1-OUTPUT-FIELD-LAYOUT*")
    :artifact-kinds
    '(:compiler-form-ast
      :compile-action
      :asm-prog
      :asm-layout-ir
      :resident-asm-image-ir
      :compiler-step
      :installed-generation-ir
      :encoded-bytes)
    :note "Generic compiler-family adapter for the MIR Stage1 compiler tranche chain."
    :metadata
    (list :roundtrip-fields
          '(:next-quote :next-symbol :next-form :next-entry :emitted-family :emit-again)
          :roundtrip-accessors
          '(:next-quote :action-next-quote
            :next-symbol :action-next-symbol
            :next-form :action-next-form
            :next-entry :action-next-entry
            :emitted-family :action-emitted-family
            :emit-again :action-emit-again)
          :determinism-entrypoints
          (list
           (list :artifact :compile-action
                 :entrypoint :interpret-source
                 :inputs '(:source-id :control-id))
           (list :artifact :asm-prog
                 :entrypoint :lower-source-to-asm-prog
                 :inputs '(:source-id :control-id))
           (list :artifact :compiler-step
                 :entrypoint :assemble-step
                 :inputs '(:source-id :control-id)))
          :lowering-edges
          (list
           (list :artifact :compile-action
                 :entrypoint :interpret-source
                 :inputs '(:source-id :control-id))
           (list :artifact :asm-prog
                 :entrypoint :lower-source-to-asm-prog
                 :inputs '(:source-id :control-id))
           (list :artifact :compiler-step
                 :entrypoint :assemble-step
                 :inputs '(:source-id :control-id))
           (list :artifact :fragment-ir
                 :entrypoint :step-fragment
                 :inputs '(:compiler-step))
           (list :artifact :resident-image
                 :entrypoint :fragment-image
                 :inputs '(:fragment-ir)))
          :installed-generation-relations
          (list
           (list :field :root-source
                 :installed-accessor :installed-root-source
                 :expected-from :source-id)
           (list :field :root-entry
                 :installed-accessor :installed-root-entry
                 :expected-from :compile-action
                 :expected-accessor :action-next-entry)
           (list :field :root-family
                 :installed-accessor :installed-root-family
                 :expected-from :compile-action
                 :expected-accessor :action-emitted-family)
           (list :field :target-source
                 :installed-accessor :installed-target-source
                 :expected-from :compile-action
                 :expected-accessor :action-next-form)
           (list :field :successor-source
                 :installed-accessor :installed-successor-source
                 :expected-from :compile-action
                 :expected-accessor :action-next-form)
           (list :field :direction
                 :installed-accessor :installed-direction
                 :expected-from :compile-action
                 :expected-accessor :action-direction)
           (list :field :target-role
                 :installed-accessor :installed-target-role
                 :expected-from :compile-action
                 :expected-accessor :action-target-role)
           (list :field :emit-again
                 :installed-accessor :installed-emit-again
                 :expected-from :compile-action
                 :expected-accessor :action-emit-again)
           (list :field :terminate-p
                 :installed-accessor :installed-terminate-p
                 :expected-from :compile-action
                 :expected-accessor :action-terminate-p)
           (list :field :authority
                 :installed-accessor :installed-authority
                 :expected-from :compile-action
                 :expected-accessor :action-authority)
           (list :field :lineage-role
                 :installed-accessor :installed-lineage-role
                 :expected-from :compile-action
                 :expected-accessor :action-lineage-role))
          :trace-default-limit 3
          :trace-direction :forward
          :artifact-types
          '(:compile-action "COMPILE-ACTION"
            :asm-prog "ASM-PROG"
            :asm-layout-ir "ASM-LAYOUT-IR"
            :compiler-step "COMPILER-STEP"
            :fragment-ir "EMITTED-FRAGMENT-IR"
            :resident-image "RESIDENT-ASM-IMAGE-IR"
            :installed-generation-ir "INSTALLED-GENERATION-IR")
          :value-keys '(:output-field-layout)
          :field-step 2))))

(defparameter *runtime-constitution-registry* (make-hash-table :test #'equal))

(defun %runtime-name-string (value)
  (etypecase value
    (string value)
    (symbol (string-downcase (symbol-name value)))))

(defun %runtime-callable-row< (lhs rhs)
  (string< (runtime-callable-row-name lhs)
           (runtime-callable-row-name rhs)))

(defun %sort-runtime-callable-rows (rows)
  (sort rows #'%runtime-callable-row<))

(defun runtime-capability-class-callable-rows-sorted (capability)
  (%sort-runtime-callable-rows
   (copy-list (runtime-capability-class-callable-rows capability))))

(defun runtime-capability-class-json-object (capability)
  (list
   (cons "id" (%runtime-name-string (runtime-capability-class-id capability)))
   (cons "lane" (%runtime-name-string (runtime-capability-class-lane capability)))
   (cons "authority_kind"
         (%runtime-name-string (runtime-capability-class-authority-kind capability)))
   (cons "callable_rows"
         (mapcar (lambda (row)
                   (list
                    (cons "name" (runtime-callable-row-name row))
                    (cons "callable" (%runtime-name-string (runtime-callable-row-callable row)))
                    (cons "kind" (%runtime-name-string (runtime-callable-row-kind row)))
                    (cons "lane" (%runtime-name-string (runtime-callable-row-lane row)))
                    (cons "ref_id"
                          (and (runtime-callable-row-ref-id row)
                               (%runtime-name-string (runtime-callable-row-ref-id row))))
                    (cons "argument_keys"
                          (mapcar #'%runtime-name-string
                                  (runtime-callable-row-argument-keys row)))
                    (cons "input_schema" (runtime-callable-row-input-schema row))
                    (cons "output_schema" (runtime-callable-row-output-schema row))
                    (cons "effect_kind"
                          (%runtime-name-string (runtime-callable-row-effect-kind row)))
                    (cons "evidence_kind"
                          (%runtime-name-string (runtime-callable-row-evidence-kind row)))
                    (cons "note" (runtime-callable-row-note row))))
                 (runtime-capability-class-callable-rows-sorted capability)))
   (cons "semantic_contract" (runtime-capability-class-semantic-contract capability))
   (cons "meta" (runtime-capability-class-meta capability))))

(defun search-kernel-obligation-kind-object (entry)
  (let ((kind (if (typep entry 'search-kernel-obligation-kind)
                  entry
                  (find entry *search-kernel-obligation-kinds*
                        :key #'search-kernel-obligation-kind-id
                        :test #'eq))))
    (unless kind
      (error "Unknown search obligation kind ~S." entry))
    (list
     (cons "id" (%runtime-name-string (search-kernel-obligation-kind-id kind)))
     (cons "severity"
           (%runtime-name-string (search-kernel-obligation-kind-severity kind)))
     (cons "projection_operation"
           (%runtime-name-string
            (search-kernel-obligation-kind-projection-operation kind)))
     (cons "payload_schema" (search-kernel-obligation-kind-payload-schema kind))
     (cons "freshness_law"
           (%runtime-name-string
            (search-kernel-obligation-kind-freshness-law kind)))
     (cons "note" (search-kernel-obligation-kind-note kind)))))

(defun list-search-kernel-obligation-kinds ()
  (mapcar #'search-kernel-obligation-kind-object
          *search-kernel-obligation-kinds*))

(defun find-search-kernel-obligation-kind (id)
  (find id *search-kernel-obligation-kinds*
        :key #'search-kernel-obligation-kind-id
        :test #'eq))

(defun search-admission-law-object (entry)
  (let ((law (if (typep entry 'search-admission-law)
                 entry
                 (find entry *search-admission-laws*
                       :key #'search-admission-law-id
                       :test #'eq))))
    (unless law
      (error "Unknown search admission law ~S." entry))
    (list
     (cons "id" (%runtime-name-string (search-admission-law-id law)))
     (cons "hard_obligation_kinds"
           (mapcar #'%runtime-name-string
                   (search-admission-law-hard-obligation-kinds law)))
     (cons "advisory_obligation_kinds"
           (mapcar #'%runtime-name-string
                   (search-admission-law-advisory-obligation-kinds law)))
     (cons "stale_threshold" (search-admission-law-stale-threshold law))
     (cons "reject_on_fail_p" (search-admission-law-reject-on-fail-p law))
     (cons "kernel_requirements"
           (mapcar #'%runtime-name-string
                   (search-admission-law-kernel-requirements law)))
     (cons "note" (search-admission-law-note law)))))

(defun list-search-admission-laws ()
  (mapcar #'search-admission-law-object *search-admission-laws*))

(defun find-search-admission-law (id)
  (find id *search-admission-laws*
        :key #'search-admission-law-id
        :test #'eq))

(defun search-evidence-status-object (entry)
  (let ((status (if (typep entry 'search-evidence-status)
                    entry
                    (find entry *search-evidence-statuses*
                          :key #'search-evidence-status-id
                          :test #'eq))))
    (unless status
      (error "Unknown search evidence status ~S." entry))
    (list
     (cons "id" (%runtime-name-string (search-evidence-status-id status)))
     (cons "terminal_p" (search-evidence-status-terminalp status))
     (cons "freshness_class"
           (%runtime-name-string (search-evidence-status-freshness-class status)))
     (cons "polarity"
           (%runtime-name-string (search-evidence-status-polarity status)))
     (cons "note" (search-evidence-status-note status)))))

(defun list-search-evidence-statuses ()
  (mapcar #'search-evidence-status-object *search-evidence-statuses*))

(defun find-search-evidence-status (id)
  (find id *search-evidence-statuses*
        :key #'search-evidence-status-id
        :test #'eq))

(defun build-search-evidence-state-from-update (update)
  (unless (typep update 'search-evidence-update)
    (error "Expected search-evidence-update, got ~S." update))
  (or (getf (search-evidence-update-metadata update) :evidence-state)
      (make-search-evidence-state
       :state-id (search-evidence-update-state-id update)
       :obligation-statuses (copy-list (search-evidence-update-obligation-statuses update))
       :live-evidence-ids (copy-list (search-evidence-update-live-evidence-ids update))
       :supersession-links (copy-list (search-evidence-update-supersession-links update))
       :hard-debt (search-evidence-update-hard-debt update)
       :advisory-debt (search-evidence-update-advisory-debt update)
       :coverage-summary (copy-list (search-evidence-update-coverage-summary update))
       :freshness-summary (copy-list (search-evidence-update-freshness-summary update))
       :status (search-evidence-update-status update)
       :metadata (copy-list (search-evidence-update-metadata update)))))

(defun evaluate-search-evidence-frontier (state)
  (let* ((evidence-state
           (or (and (typep state 'search-evidence-state) state)
               (and (typep state 'search-evidence-update)
                    (build-search-evidence-state-from-update state))
               (error "Expected search-evidence-state or search-evidence-update, got ~S."
                      state)))
         (index (copy-list (or (getf (search-evidence-state-metadata evidence-state)
                                     :evidence-entry-index)
                               '())))
         (live-frontier '())
         (superseded '()))
    (dolist (evidence-id (search-evidence-state-live-evidence-ids evidence-state))
      (let ((entry (%search-evidence-entry-from-index index evidence-id)))
        (when entry
          (push (list :obligation-id (search-formal-evidence-obligation-id entry)
                      :obligation-kind (search-formal-evidence-obligation-kind entry)
                      :evidence-id evidence-id
                      :status (%search-evidence-status-from-evidence entry))
                live-frontier))))
    (dolist (link (search-evidence-state-supersession-links evidence-state))
      (pushnew (getf link :prior-evidence-id) superseded :test #'equal))
    (make-search-evidence-frontier
     :state-id (search-evidence-state-state-id evidence-state)
     :live-frontier (nreverse live-frontier)
     :superseded-evidence-ids (nreverse superseded)
     :diagnostics
     (list :live-count (length live-frontier)
           :superseded-count (length superseded)
           :state-status (search-evidence-state-status evidence-state)))))

(defun search-legality-clause-object (entry)
  (let ((clause (if (typep entry 'search-legality-clause)
                    entry
                    (find entry *search-legality-clauses*
                          :key #'search-legality-clause-id
                          :test #'eq))))
    (unless clause
      (error "Unknown search legality clause ~S." entry))
    (list
     (cons "id" (%runtime-name-string (search-legality-clause-id clause)))
     (cons "severity" (%runtime-name-string (search-legality-clause-severity clause)))
     (cons "note" (search-legality-clause-note clause)))))

(defun list-search-legality-clauses ()
  (mapcar #'search-legality-clause-object *search-legality-clauses*))

(defun find-search-legality-clause (id)
  (find id *search-legality-clauses*
        :key #'search-legality-clause-id
        :test #'eq))

(defun search-operator-class-object (entry)
  (let ((operator-class
          (if (typep entry 'search-operator-class)
              entry
              (find entry *search-operator-classes*
                    :key #'search-operator-class-id
                    :test #'eq))))
    (unless operator-class
      (error "Unknown search operator class ~S." entry))
    (list
     (cons "id" (%runtime-name-string (search-operator-class-id operator-class)))
     (cons "subject_kinds"
           (mapcar #'%runtime-name-string
                   (search-operator-class-subject-kinds operator-class)))
     (cons "mandatory_obligation_kinds"
           (mapcar #'%runtime-name-string
                   (search-operator-class-mandatory-obligation-kinds operator-class)))
     (cons "kernel_requirements"
           (mapcar #'%runtime-name-string
                   (search-operator-class-kernel-requirements operator-class)))
     (cons "replay_required_p"
           (search-operator-class-replay-required-p operator-class))
     (cons "note" (search-operator-class-note operator-class)))))

(defun list-search-operator-classes ()
  (mapcar #'search-operator-class-object *search-operator-classes*))

(defun find-search-operator-class (id)
  (find id *search-operator-classes*
        :key #'search-operator-class-id
        :test #'eq))

(defun find-compiler-family (id)
  (find id *compiler-families*
        :key #'compiler-family-id
        :test #'eq))

(defun %compiler-family-package-string (family)
  (let ((value (compiler-family-package-name family)))
    (etypecase value
      (package (string-downcase (package-name value)))
      (symbol (string-downcase (symbol-name value)))
      (string value))))

(defun %compiler-family-entrypoint-keys (family)
  (loop for (key value) on (compiler-family-entrypoints family) by #'cddr
        collect key))

(defun compiler-family-object (entry)
  (let ((family (if (typep entry 'compiler-family)
                    entry
                    (or (find-compiler-family entry)
                        (error "Unknown compiler family ~S." entry)))))
    (list
     (cons "id" (%runtime-name-string (compiler-family-id family)))
     (cons "package_name" (%compiler-family-package-string family))
     (cons "source_path" (compiler-family-source-path family))
     (cons "dependency_paths" (copy-list (compiler-family-dependency-paths family)))
     (cons "entrypoint_keys"
           (mapcar #'%runtime-name-string
                   (%compiler-family-entrypoint-keys family)))
     (cons "artifact_kinds"
           (mapcar #'%runtime-name-string
                   (compiler-family-artifact-kinds family)))
     (cons "roundtrip_fields"
           (mapcar #'%runtime-name-string
                   (copy-list (or (getf (compiler-family-metadata family)
                                        :roundtrip-fields)
                                  '()))))
     (cons "determinism_artifacts"
           (mapcar (lambda (row)
                     (list
                      (cons "artifact"
                            (%runtime-name-string (getf row :artifact)))
                      (cons "entrypoint"
                            (%runtime-name-string (getf row :entrypoint)))
                      (cons "inputs"
                            (mapcar #'%runtime-name-string
                                    (copy-list (or (getf row :inputs)
                                                   '()))))))
                   (copy-tree (or (getf (compiler-family-metadata family)
                                        :determinism-entrypoints)
                                  '()))))
     (cons "lowering_edges"
           (mapcar (lambda (row)
                     (list
                      (cons "artifact"
                            (%runtime-name-string (getf row :artifact)))
                      (cons "entrypoint"
                            (%runtime-name-string (getf row :entrypoint)))
                      (cons "inputs"
                            (mapcar #'%runtime-name-string
                                    (copy-list (or (getf row :inputs)
                                                   '()))))))
                   (copy-tree (or (getf (compiler-family-metadata family)
                                        :lowering-edges)
                                  '()))))
     (cons "installed_generation_fields"
           (mapcar (lambda (row)
                     (list
                      (cons "field"
                            (%runtime-name-string (getf row :field)))
                      (cons "installed_accessor"
                            (%runtime-name-string (getf row :installed-accessor)))
                      (cons "expected_from"
                            (%runtime-name-string (getf row :expected-from)))
                      (cons "expected_accessor"
                            (and (getf row :expected-accessor)
                                 (%runtime-name-string (getf row :expected-accessor))))))
                   (copy-tree (or (getf (compiler-family-metadata family)
                                        :installed-generation-relations)
                                  '()))))
     (cons "trace_default_limit"
           (%compiler-family-metadata-value family :trace-default-limit))
     (cons "note" (compiler-family-note family)))))

(defun list-compiler-families ()
  (mapcar #'compiler-family-object *compiler-families*))

(defun describe-compiler-family (family)
  (compiler-family-object family))

(defun find-compiler-obligation-kind (id)
  (find id *compiler-obligation-kinds*
        :key #'compiler-obligation-kind-id
        :test #'eq))

(defun compiler-obligation-kind-object (entry)
  (let ((kind (if (typep entry 'compiler-obligation-kind)
                  entry
                  (or (find-compiler-obligation-kind entry)
                      (error "Unknown compiler obligation kind ~S." entry)))))
    (list
     (cons "id" (%runtime-name-string (compiler-obligation-kind-id kind)))
     (cons "severity" (%runtime-name-string (compiler-obligation-kind-severity kind)))
     (cons "check_operation"
           (%runtime-name-string (compiler-obligation-kind-check-operation kind)))
     (cons "required_artifacts"
           (mapcar #'%runtime-name-string
                   (compiler-obligation-kind-required-artifacts kind)))
     (cons "note" (compiler-obligation-kind-note kind)))))

(defun list-compiler-obligation-kinds ()
  (mapcar #'compiler-obligation-kind-object *compiler-obligation-kinds*))

(defun %resolve-compiler-family (family)
  (or (and (typep family 'compiler-family) family)
      (find-compiler-family family)
      (error "Unknown compiler family ~S." family)))

(defun %ensure-compiler-family-loaded (family)
  (let* ((family* (%resolve-compiler-family family))
         (package-designator (compiler-family-package-name family*))
         (package (find-package package-designator)))
    (unless (probe-file (compiler-family-source-path family*))
      (error "Missing compiler family source ~A." (compiler-family-source-path family*)))
    (dolist (path (compiler-family-dependency-paths family*))
      (unless (probe-file path)
        (error "Missing compiler family dependency ~A." path)))
    (unless package
      (load (compiler-family-source-path family*))
      (setf package (find-package package-designator)))
    (unless package
      (error "Unable to load compiler family package ~S." package-designator))
    package))

(defun %compiler-family-symbol (family key &key functionp boundp)
  (let* ((family* (%resolve-compiler-family family))
         (package (%ensure-compiler-family-loaded family*))
         (name (getf (compiler-family-entrypoints family*) key)))
    (unless name
      (error "Compiler family ~S is missing entrypoint ~S."
             (compiler-family-id family*)
             key))
    (multiple-value-bind (symbol status)
        (find-symbol name package)
      (declare (ignore status))
      (unless symbol
        (error "Missing compiler family symbol ~A in package ~A."
               name
               (package-name package)))
      (when functionp
        (unless (fboundp symbol)
          (error "Compiler family symbol ~A is not fbound." name)))
      (when boundp
        (unless (boundp symbol)
          (error "Compiler family symbol ~A is not bound." name)))
      symbol)))

(defun %compiler-family-call (family key &rest args)
  (apply (symbol-function (%compiler-family-symbol family key :functionp t))
         args))

(defun %compiler-family-value (family key)
  (symbol-value (%compiler-family-symbol family key :boundp t)))

(defun %compiler-roundtrip-fields (family)
  (copy-list (or (getf (compiler-family-metadata family)
                       :roundtrip-fields)
                 '())))

(defun %compiler-family-metadata-value (family key &optional default)
  (loop for (candidate-key candidate-value) on (compiler-family-metadata family) by #'cddr
        when (eq candidate-key key)
          do (return candidate-value)
        finally (return default)))

(defun %compiler-determinism-rows (family)
  (copy-tree (%compiler-family-metadata-value family :determinism-entrypoints '())))

(defun %compiler-lowering-edges (family)
  (copy-tree (%compiler-family-metadata-value family :lowering-edges '())))

(defun %compiler-installed-generation-relations (family)
  (copy-tree (%compiler-family-metadata-value family
                                              :installed-generation-relations
                                              '())))

(defun %compiler-family-artifact-type-spec (family artifact)
  (getf (%compiler-family-metadata-value family :artifact-types '())
        artifact))

(defun %compiler-family-type-symbol (family name)
  (etypecase name
    (symbol name)
    (string
     (let ((package (%ensure-compiler-family-loaded family)))
       (multiple-value-bind (symbol status)
           (find-symbol name package)
         (declare (ignore status))
         (unless symbol
           (error "Missing compiler family type ~A in package ~A."
                  name
                  (package-name package)))
         symbol)))))

(defun %compiler-expected-type-names (family artifact)
  (let ((spec (%compiler-family-artifact-type-spec family artifact)))
    (cond
      ((null spec) '())
      ((listp spec)
       (mapcar (lambda (entry)
                 (if (symbolp entry)
                     (%runtime-name-string entry)
                     (string-downcase (princ-to-string entry))))
               spec))
      ((symbolp spec) (list (%runtime-name-string spec)))
      (t (list (string-downcase (princ-to-string spec)))))))

(defun %compiler-expected-type-symbols (family artifact)
  (let ((spec (%compiler-family-artifact-type-spec family artifact)))
    (cond
      ((null spec) '())
      ((listp spec)
       (mapcar (lambda (entry)
                 (%compiler-family-type-symbol family entry))
               spec))
      (t (list (%compiler-family-type-symbol family spec))))))

(defun %compiler-artifact-type-ok-p (family artifact object)
  (let ((expected-types (%compiler-expected-type-symbols family artifact)))
    (or (null expected-types)
        (some (lambda (type-symbol)
                (typep object type-symbol))
              expected-types))))

(defun %compiler-normalize-artifact (object)
  (with-standard-io-syntax
    (let ((*print-array* t)
          (*print-circle* t)
          (*print-length* nil)
          (*print-level* nil)
          (*print-pretty* nil)
          (*print-readably* nil))
      (write-to-string object))))

(defun %compiler-signature-from-normalized (object normalized)
  (list :type (%compiler-type-string object)
        :hash (sxhash normalized)
        :length (length normalized)))

(defun %compiler-artifact-signature (object)
  (let ((normalized (%compiler-normalize-artifact object)))
    (%compiler-signature-from-normalized object normalized)))

(defun %compiler-resolve-row-inputs (context inputs)
  (let ((sentinel (list :missing))
        (values '())
        (missing '()))
    (dolist (input inputs)
      (let ((value (getf context input sentinel)))
        (if (eq value sentinel)
            (push input missing)
            (push value values))))
    (values (nreverse values)
            (nreverse missing))))

(defun %compiler-context-value (context key)
  (let ((sentinel (list :missing)))
    (let ((value (getf context key sentinel)))
      (if (eq value sentinel)
          (values nil nil)
          (values value t)))))

(defun %compiler-roundtrip-accessor-key (family field)
  (or (getf (getf (compiler-family-metadata family) :roundtrip-accessors) field)
      (error "Compiler family ~S is missing roundtrip accessor for ~S."
             (compiler-family-id family)
             field)))

(defun %compiler-family-entrypoint-present-p (family key)
  (not (null (getf (compiler-family-entrypoints family) key))))

(defun %compiler-relation-value (family context source-key accessor-key)
  (multiple-value-bind (source-value presentp)
      (%compiler-context-value context source-key)
    (cond
      ((not presentp) (values nil nil))
      ((null accessor-key) (values source-value t))
      ((null source-value) (values nil t))
      (t (values (%compiler-family-call family accessor-key source-value) t)))))

(defun %compiler-sample-source-id (family &optional source-id)
  (or source-id
      (let* ((asts (%compiler-family-call family :live-compiler-asts))
             (first-ast (first asts)))
        (unless first-ast
          (error "Compiler family ~S has no live compiler ASTs."
                 (compiler-family-id family)))
        (%compiler-family-call family :ast-source-id first-ast))))

(defun %compiler-check-result
    (family obligation-kind source-id control-id status diagnostics
     &optional metadata)
  (make-compiler-check-result
   :family-id (compiler-family-id family)
   :obligation-kind obligation-kind
   :source-id source-id
   :control-id control-id
   :status status
   :diagnostics diagnostics
   :metadata metadata))

(defun %compiler-check-error-result
    (family obligation-kind source-id control-id condition)
  (%compiler-check-result
   family
   obligation-kind
   source-id
   control-id
   :error
   (list :condition (princ-to-string condition))
   (list :error-type (%runtime-name-string (type-of condition)))))

(defun %compiler-type-string (object)
  (let ((type (type-of object)))
    (if (symbolp type)
        (%runtime-name-string type)
        (string-downcase (princ-to-string type)))))

(defun %compiler-layout-label-pc (label-pcs label)
  (let ((entry (or (assoc label label-pcs :test #'equal)
                   (and (symbolp label)
                        (assoc (string-downcase (symbol-name label))
                               label-pcs
                               :test #'equal))
                   (and (stringp label)
                        (assoc (intern (string-upcase label) :keyword)
                               label-pcs
                               :test #'equal)))))
    (and entry (cdr entry))))

(defun check-compiler-schema (family &optional source-id control-id)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id)))))
    (handler-case
        (let* ((package (%ensure-compiler-family-loaded family*))
               (value-keys (copy-list (or (getf (compiler-family-metadata family*)
                                                :value-keys)
                                          '())))
               (function-keys
                 (set-difference (%compiler-family-entrypoint-keys family*)
                                 value-keys
                                 :test #'eq))
               (field-layout (%compiler-family-value family* :output-field-layout))
               (field-layout-list (if (listp field-layout) field-layout '()))
               (field-step (or (getf (compiler-family-metadata family*) :field-step) 1))
               (roundtrip-fields (%compiler-roundtrip-fields family*))
               (action (%compiler-family-call family* :interpret-source sid control-id))
               (asm-prog (%compiler-family-call family* :lower-source-to-asm-prog sid control-id))
               (step (%compiler-family-call family* :assemble-step sid control-id))
               (image (%compiler-family-call family* :fragment-image
                                            (%compiler-family-call family* :step-fragment step)))
               (bytes (%compiler-family-call family* :encode-source-to-bytes sid control-id))
               (violations '()))
          (dolist (key function-keys)
            (%compiler-family-symbol family* key :functionp t))
          (dolist (key value-keys)
            (%compiler-family-symbol family* key :boundp t))
          (unless (listp field-layout)
            (push (list :kind :field-layout-not-list
                        :value field-layout)
                  violations))
          (let ((layout-fields (mapcar #'car field-layout-list))
                (layout-offsets (mapcar #'cdr field-layout-list)))
            (unless (equal layout-fields roundtrip-fields)
              (push (list :kind :field-layout-keys
                          :expected roundtrip-fields
                          :actual layout-fields)
                    violations))
            (unless (equal layout-offsets
                           (loop for _ in roundtrip-fields
                                 for offset from 0 by field-step
                                 collect offset))
              (push (list :kind :field-layout-offsets
                          :expected (loop for _ in roundtrip-fields
                                          for offset from 0 by field-step
                                          collect offset)
                          :actual layout-offsets)
                    violations)))
          (dolist (artifact (list (cons :action action)
                                  (cons :asm-prog asm-prog)
                                  (cons :compiler-step step)
                                  (cons :resident-image image)
                                  (cons :encoded-bytes bytes)))
            (unless (cdr artifact)
              (push (list :kind :missing-artifact
                          :artifact (car artifact))
                    violations))
            (when (and (cdr artifact)
                       (not (%compiler-artifact-type-ok-p family*
                                                          (car artifact)
                                                          (cdr artifact))))
              (push (list :kind :unexpected-artifact-type
                          :artifact (car artifact)
                          :expected (%compiler-expected-type-names family*
                                                                   (car artifact))
                          :actual (%compiler-type-string (cdr artifact)))
                    violations)))
          (%compiler-check-result
           family*
           :compiler-schema-well-formed
           sid
           control-id
           (if violations :failed :passed)
           (list :package (package-name package)
                 :field-layout (copy-list field-layout-list)
                 :artifact-types
                 (list :action (%compiler-type-string action)
                       :asm-prog (%compiler-type-string asm-prog)
                       :compiler-step (%compiler-type-string step)
                       :resident-image (%compiler-type-string image)
                       :encoded-bytes (%compiler-type-string bytes))
                 :violations (nreverse violations))
           (list :artifact-kinds (copy-list (compiler-family-artifact-kinds family*)))))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-schema-well-formed
         sid
         control-id
         condition)))))

(defun check-compiler-control-determinism (family &optional source-id control-id)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id)))))
    (handler-case
        (let* ((rows (%compiler-determinism-rows family*))
               (context (list :source-id sid :control-id control-id))
               (checks '())
               (violations '()))
          (unless rows
            (error "Compiler family ~S has no determinism entrypoints."
                   (compiler-family-id family*)))
          (dolist (row rows)
            (let* ((artifact (or (getf row :artifact)
                                 (error "Compiler family ~S determinism row is missing :artifact."
                                        (compiler-family-id family*))))
                   (entrypoint (or (getf row :entrypoint)
                                   (error "Compiler family ~S determinism row is missing :entrypoint."
                                          (compiler-family-id family*))))
                   (inputs (copy-list (or (getf row :inputs) '()))))
              (multiple-value-bind (args missing-inputs)
                  (%compiler-resolve-row-inputs context inputs)
                (if missing-inputs
                    (push (list :kind :missing-inputs
                                :artifact artifact
                                :entrypoint entrypoint
                                :inputs missing-inputs)
                          violations)
                    (let* ((lhs (apply #'%compiler-family-call family* entrypoint args))
                           (rhs (apply #'%compiler-family-call family* entrypoint args))
                           (lhs-normalized (%compiler-normalize-artifact lhs))
                           (rhs-normalized (%compiler-normalize-artifact rhs))
                           (lhs-signature (%compiler-signature-from-normalized lhs lhs-normalized))
                           (rhs-signature (%compiler-signature-from-normalized rhs rhs-normalized))
                           (lhs-type-ok (%compiler-artifact-type-ok-p family* artifact lhs))
                           (rhs-type-ok (%compiler-artifact-type-ok-p family* artifact rhs))
                           (stablep (string= lhs-normalized rhs-normalized)))
                      (unless lhs-type-ok
                        (push (list :kind :unexpected-artifact-type
                                    :artifact artifact
                                    :which :first
                                    :expected (%compiler-expected-type-names family* artifact)
                                    :actual (%compiler-type-string lhs))
                              violations))
                      (unless rhs-type-ok
                        (push (list :kind :unexpected-artifact-type
                                    :artifact artifact
                                    :which :second
                                    :expected (%compiler-expected-type-names family* artifact)
                                    :actual (%compiler-type-string rhs))
                              violations))
                      (unless stablep
                        (push (list :kind :nondeterministic-artifact
                                    :artifact artifact
                                    :entrypoint entrypoint
                                    :first lhs-signature
                                    :second rhs-signature)
                              violations))
                      (push (list :artifact artifact
                                  :entrypoint entrypoint
                                  :inputs inputs
                                  :stablep stablep
                                  :first lhs-signature
                                  :second rhs-signature)
                            checks))))))
          (%compiler-check-result
           family*
           :compiler-control-determinism
           sid
           control-id
           (if violations :failed :passed)
           (list :checks (nreverse checks)
                 :violations (nreverse violations))
           (list :entry-count (length rows))))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-control-determinism
         sid
         control-id
         condition)))))

(defun check-compiler-lowering-totality (family &optional source-id control-id)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id)))))
    (handler-case
        (let* ((edges (%compiler-lowering-edges family*))
               (context (list :source-id sid :control-id control-id))
               (checks '())
               (violations '()))
          (unless edges
            (error "Compiler family ~S has no lowering edges."
                   (compiler-family-id family*)))
          (dolist (edge edges)
            (let* ((artifact (or (getf edge :artifact)
                                 (error "Compiler family ~S lowering edge is missing :artifact."
                                        (compiler-family-id family*))))
                   (entrypoint (or (getf edge :entrypoint)
                                   (error "Compiler family ~S lowering edge is missing :entrypoint."
                                          (compiler-family-id family*))))
                   (inputs (copy-list (or (getf edge :inputs) '()))))
              (multiple-value-bind (args missing-inputs)
                  (%compiler-resolve-row-inputs context inputs)
                (if missing-inputs
                    (progn
                      (push (list :kind :missing-inputs
                                  :artifact artifact
                                  :entrypoint entrypoint
                                  :inputs missing-inputs)
                            violations)
                      (push (list :artifact artifact
                                  :entrypoint entrypoint
                                  :inputs inputs
                                  :status :blocked
                                  :missing-inputs missing-inputs)
                            checks))
                    (let* ((value (apply #'%compiler-family-call family* entrypoint args))
                           (presentp (not (null value)))
                           (type-ok (and presentp
                                         (%compiler-artifact-type-ok-p family*
                                                                       artifact
                                                                       value))))
                      (when presentp
                        (setf (getf context artifact) value))
                      (unless presentp
                        (push (list :kind :missing-artifact
                                    :artifact artifact
                                    :entrypoint entrypoint)
                              violations))
                      (when (and presentp (not type-ok))
                        (push (list :kind :unexpected-artifact-type
                                    :artifact artifact
                                    :entrypoint entrypoint
                                    :expected (%compiler-expected-type-names family* artifact)
                                    :actual (%compiler-type-string value))
                              violations))
                      (push (list :artifact artifact
                                  :entrypoint entrypoint
                                  :inputs inputs
                                  :status (cond
                                            ((not presentp) :missing)
                                            (type-ok :realized)
                                            (t :wrong-type))
                                  :artifact-type (and presentp
                                                      (%compiler-type-string value))
                                  :signature (and presentp
                                                  (%compiler-artifact-signature value)))
                            checks))))))
          (%compiler-check-result
           family*
           :compiler-lowering-totality
           sid
           control-id
           (if violations :failed :passed)
           (list :checks (nreverse checks)
                 :violations (nreverse violations))
           (list :edge-count (length edges))))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-lowering-totality
         sid
         control-id
         condition)))))

(defun check-compiler-installed-generation (family &optional source-id control-id)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id)))))
    (handler-case
        (let* ((relations (%compiler-installed-generation-relations family*))
               (action (%compiler-family-call family* :interpret-source sid control-id))
               (step (%compiler-family-call family* :assemble-step sid control-id))
               (install (%compiler-family-call family* :step-installed-generation step))
               (context (list :source-id sid
                              :control-id control-id
                              :compile-action action
                              :compiler-step step
                              :installed-generation-ir install))
               (checks '())
               (violations '()))
          (unless relations
            (error "Compiler family ~S has no installed-generation relations."
                   (compiler-family-id family*)))
          (unless (%compiler-artifact-type-ok-p family* :compiler-step step)
            (push (list :kind :unexpected-artifact-type
                        :artifact :compiler-step
                        :expected (%compiler-expected-type-names family* :compiler-step)
                        :actual (%compiler-type-string step))
                  violations))
          (unless (%compiler-artifact-type-ok-p family* :installed-generation-ir install)
            (push (list :kind :unexpected-artifact-type
                        :artifact :installed-generation-ir
                        :expected (%compiler-expected-type-names family* :installed-generation-ir)
                        :actual (%compiler-type-string install))
                  violations))
          (dolist (relation relations)
            (multiple-value-bind (actual actual-presentp)
                (%compiler-relation-value family*
                                          context
                                          :installed-generation-ir
                                          (getf relation :installed-accessor))
              (multiple-value-bind (expected expected-presentp)
                  (%compiler-relation-value family*
                                            context
                                            (getf relation :expected-from)
                                            (getf relation :expected-accessor))
                (cond
                  ((not actual-presentp)
                   (push (list :kind :missing-source
                               :field (getf relation :field)
                               :source :installed-generation-ir)
                         violations))
                  ((not expected-presentp)
                   (push (list :kind :missing-source
                               :field (getf relation :field)
                               :source (getf relation :expected-from))
                         violations))
                  ((not (equal actual expected))
                   (push (list :kind :field-mismatch
                               :field (getf relation :field)
                               :actual actual
                               :expected expected)
                         violations)))
                (push (list :field (getf relation :field)
                            :actual actual
                            :expected expected
                            :matchp (and actual-presentp
                                         expected-presentp
                                         (equal actual expected)))
                      checks))))
          (%compiler-check-result
           family*
           :compiler-installed-generation-soundness
           sid
           control-id
           (if violations :failed :passed)
           (list :checks (nreverse checks)
                 :violations (nreverse violations))
           (list :relation-count (length relations))))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-installed-generation-soundness
         sid
         control-id
         condition)))))

(defun check-compiler-trace-parity (family &optional source-id control-id limit)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id))))
         (trace-limit (or limit
                          (%compiler-family-metadata-value family*
                                                           :trace-default-limit
                                                           3))))
    (handler-case
        (let* ((trace (%compiler-family-call family* :live-ir-chain sid control-id trace-limit))
               (direction (or (%compiler-family-metadata-value family*
                                                               :trace-direction
                                                               :forward)
                              :forward))
               (alternate-trace
                 (when (%compiler-family-entrypoint-present-p family*
                                                             :live-ir-chain-directed)
                   (%compiler-family-call family*
                                          :live-ir-chain-directed
                                          direction
                                          sid
                                          control-id
                                          trace-limit)))
               (checks '())
               (violations '())
               (expected-source sid)
               (previous-install nil))
          (unless (listp trace)
            (push (list :kind :trace-not-list
                        :value trace)
                  violations))
          (when (null trace)
            (push (list :kind :empty-trace
                        :limit trace-limit)
                  violations))
          (when (and alternate-trace
                     (not (string=
                           (%compiler-normalize-artifact trace)
                           (%compiler-normalize-artifact alternate-trace))))
            (push (list :kind :alternate-trace-mismatch
                        :direction direction
                        :primary-signature (%compiler-artifact-signature trace)
                        :alternate-signature (%compiler-artifact-signature alternate-trace))
                  violations))
          (when (listp trace)
            (loop for step in trace
                  for index from 0
                  do (let* ((step-type-ok (%compiler-artifact-type-ok-p family*
                                                                       :compiler-step
                                                                       step))
                            (step-source (and step-type-ok
                                              (%compiler-family-call family*
                                                                     :step-source-id
                                                                     step)))
                            (step-asm (and step-type-ok
                                           (%compiler-family-call family*
                                                                  :step-asm-prog
                                                                  step)))
                            (step-bytes (and step-type-ok
                                             (%compiler-family-call family*
                                                                    :step-bytes
                                                                    step)))
                            (install (and step-type-ok
                                          (%compiler-family-call family*
                                                                 :step-installed-generation
                                                                 step)))
                            (install-type-ok (and install
                                                  (%compiler-artifact-type-ok-p family*
                                                                                :installed-generation-ir
                                                                                install)))
                            (install-root (and install-type-ok
                                               (%compiler-family-call family*
                                                                      :installed-root-source
                                                                      install)))
                            (install-target (and install-type-ok
                                                 (%compiler-family-call family*
                                                                        :installed-target-source
                                                                        install)))
                            (install-successor (and install-type-ok
                                                    (%compiler-family-call family*
                                                                           :installed-successor-source
                                                                           install)))
                            (install-terminate (and install-type-ok
                                                    (%compiler-family-call family*
                                                                           :installed-terminate-p
                                                                           install)))
                            (next-source (and install-type-ok
                                              (or install-target
                                                  install-successor))))
                       (unless step-type-ok
                         (push (list :kind :unexpected-artifact-type
                                     :artifact :compiler-step
                                     :index index
                                     :expected (%compiler-expected-type-names family*
                                                                              :compiler-step)
                                     :actual (%compiler-type-string step))
                               violations))
                       (when (and expected-source
                                  step-source
                                  (not (equal step-source expected-source)))
                         (push (list :kind :trace-source
                                     :index index
                                     :expected expected-source
                                     :actual step-source)
                               violations))
                       (unless install-type-ok
                         (push (list :kind :unexpected-artifact-type
                                     :artifact :installed-generation-ir
                                     :index index
                                     :expected (%compiler-expected-type-names family*
                                                                              :installed-generation-ir)
                                     :actual (and install
                                                  (%compiler-type-string install)))
                               violations))
                       (when (and install-type-ok
                                  step-source
                                  (not (equal install-root step-source)))
                         (push (list :kind :trace-root-source
                                     :index index
                                     :expected step-source
                                     :actual install-root)
                               violations))
                       (when (and previous-install
                                  (%compiler-family-call family*
                                                         :installed-terminate-p
                                                         previous-install))
                         (push (list :kind :step-after-terminate
                                     :index index)
                               violations))
                       (when (and step-type-ok
                                  (null step-asm))
                         (push (list :kind :missing-artifact
                                     :artifact :asm-prog
                                     :index index)
                               violations))
                       (when (and step-type-ok
                                  step-asm
                                  (not (%compiler-artifact-type-ok-p family*
                                                                     :asm-prog
                                                                     step-asm)))
                         (push (list :kind :unexpected-artifact-type
                                     :artifact :asm-prog
                                     :index index
                                     :expected (%compiler-expected-type-names family*
                                                                              :asm-prog)
                                     :actual (%compiler-type-string step-asm))
                               violations))
                       (when (and step-type-ok
                                  (or (null step-bytes)
                                      (not (arrayp step-bytes))
                                      (not (plusp (length step-bytes)))))
                         (push (list :kind :invalid-bytes
                                     :index index
                                     :value step-bytes)
                               violations))
                       (push (list :index index
                                   :source-id step-source
                                   :install-root-source install-root
                                   :terminate-p install-terminate
                                   :next-source next-source
                                   :asm-signature (and step-asm
                                                       (%compiler-artifact-signature step-asm))
                                   :bytes-length (and step-bytes
                                                      (length step-bytes)))
                             checks)
                       (setf expected-source (unless install-terminate next-source)
                             previous-install (and install-type-ok install)))))
          (%compiler-check-result
           family*
           :compiler-bounded-trace-parity
           sid
           control-id
           (if violations :failed :passed)
           (list :limit trace-limit
                 :chain-length (and (listp trace) (length trace))
                 :alternate-trace-present-p (not (null alternate-trace))
                 :checks (nreverse checks)
                 :violations (nreverse violations))
           (list :direction direction)))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-bounded-trace-parity
         sid
         control-id
         condition)))))

(defun check-compiler-layout (family &optional source-id control-id)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id)))))
    (handler-case
        (let* ((asm-prog (%compiler-family-call family* :lower-source-to-asm-prog sid control-id))
               (layout (%compiler-family-call family* :layout-asm-prog asm-prog))
               (entries (%compiler-family-call family* :asm-layout-entries layout))
               (label-pcs (%compiler-family-call family* :asm-layout-label-pcs layout))
               (size (%compiler-family-call family* :asm-layout-size layout))
               (expected-index 0)
               (expected-pc 0)
               (violations '())
               (label-count 0))
          (dolist (entry entries)
            (let ((index (%compiler-family-call family* :asm-layout-entry-index entry))
                  (pc (%compiler-family-call family* :asm-layout-entry-pc entry))
                  (width (%compiler-family-call family* :asm-layout-entry-width entry))
                  (opcode (%compiler-family-call family* :asm-layout-entry-opcode entry))
                  (operands (%compiler-family-call family* :asm-layout-entry-operands entry)))
              (unless (eql index expected-index)
                (push (list :kind :index
                            :expected expected-index
                            :actual index)
                      violations))
              (unless (and (integerp pc) (>= pc 0) (eql pc expected-pc))
                (push (list :kind :pc
                            :expected expected-pc
                            :actual pc
                            :index index)
                      violations))
              (unless (and (integerp width) (>= width 0))
                (push (list :kind :width
                            :expected :nonnegative-integer
                            :actual width
                            :index index)
                      violations))
              (when (and (not (eq opcode :label))
                         (eql width 0))
                (push (list :kind :zero-width-nonlabel
                            :opcode opcode
                            :index index)
                      violations))
              (when (eq opcode :label)
                (incf label-count)
                (let ((label (first operands)))
                  (unless (eql (%compiler-layout-label-pc label-pcs label) pc)
                    (push (list :kind :label-pc
                                :label label
                                :expected pc
                                :actual (%compiler-layout-label-pc label-pcs label))
                          violations))))
              (incf expected-index)
              (incf expected-pc (if (and (integerp width) (>= width 0))
                                    width
                                    0))))
          (unless (eql expected-pc size)
            (push (list :kind :size
                        :expected expected-pc
                        :actual size)
                  violations))
          (%compiler-check-result
           family*
           :compiler-layout-monotonicity
           sid
           control-id
           (if violations :failed :passed)
           (list :entry-count (length entries)
                 :label-count label-count
                 :size size
                 :violations (nreverse violations))
           (list :layout-type (%compiler-type-string layout))))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-layout-monotonicity
         sid
         control-id
         condition)))))

(defun check-compiler-roundtrip (family &optional source-id control-id)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id)))))
    (handler-case
        (let* ((fields (%compiler-roundtrip-fields family*))
               (action (%compiler-family-call family* :interpret-source sid control-id))
               (bytes (%compiler-family-call family* :encode-source-to-bytes sid control-id))
               (decoded (%compiler-family-call family* :decode-bytes bytes))
               (expected
                 (loop for field in fields
                       append (list field
                                    (%compiler-family-call
                                     family*
                                     (%compiler-roundtrip-accessor-key family* field)
                                     action))))
               (mismatches
                 (loop for field in fields
                       for expected-value = (getf expected field)
                       for actual-value = (getf decoded field)
                       unless (equal expected-value actual-value)
                         collect (list :field field
                                       :expected expected-value
                                       :actual actual-value))))
          (%compiler-check-result
           family*
           :compiler-encode-decode-roundtrip
           sid
           control-id
           (if mismatches :failed :passed)
           (list :bytes-length (length bytes)
                 :expected expected
                 :decoded decoded
                 :mismatches mismatches)
           (list :field-count (length fields))))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-encode-decode-roundtrip
         sid
         control-id
         condition)))))

(defun check-compiler-image-closure (family &optional source-id control-id)
  (let* ((family* (%resolve-compiler-family family))
         (sid (or source-id
                  (handler-case
                      (%compiler-sample-source-id family*)
                    (error () source-id)))))
    (handler-case
        (let* ((step (%compiler-family-call family* :assemble-step sid control-id))
               (image (%compiler-family-call family* :fragment-image
                                            (%compiler-family-call family* :step-fragment step)))
               (root-id (%compiler-family-call family* :image-root-id image))
               (blob-id (%compiler-family-call family* :image-blob-id image))
               (cells (%compiler-family-call family* :image-cells image))
               (blob (%compiler-family-call family* :image-blob image))
               (layout (%compiler-family-call family* :image-layout image))
               (layout-size (%compiler-family-call family* :asm-layout-size layout))
               (cell-ids (mapcar #'car cells))
               (sorted-cell-ids (sort (copy-list cell-ids) #'<))
               (unique-cell-ids (remove-duplicates cell-ids :test #'eql))
               (violations '()))
          (unless (and (integerp root-id) (member root-id cell-ids :test #'eql))
            (push (list :kind :root-id
                        :value root-id)
                  violations))
          (unless (and (integerp blob-id) (member blob-id cell-ids :test #'eql))
            (push (list :kind :blob-id
                        :value blob-id)
                  violations))
          (unless (equal cell-ids sorted-cell-ids)
            (push (list :kind :cell-order
                        :expected sorted-cell-ids
                        :actual cell-ids)
                  violations))
          (unless (= (length cell-ids) (length unique-cell-ids))
            (push (list :kind :duplicate-cell-ids
                        :actual cell-ids)
                  violations))
          (unless (and (arrayp blob) (plusp (length blob)))
            (push (list :kind :blob
                        :value blob)
                  violations))
          (unless (and layout (integerp layout-size) (>= layout-size 0))
            (push (list :kind :layout
                        :value layout)
                  violations))
          (%compiler-check-result
           family*
           :compiler-image-closure
           sid
           control-id
           (if violations :failed :passed)
           (list :cell-count (length cells)
                 :blob-length (and (arrayp blob) (length blob))
                 :layout-size layout-size
                 :root-id root-id
                 :blob-id blob-id
                 :violations (nreverse violations))
           (list :image-type (%compiler-type-string image))))
      (error (condition)
        (%compiler-check-error-result
         family*
         :compiler-image-closure
         sid
         control-id
         condition)))))

(defun build-search-operator-instance
    (operator-class target-zone source-operation
     &optional replay-token budget-row metadata)
  (let ((class* (or (and (typep operator-class 'search-operator-class) operator-class)
                    (find-search-operator-class operator-class)
                    (error "Unknown search operator class ~S." operator-class))))
    (make-search-operator-instance
     :id (format nil "search-operator-instance:~(~A~):~X"
                 (search-operator-class-id class*)
                 (artifact-digest
                  (list (search-operator-class-id class*)
                        target-zone
                        source-operation
                        replay-token
                        budget-row
                        metadata)))
     :operator-class-id (search-operator-class-id class*)
     :target-zone target-zone
     :source-operation source-operation
     :replay-token replay-token
     :budget-row budget-row
     :metadata metadata)))

(defun build-search-formal-obligation
    (kind scope projection-seed source-operation
     &optional status metadata severity freshness-law)
  (let ((entry (or (find-search-kernel-obligation-kind kind)
                   (error "Unknown search obligation kind ~S." kind))))
    (make-search-formal-obligation
     :id (format nil "search-obligation:~(~A~):~X"
                 kind
                 (artifact-digest (list kind scope projection-seed source-operation metadata)))
     :kind kind
     :severity (or severity (search-kernel-obligation-kind-severity entry))
     :scope scope
     :projection-seed projection-seed
     :freshness-law (or freshness-law
                        (search-kernel-obligation-kind-freshness-law entry))
     :source-operation source-operation
     :status (or status :open)
     :metadata metadata)))

(defun project-search-formal-obligation (obligation)
  (unless (typep obligation 'search-formal-obligation)
    (error "Expected search-formal-obligation, got ~S." obligation))
  (let* ((kind-entry
           (or (find-search-kernel-obligation-kind
                (search-formal-obligation-kind obligation))
               (error "Unknown search obligation kind ~S."
                      (search-formal-obligation-kind obligation))))
         (payload
           (list :obligation-id (search-formal-obligation-id obligation)
                 :kind (search-formal-obligation-kind obligation)
                 :scope (search-formal-obligation-scope obligation)
                 :projection-seed (search-formal-obligation-projection-seed obligation)
                 :source-operation (search-formal-obligation-source-operation obligation))))
    (make-search-obligation-projection
     :obligation-id (search-formal-obligation-id obligation)
     :kind (search-formal-obligation-kind obligation)
     :operation-id (search-kernel-obligation-kind-projection-operation kind-entry)
     :payloads (list payload)
     :totality-class :total
     :metadata (list :severity (search-formal-obligation-severity obligation)
                     :freshness-law (search-formal-obligation-freshness-law obligation)))))

(defun evaluate-search-bridge-totality (obligation &optional capability)
  (unless (typep obligation 'search-formal-obligation)
    (error "Expected search-formal-obligation, got ~S." obligation))
  (let* ((projection (project-search-formal-obligation obligation))
         (capability* (or capability (current-formal-capability-class)))
         (operation
           (find-formal-capability-operation
            (formal-capability-class-operations capability*)
            (search-obligation-projection-operation-id projection)))
         (payloads (search-obligation-projection-payloads projection))
         (status (cond
                   ((null operation) :missing-route)
                   ((null payloads) :empty-payload-family)
                   (t :total))))
    (make-search-bridge-totality-result
     :obligation-id (search-formal-obligation-id obligation)
     :obligation-kind (search-formal-obligation-kind obligation)
     :status status
     :projection-operation (search-obligation-projection-operation-id projection)
     :payload-count (length payloads)
     :route-operation-id (and operation
                              (formal-capability-operation-id operation))
     :diagnostics
     (list :totality-class (search-obligation-projection-totality-class projection)
           :severity (search-formal-obligation-severity obligation)
           :capability-id (formal-capability-class-id capability*)))))

(defun build-search-formal-evidence
    (obligation judgment certificate freshness-status
     &optional resource-row metadata)
  (unless (typep obligation 'search-formal-obligation)
    (error "Expected search-formal-obligation, got ~S." obligation))
  (let ((status
          (cond
            ((eq judgment :pass)
             (if (eq freshness-status :fresh) :fresh-pass :stale))
            ((or (eq judgment :fail)
                 (eq judgment :advisory-fail))
             (if (eq freshness-status :fresh) :fresh-fail :stale))
            (t :open))))
    (make-search-formal-evidence
     :id (format nil "search-evidence:~A:~X"
                 (search-formal-obligation-id obligation)
                 (artifact-digest (list judgment certificate freshness-status resource-row metadata)))
     :obligation-id (search-formal-obligation-id obligation)
     :obligation-kind (search-formal-obligation-kind obligation)
     :evidence-kind :search-formal-evidence
     :judgment judgment
     :status status
     :certificate certificate
     :scope (search-formal-obligation-scope obligation)
     :freshness-status (or freshness-status :fresh)
     :resource-row resource-row
     :metadata metadata)))

(defun %search-evidence-status-from-evidence (entry)
  (or (search-formal-evidence-status entry)
      (cond
        ((eq (search-formal-evidence-freshness-status entry) :fresh)
         (if (member (search-formal-evidence-judgment entry) '(:fail :advisory-fail))
             :fresh-fail
             :fresh-pass))
        ((search-formal-evidence-judgment entry) :stale)
        (t :open))))

(defun %search-evidence-classify-obligation-status (entries)
  (cond
    ((null entries) :open)
    ((find :fresh-fail entries :key #'%search-evidence-status-from-evidence) :fresh-fail)
    ((find :fresh-pass entries :key #'%search-evidence-status-from-evidence) :fresh-pass)
    ((some (lambda (entry)
             (member (%search-evidence-status-from-evidence entry)
                     '(:stale :superseded)))
           entries)
     :stale)
    (t :open)))

(defun %search-evidence-index-entry (index evidence)
  (acons (search-formal-evidence-id evidence)
         evidence
         (remove (search-formal-evidence-id evidence)
                 index
                 :key #'car
                 :test #'equal)))

(defun %search-evidence-entry-from-index (index evidence-id)
  (cdr (assoc evidence-id index :test #'equal)))

(defun %search-obligation-severity (obligation-kind)
  (let ((entry (find-search-kernel-obligation-kind obligation-kind)))
    (if entry
        (search-kernel-obligation-kind-severity entry)
        :hard)))

(defun %search-evidence-summarize-statuses (obligation-statuses)
  (let ((hard-debt 0)
        (advisory-debt 0)
        (coverage 0)
        (fresh-count 0)
        (stale-count 0)
        (open-count 0))
    (dolist (pair obligation-statuses)
      (case (cdr pair)
        (:fresh-pass
         (incf coverage)
         (incf fresh-count))
        (:fresh-fail
         (incf fresh-count)
         (if (eq (%search-obligation-severity (car pair)) :advisory)
             (incf advisory-debt)
             (incf hard-debt)))
        (:stale
         (incf stale-count))
        (otherwise
         (incf open-count))))
    (values hard-debt
            advisory-debt
            coverage
            fresh-count
            stale-count
            open-count)))

(defun apply-search-evidence-update
    (state-id evidence &optional prior-hard-debt prior-advisory-debt prior-evidence-state)
  (let* ((entries (if (listp evidence) evidence (list evidence)))
         (prior-state
           (and prior-evidence-state
                (or (and (typep prior-evidence-state 'search-evidence-state)
                         prior-evidence-state)
                    (error "Expected search-evidence-state, got ~S."
                           prior-evidence-state))))
         (prior-live-ids (copy-list (or (and prior-state
                                             (search-evidence-state-live-evidence-ids prior-state))
                                        '())))
         (prior-entry-index
           (copy-list (or (and prior-state
                               (getf (search-evidence-state-metadata prior-state)
                                     :evidence-entry-index))
                          '())))
         (status-table (make-hash-table :test #'eq))
         (grouped-by-kind (make-hash-table :test #'eq))
         (grouped-by-obligation (make-hash-table :test #'equal))
         (supersession-links
           (copy-list (or (and prior-state
                               (search-evidence-state-supersession-links prior-state))
                          '())))
         (entry-index prior-entry-index)
         (live-evidence-ids (copy-list prior-live-ids)))
    (dolist (pair (and prior-state
                       (search-evidence-state-obligation-statuses prior-state)))
      (setf (gethash (car pair) status-table) (cdr pair)))
    (dolist (entry entries)
      (unless (typep entry 'search-formal-evidence)
        (error "Expected search-formal-evidence, got ~S." entry))
      (push entry (gethash (search-formal-evidence-obligation-kind entry) grouped-by-kind))
      (push entry (gethash (search-formal-evidence-obligation-id entry) grouped-by-obligation))
      (pushnew (search-formal-evidence-id entry) live-evidence-ids :test #'equal)
      (setf entry-index (%search-evidence-index-entry entry-index entry)))
    (maphash
     (lambda (obligation-kind grouped-entries)
       (let ((new-status (%search-evidence-classify-obligation-status grouped-entries)))
         (setf (gethash obligation-kind status-table) new-status)))
     grouped-by-kind)
    (maphash
     (lambda (obligation-id grouped-entries)
       (let* ((replacement-id (search-formal-evidence-id (first grouped-entries)))
              (prior-obligation-ids
                (loop for prior-id in prior-live-ids
                      for prior-entry = (%search-evidence-entry-from-index prior-entry-index prior-id)
                      when (and prior-entry
                                (equal (search-formal-evidence-obligation-id prior-entry)
                                       obligation-id))
                        collect prior-id)))
         (dolist (prior-id prior-obligation-ids)
           (unless (equal prior-id replacement-id)
             (setf live-evidence-ids (remove prior-id live-evidence-ids :test #'equal))
             (push (list :prior-evidence-id prior-id
                         :superseded-by replacement-id
                         :obligation-id obligation-id)
                   supersession-links)))))
     grouped-by-obligation)
    (let* ((obligation-statuses
             (loop for obligation-kind being the hash-keys of status-table
                     using (hash-value status)
                   collect (cons obligation-kind status)))
           (hard-debt 0)
           (advisory-debt 0)
           (coverage 0)
           (fresh-count 0)
           (stale-count 0)
           (open-count 0)
           (overall-status
             :open))
      (multiple-value-setq (hard-debt advisory-debt coverage fresh-count stale-count open-count)
        (%search-evidence-summarize-statuses obligation-statuses))
      (setf overall-status
            (cond
              ((null obligation-statuses) :open)
              ((plusp hard-debt) :fresh-fail)
              ((plusp advisory-debt) :fresh-fail)
              ((plusp open-count) :open)
              ((plusp stale-count) :stale)
              (t :fresh-pass)))
      (let ((evidence-state
              (make-search-evidence-state
               :state-id state-id
               :obligation-statuses obligation-statuses
               :live-evidence-ids (nreverse live-evidence-ids)
               :supersession-links (nreverse supersession-links)
               :hard-debt hard-debt
               :advisory-debt advisory-debt
               :coverage-summary (list :covered-obligation-count coverage
                                       :total-obligation-count (length obligation-statuses))
               :freshness-summary (list :fresh-count fresh-count
                                        :stale-count stale-count
                                        :open-count open-count)
               :status overall-status
               :metadata (list :prior-hard-debt prior-hard-debt
                               :prior-advisory-debt prior-advisory-debt
                               :evidence-entry-index entry-index))))
        (make-search-evidence-update
         :state-id state-id
         :evidence-ids (mapcar #'search-formal-evidence-id entries)
         :obligation-statuses obligation-statuses
         :live-evidence-ids (search-evidence-state-live-evidence-ids evidence-state)
         :supersession-links (search-evidence-state-supersession-links evidence-state)
         :hard-debt hard-debt
         :advisory-debt advisory-debt
         :coverage-summary (search-evidence-state-coverage-summary evidence-state)
         :freshness-summary (search-evidence-state-freshness-summary evidence-state)
         :status overall-status
         :metadata (list :evidence-state evidence-state))))))

(defun evaluate-search-admission-law
    (law state-id evidence-update &optional touched-obligation-kinds)
  (let* ((law* (or (and (typep law 'search-admission-law) law)
                   (find-search-admission-law law)
                   (error "Unknown search admission law ~S." law)))
         (update* (or (and (typep evidence-update 'search-evidence-update) evidence-update)
                      (error "Expected search-evidence-update, got ~S." evidence-update)))
         (status-pairs (search-evidence-update-obligation-statuses update*))
         (touched-kinds (or touched-obligation-kinds
                            (search-admission-law-hard-obligation-kinds law*)))
         (effective-statuses
           (loop for kind in touched-kinds
                 collect (cons kind
                               (or (cdr (assoc kind status-pairs :test #'eq))
                                   :open))))
         (hard-kinds (search-admission-law-hard-obligation-kinds law*))
         (advisory-kinds (search-admission-law-advisory-obligation-kinds law*))
         (status (cond
                   ((some (lambda (pair)
                            (and (member (car pair) hard-kinds)
                                 (eq (cdr pair) :fresh-fail)))
                          effective-statuses)
                    :reject)
                   ((some (lambda (pair)
                            (and (member (car pair) hard-kinds)
                                 (member (cdr pair) '(:open :stale))))
                          effective-statuses)
                    :quarantine)
                   ((or
                     (plusp (search-evidence-update-advisory-debt update*))
                     (some (lambda (pair)
                             (and (member (car pair) advisory-kinds)
                                  (member (cdr pair) '(:fresh-fail :open :stale))))
                           effective-statuses))
                    :quarantine)
                   (t :admit))))
    (make-search-admission-result
     :law-id (search-admission-law-id law*)
     :state-id state-id
     :status status
     :hard-debt (search-evidence-update-hard-debt update*)
     :advisory-debt (search-evidence-update-advisory-debt update*)
     :failing-obligation-kinds
     (if (eq status :reject)
         (loop for pair in effective-statuses
               when (eq (cdr pair) :fresh-fail)
               collect (car pair))
         '())
     :diagnostics (list :obligation-statuses effective-statuses
                        :freshness-summary (search-evidence-update-freshness-summary update*)
                        :coverage-summary (search-evidence-update-coverage-summary update*)
                        :kernel-requirements
                        (copy-list (search-admission-law-kernel-requirements law*))))))

(defun evaluate-search-evidence-monotonicity
    (current &optional prior)
  (let* ((current-state
           (or (and (typep current 'search-evidence-state) current)
               (and (typep current 'search-evidence-update)
                    (build-search-evidence-state-from-update current))
               (error "Expected search-evidence-state or search-evidence-update, got ~S."
                      current)))
         (prior-state
           (cond
             ((null prior) nil)
             ((typep prior 'search-evidence-state) prior)
             ((typep prior 'search-evidence-update)
              (build-search-evidence-state-from-update prior))
             (t
              (error "Expected prior search-evidence-state or search-evidence-update, got ~S."
                     prior))))
         (current-live (copy-list (search-evidence-state-live-evidence-ids current-state)))
         (prior-live (copy-list (or (and prior-state
                                         (search-evidence-state-live-evidence-ids prior-state))
                                    '())))
         (appended (set-difference current-live prior-live :test #'equal))
         (preserved (intersection current-live prior-live :test #'equal))
         (removed (set-difference prior-live current-live :test #'equal))
         (links (copy-list (search-evidence-state-supersession-links current-state)))
         (covered-removed
           (every (lambda (evidence-id)
                    (find evidence-id links
                          :key (lambda (entry)
                                 (getf entry :prior-evidence-id))
                          :test #'equal))
                  removed))
         (status (if covered-removed :monotone :violated)))
    (make-search-evidence-monotonicity-result
     :state-id (search-evidence-state-state-id current-state)
     :status status
     :preserved-evidence-ids preserved
     :appended-evidence-ids appended
     :supersession-links links
     :diagnostics
     (list :removed-evidence-ids removed
           :prior-state-id (and prior-state
                                (search-evidence-state-state-id prior-state))
           :current-status (search-evidence-state-status current-state)))))

(defun evaluate-search-supersession-consistency (state)
  (let* ((evidence-state
           (or (and (typep state 'search-evidence-state) state)
               (and (typep state 'search-evidence-update)
                    (build-search-evidence-state-from-update state))
               (error "Expected search-evidence-state or search-evidence-update, got ~S."
                      state)))
         (frontier (evaluate-search-evidence-frontier evidence-state))
         (frontier-obligation-ids
           (mapcar (lambda (entry) (getf entry :obligation-id))
                   (search-evidence-frontier-live-frontier frontier)))
         (links (copy-list (search-evidence-state-supersession-links evidence-state)))
         (covered '())
         (uncovered '()))
    (dolist (link links)
      (let ((obligation-id (getf link :obligation-id)))
        (cond
          ((member obligation-id frontier-obligation-ids :test #'equal)
           (pushnew obligation-id covered :test #'equal))
          (t
           (pushnew obligation-id uncovered :test #'equal)))))
    (make-search-supersession-consistency-result
     :state-id (search-evidence-state-state-id evidence-state)
     :status (if uncovered :inconsistent :consistent)
     :covered-obligation-ids (nreverse covered)
     :uncovered-obligation-ids (nreverse uncovered)
     :diagnostics
     (list :frontier-obligation-ids frontier-obligation-ids
           :supersession-count (length links)
           :state-status (search-evidence-state-status evidence-state)))))

(defun evaluate-search-legal-transition
    (operator-instance state-id
     &optional capability budget-ok-p kernel-ok-p replay-ok-p)
  (let* ((instance (or (and (typep operator-instance 'search-operator-instance)
                            operator-instance)
                       (error "Expected search-operator-instance, got ~S."
                              operator-instance)))
         (class* (or (find-search-operator-class
                      (search-operator-instance-operator-class-id instance))
                     (error "Unknown search operator class ~S."
                            (search-operator-instance-operator-class-id instance))))
         (capability* (or capability (current-formal-capability-class)))
         (satisfied '())
         (failing '())
         (bridge-results '()))
    (if (and (search-operator-instance-target-zone instance)
             (search-operator-instance-source-operation instance))
        (push :type-domain-ok satisfied)
        (push :type-domain-ok failing))
    (if (if (search-operator-class-replay-required-p class*)
            (or replay-ok-p
                (search-operator-instance-replay-token instance))
            t)
        (push :replay-defined satisfied)
        (push :replay-defined failing))
    (dolist (kind (search-operator-class-mandatory-obligation-kinds class*))
      (let* ((obligation
               (build-search-formal-obligation
                kind
                (list :zone (search-operator-instance-target-zone instance))
                (list :operator-class (search-operator-class-id class*)
                      :operator-instance (search-operator-instance-id instance))
                (search-operator-instance-source-operation instance)))
             (totality (evaluate-search-bridge-totality obligation capability*)))
        (push totality bridge-results)
        (when (eq kind :bridge-totality)
          (if (eq (search-bridge-totality-result-status totality) :total)
              (push :bridge-totality satisfied)
              (push :bridge-totality failing)))))
    (if (if (null budget-ok-p)
            (not (getf (or (search-operator-instance-budget-row instance) '())
                       :exceeded))
            budget-ok-p)
        (push :budget-ok satisfied)
        (push :budget-ok failing))
    (if (if (null kernel-ok-p)
            (not (null (search-operator-class-kernel-requirements class*)))
            kernel-ok-p)
        (push :kernel-preserved satisfied)
        (push :kernel-preserved failing))
    (make-search-legal-transition
     :operator-instance-id (search-operator-instance-id instance)
     :operator-class-id (search-operator-class-id class*)
     :state-id state-id
     :status (if failing :illegal :legal)
     :satisfied-clauses (sort (copy-list satisfied)
                              #'string<
                              :key #'%runtime-name-string)
     :failing-clauses (sort (copy-list failing)
                            #'string<
                            :key #'%runtime-name-string)
     :bridge-totality-results (nreverse bridge-results)
     :diagnostics
     (list :capability-id (formal-capability-class-id capability*)
           :mandatory-obligation-kinds
           (copy-list (search-operator-class-mandatory-obligation-kinds class*))
           :kernel-requirements
           (copy-list (search-operator-class-kernel-requirements class*))))))

(defun formal-constraint-class-json-object (constraint)
  (list
   (cons "id" (%runtime-name-string (formal-constraint-class-id constraint)))
   (cons "lane" (%runtime-name-string (formal-constraint-class-lane constraint)))
   (cons "kind" (%runtime-name-string (formal-constraint-class-kind constraint)))
   (cons "callable" (%runtime-name-string (formal-constraint-class-callable constraint)))
   (cons "expected_result_kind"
         (%runtime-name-string (formal-constraint-class-expected-result-kind constraint)))
   (cons "note" (formal-constraint-class-note constraint))))

(defun formal-admission-policy-json-object (policy)
  (list
   (cons "id" (%runtime-name-string (formal-admission-policy-id policy)))
   (cons "allowed_invocations"
         (mapcar #'%runtime-name-string
                 (formal-admission-policy-allowed-invocations policy)))
   (cons "required_evidence"
         (mapcar #'%runtime-name-string
                 (formal-admission-policy-required-evidence policy)))
   (cons "trusted_boundaries"
         (mapcar #'%runtime-name-string
                 (formal-admission-policy-trusted-boundaries policy)))
   (cons "forbidden_mutations"
         (mapcar #'%runtime-name-string
                 (formal-admission-policy-forbidden-mutations policy)))
   (cons "note" (formal-admission-policy-note policy))))

(defun formal-capability-class-json-object (capability)
  (list
   (cons "id" (%runtime-name-string (formal-capability-class-id capability)))
   (cons "operations"
         (mapcar
          (lambda (operation)
            (let ((row (formal-capability-operation-callable-row operation)))
              (list
               (cons "id"
                     (%runtime-name-string
                      (formal-capability-operation-id operation)))
               (cons "callable_row"
                     (runtime-callable-row-name row))
               (cons "argument_keys"
                     (mapcar #'%runtime-name-string
                             (runtime-callable-row-argument-keys row)))
               (cons "input_schema" (runtime-callable-row-input-schema row))
               (cons "output_schema" (runtime-callable-row-output-schema row))
               (cons "effect_kind"
                     (%runtime-name-string
                      (runtime-callable-row-effect-kind row)))
               (cons "evidence_kind"
                     (%runtime-name-string
                      (runtime-callable-row-evidence-kind row)))
               (cons "constraint_classes"
                     (mapcar #'%runtime-name-string
                             (formal-capability-operation-constraint-classes
                              operation)))
               (cons "required_evidence"
                     (mapcar #'%runtime-name-string
                             (formal-capability-operation-required-evidence
                              operation)))
               (cons "admissible_caller_classes"
                     (mapcar #'%runtime-name-string
                             (formal-capability-operation-admissible-caller-classes
                              operation)))
               (cons "trusted_boundaries"
                     (mapcar #'%runtime-name-string
                             (formal-capability-operation-trusted-boundaries
                              operation))))))
          (sort (copy-list (formal-capability-class-operations capability))
                #'string<
                :key (lambda (operation)
                       (%runtime-name-string
                        (formal-capability-operation-id operation))))))
   (cons "callable_rows"
         (mapcar (lambda (row)
                   (list
                    (cons "operation_id"
                          (%runtime-name-string
                           (runtime-callable-row-operation-id row)))
                    (cons "name" (runtime-callable-row-name row))
                    (cons "callable" (%runtime-name-string (runtime-callable-row-callable row)))
                    (cons "kind" (%runtime-name-string (runtime-callable-row-kind row)))
                    (cons "lane" (%runtime-name-string (runtime-callable-row-lane row)))
                    (cons "ref_id"
                          (and (runtime-callable-row-ref-id row)
                               (%runtime-name-string (runtime-callable-row-ref-id row))))
                    (cons "argument_keys"
                          (mapcar #'%runtime-name-string
                                  (runtime-callable-row-argument-keys row)))
                    (cons "input_schema" (runtime-callable-row-input-schema row))
                    (cons "output_schema" (runtime-callable-row-output-schema row))
                    (cons "effect_kind"
                          (%runtime-name-string (runtime-callable-row-effect-kind row)))
                    (cons "evidence_kind"
                          (%runtime-name-string (runtime-callable-row-evidence-kind row)))
                    (cons "note" (runtime-callable-row-note row))))
                 (%sort-runtime-callable-rows
                  (copy-list (formal-capability-class-callable-rows capability)))))
   (cons "constraint_classes"
         (mapcar #'formal-constraint-class-json-object
                 (formal-capability-class-constraint-classes capability)))
   (cons "evidence_kinds"
         (mapcar #'%runtime-name-string
                 (formal-capability-class-evidence-kinds capability)))
   (cons "trusted_boundaries"
         (mapcar #'%runtime-name-string
                 (formal-capability-class-trusted-boundaries capability)))
   (cons "admission_policy"
         (formal-admission-policy-json-object
          (formal-capability-class-admission-policy capability)))
   (cons "meta" (formal-capability-class-meta capability))))

(defun runtime-constitution-callable-rows (constitution)
  (%sort-runtime-callable-rows
   (loop for capability in (runtime-constitution-capability-classes constitution)
         append (copy-list (runtime-capability-class-callable-rows capability)))))

(defun find-runtime-callable-row (rows operation-id)
  (let ((name (%runtime-name-string operation-id)))
    (or (find name rows :key #'runtime-callable-row-name :test #'string=)
        (find operation-id rows
              :key #'runtime-callable-row-operation-id
              :test #'equal))))

(defun make-formal-capability-operations (rows constraints)
  (mapcar (lambda (row)
            (make-formal-capability-operation
             :id (runtime-callable-row-operation-id row)
             :callable-row row
             :constraint-classes
             (loop for constraint in constraints
                   when (eq (formal-constraint-class-callable constraint)
                            (runtime-callable-row-callable row))
                   collect (formal-constraint-class-id constraint))
             :required-evidence
             (list (runtime-callable-row-evidence-kind row))
             :admissible-caller-classes
             (case (runtime-callable-row-lane row)
               (:kernel '(:synth :audit))
               (:smt '(:synth :audit :stage))
               (:bridge '(:synth :audit :stage :compiler))
               (:lsip '(:synth :audit :compiler))
               (:audit '(:synth :audit))
               (:formal '(:synth :audit :compiler))
               (otherwise '(:synth)))
             :trusted-boundaries
             (case (runtime-callable-row-lane row)
               (:kernel '(:kernel))
               (:smt '(:smt))
               (:bridge '(:bridge))
               (:lsip '(:lsip))
               (:audit '(:closure))
               (otherwise '(:constitution)))))
          rows))

(defun find-formal-capability-operation (operations operation-id)
  (find operation-id operations
        :key #'formal-capability-operation-id
        :test #'equal))

(defun find-formal-capability-operations-by-constraint-class
    (operations constraint-class-id)
  (remove-if-not
   (lambda (operation)
     (member constraint-class-id
             (formal-capability-operation-constraint-classes operation)))
   operations))

(defun make-formal-constraint-classes ()
  (list
   (make-formal-constraint-class
    :id :kernel-judgment-check
    :lane :kernel
    :kind :decision
    :callable 'check-kernel-spec-kr
    :expected-result-kind :kernel-status
    :note "Shared kernel judgment checking over frozen kernel-spec carriers.")
   (make-formal-constraint-class
    :id :kernel-lane-parity
    :lane :kernel
    :kind :equivalence
    :callable 'compare-kernel-spec-kr-kl-defir
    :expected-result-kind :parity-report
    :note "Three-lane KR/KL/DefIR parity over shared kernel obligations.")
   (make-formal-constraint-class
    :id :smt-admitted-bridge
    :lane :bridge
    :kind :discharge
   :callable 'j-smt-admitted-obligation-bridge
   :expected-result-kind :bridge-status
   :note "Admitted SMT bridge discharge over frozen O_i / S_i / Pi_i classes.")
   (make-formal-constraint-class
    :id :smt-constraint-cegis
    :lane :smt
    :kind :synthesis
    :callable 'run-smt-cegis
    :expected-result-kind :cegis-state
    :note "Counterexample-guided synthesis over the admitted SMT constraint fragment.")
   (make-formal-constraint-class
    :id :lsip-edge-policy-cegis
    :lane :lsip
    :kind :synthesis
    :callable 'run-lsip-edge-policy-cegis
   :expected-result-kind :cegis-state
   :note "Counterexample-guided synthesis over LSIP edge-policy law selections.")
   (make-formal-constraint-class
    :id :compiler-mutation-cegis
    :lane :formal
    :kind :synthesis
    :callable 'run-compiler-mutation-cegis
    :expected-result-kind :cegis-state
    :note "Counterexample-guided synthesis over compiler-search mutation constraints.")
   (make-formal-constraint-class
    :id :cegis-synthesis
    :lane :formal
    :kind :synthesis
    :callable 'run-cegis-family
    :expected-result-kind :cegis-state
    :note "Generic CEGIS family dispatch over the frozen family manifest catalog.")
   (make-formal-constraint-class
    :id :structural-lsip-law
    :lane :lsip
    :kind :relation
    :callable 'check-lsip-edge-gate
    :expected-result-kind :lsip-law-result
    :note "Structural LSIP edge-law checking over prepared lowering relations.")
   (make-formal-constraint-class
    :id :closure-profile-check
    :lane :audit
    :kind :audit
    :callable 'evaluate-metakernel-closure-profile
    :expected-result-kind :audit-result
    :note "Closure-profile evaluation over the current metakernel backlog.")
   (make-formal-constraint-class
    :id :compiler-family-schema
    :lane :formal
    :kind :decision
    :callable 'check-compiler-schema
    :expected-result-kind :compiler-check-result
    :note "Executable compiler-family schema and artifact-formation checks over a registered compiler family.")
   (make-formal-constraint-class
    :id :compiler-control-determinism
    :lane :formal
    :kind :decision
    :callable 'check-compiler-control-determinism
    :expected-result-kind :compiler-check-result
    :note "Repeated evaluation over a registered compiler family yields stable outputs for a fixed source/control input.")
   (make-formal-constraint-class
    :id :compiler-lowering-totality
    :lane :formal
    :kind :decision
    :callable 'check-compiler-lowering-totality
    :expected-result-kind :compiler-check-result
    :note "Declared compiler lowering edges are executable and produce well-typed artifacts for a registered compiler family.")
   (make-formal-constraint-class
    :id :compiler-installed-generation-soundness
    :lane :formal
    :kind :decision
    :callable 'check-compiler-installed-generation
    :expected-result-kind :compiler-check-result
    :note "Installed-generation artifacts agree with the action and step artifacts that produced them.")
   (make-formal-constraint-class
    :id :compiler-layout-monotonicity
    :lane :formal
    :kind :decision
    :callable 'check-compiler-layout
    :expected-result-kind :compiler-check-result
    :note "Monotone compiler-layout checking over a registered compiler family.")
   (make-formal-constraint-class
    :id :compiler-encode-decode-roundtrip
    :lane :formal
    :kind :relation
    :callable 'check-compiler-roundtrip
    :expected-result-kind :compiler-check-result
    :note "Executable encode/decode parity check over a registered compiler family.")
   (make-formal-constraint-class
    :id :compiler-image-closure
    :lane :formal
    :kind :decision
    :callable 'check-compiler-image-closure
    :expected-result-kind :compiler-check-result
    :note "Resident compiler-image closure check over a registered compiler family.")
   (make-formal-constraint-class
    :id :compiler-bounded-trace-parity
    :lane :formal
    :kind :relation
    :callable 'check-compiler-trace-parity
    :expected-result-kind :compiler-check-result
    :note "Bounded compiler trace coherence and alternate-trace parity over a registered compiler family.")
   (make-formal-constraint-class
    :id :search-obligation-formation
    :lane :formal
    :kind :construction
    :callable 'build-search-formal-obligation
    :expected-result-kind :search-obligation
    :note "Build a first-class formal search obligation from the frozen obligation catalog.")
   (make-formal-constraint-class
    :id :search-obligation-projection
    :lane :formal
    :kind :projection
    :callable 'project-search-formal-obligation
    :expected-result-kind :search-projection
    :note "Project a formal search obligation into governed FORMAL payload rows.")
   (make-formal-constraint-class
    :id :search-bridge-totality
    :lane :formal
    :kind :projection
    :callable 'evaluate-search-bridge-totality
    :expected-result-kind :search-bridge-totality
    :note "Check totality of the governed projection route for one search obligation.")
   (make-formal-constraint-class
    :id :search-evidence-closure
    :lane :formal
    :kind :closure
    :callable 'apply-search-evidence-update
    :expected-result-kind :search-evidence-update
    :note "Apply monotone evidence closure and derive debt, coverage, and freshness summaries.")
   (make-formal-constraint-class
    :id :search-evidence-monotonicity
    :lane :formal
    :kind :audit
    :callable 'evaluate-search-evidence-monotonicity
    :expected-result-kind :search-evidence-monotonicity
    :note "Check append-only evidence history with explicit supersession links.")
   (make-formal-constraint-class
    :id :search-evidence-frontier
    :lane :formal
    :kind :audit
    :callable 'evaluate-search-evidence-frontier
    :expected-result-kind :search-evidence-frontier
    :note "Compute the live per-obligation evidence frontier for an evidence-closed state.")
   (make-formal-constraint-class
    :id :search-supersession-consistency
    :lane :formal
    :kind :audit
    :callable 'evaluate-search-supersession-consistency
    :expected-result-kind :search-supersession-consistency
    :note "Check that every supersession link is backed by a live frontier representative.")
   (make-formal-constraint-class
    :id :search-legal-transition
    :lane :formal
    :kind :decision
    :callable 'evaluate-search-legal-transition
    :expected-result-kind :search-legal-transition
    :note "Evaluate the first legality kernel over a search operator instance.")
   (make-formal-constraint-class
    :id :search-admission-evaluation
    :lane :formal
    :kind :decision
    :callable 'evaluate-search-admission-law
    :expected-result-kind :search-admission-result
    :note "Evaluate the first search-kernel admission law over an evidence-closed state.")))

(defun build-formal-admission-policy ()
  (make-formal-admission-policy
   :id :formal-capability-admission
   :allowed-invocations '(:kernel-check
                          :smt-check
                          :cegis-synthesis
                          :cegis-trace
                          :bridge-discharge
                          :lsip-structural-check
                          :closure-audit
                          :search-kernel-read
                          :search-kernel-check)
   :required-evidence '(:kernel-status
                        :bridge-status
                        :cegis-state
                        :cegis-trace
                        :audit-result
                        :parity-report
                        :lsip-law-result
                        :compiler-check-result
                        :search-obligation
                        :search-projection
                        :search-bridge-totality
                        :search-operator-instance
                        :search-formal-evidence
                        :search-evidence-state
                        :search-evidence-update
                        :search-evidence-monotonicity
                        :search-evidence-frontier
                        :search-supersession-consistency
                        :search-legal-transition
                        :search-admission-result)
   :trusted-boundaries '(:kernel-core-registry
                         :smt-core-registry
                         :admitted-obligation-registry
                         :theorem-bridge-binding-registry
                         :lsip-lowering-contract-registry)
   :forbidden-mutations '(:kernel-core-semantics
                          :smt-core-semantics
                          :trusted-bridge-polarity
                          :closure-backlog-forgery
                          :lsip-edge-contract-forgery)
   :note "FORMAL exposes governed checking capabilities; synthesized callers may invoke services but may not mutate trusted semantic registries without admission."))

(defun make-formal-capability-class-object
    (&optional (constitution (current-runtime-constitution)))
  (let* ((rows (runtime-constitution-callable-rows constitution))
         (constraints (make-formal-constraint-classes)))
    (make-formal-capability-class
   :id :formal
   :callable-rows rows
   :operations (make-formal-capability-operations rows constraints)
   :constraint-classes constraints
   :evidence-kinds '(:kernel-status
                     :bridge-status
                     :cegis-state
                     :cegis-trace
                     :audit-result
                     :parity-report
                     :lsip-law-result
                     :compiler-check-result
                     :search-obligation
                     :search-projection
                     :search-bridge-totality
                     :search-operator-instance
                     :search-formal-evidence
                     :search-evidence-state
                     :search-evidence-update
                     :search-evidence-monotonicity
                     :search-evidence-frontier
                     :search-supersession-consistency
                     :search-legal-transition
                     :search-admission-result
                     :constitution-state)
   :trusted-boundaries '(:kernel
                         :smt
                         :bridge
                         :lsip
                         :closure)
   :admission-policy (build-formal-admission-policy)
   :meta (list :capability-provider :formal
               :callable-count (length rows)
               :operation-count (length rows)
               :constraint-count (length constraints)
               :closure-summary (closure-backlog-summary)))))

(defun current-formal-capability-class ()
  (make-formal-capability-class-object (current-runtime-constitution)))

(defun evaluate-formal-capability-report
    (&optional (capability (current-formal-capability-class)))
  (make-formal-capability-report
   :capability-id (formal-capability-class-id capability)
   :callable-count (length (formal-capability-class-callable-rows capability))
   :operation-count (length (formal-capability-class-operations capability))
   :constraint-count (length (formal-capability-class-constraint-classes capability))
   :evidence-kinds (copy-list (formal-capability-class-evidence-kinds capability))
   :trusted-boundaries (copy-list (formal-capability-class-trusted-boundaries capability))
   :admission-policy-id
   (formal-admission-policy-id (formal-capability-class-admission-policy capability))
   :summary (list :requires-evidence
                  (formal-admission-policy-required-evidence
                   (formal-capability-class-admission-policy capability))
                  :forbidden-mutations
                  (formal-admission-policy-forbidden-mutations
                   (formal-capability-class-admission-policy capability))
                  :operation-ids
                  (mapcar #'formal-capability-operation-id
                          (formal-capability-class-operations capability)))))

(defun check-formal-capability-consistency
    (&optional (capability (current-formal-capability-class)))
  (let* ((rows (formal-capability-class-callable-rows capability))
         (operations (formal-capability-class-operations capability))
         (row-callables (mapcar #'runtime-callable-row-callable rows))
         (evidence-kinds (formal-capability-class-evidence-kinds capability))
         (policy (formal-capability-class-admission-policy capability)))
    (and
     (every (lambda (row)
              (and (runtime-callable-row-input-schema row)
                   (or (null (runtime-callable-row-argument-keys row))
                       (listp (runtime-callable-row-argument-keys row)))
                   (runtime-callable-row-output-schema row)
                   (runtime-callable-row-effect-kind row)
                   (runtime-callable-row-evidence-kind row)))
            rows)
     (every (lambda (constraint)
              (member (formal-constraint-class-callable constraint)
                      row-callables
                      :test #'eq))
            (formal-capability-class-constraint-classes capability))
     (every (lambda (operation)
              (and (formal-capability-operation-callable-row operation)
                   (find-runtime-callable-row rows
                                              (formal-capability-operation-id operation))
                   (subsetp (formal-capability-operation-required-evidence operation)
                            evidence-kinds)))
            operations)
     (subsetp (formal-admission-policy-required-evidence policy)
              evidence-kinds)
     (subsetp '(:kernel :smt :bridge :lsip :closure)
              (formal-capability-class-trusted-boundaries capability)))))

(defun %normalized-argument-values (args)
  (loop for (key value) on args by #'cddr
        unless (member key '(:capability :mutation-kind :caller-class))
        collect value))

(defun %normalized-argument-plist (args)
  (loop for (key value) on args by #'cddr
        unless (member key '(:capability :mutation-kind :caller-class))
        append (list key value)))

(defun %schema-arity-bounds (input-schema)
  (let ((args (second input-schema))
        (required 0)
        (optional 0)
        (mode :required)
        (keywordp nil))
    (dolist (entry args)
      (cond
        ((eq entry '&optional)
         (setf mode :optional))
        ((eq entry '&key)
         (setf keywordp t
               mode :key))
        ((member mode '(:required :optional))
         (ecase mode
           (:required (incf required))
           (:optional (incf optional))))))
    (values required
            (unless keywordp
              (+ required optional)))))

(defun %arguments-match-schema-p (input-schema values)
  (multiple-value-bind (min max)
      (%schema-arity-bounds input-schema)
    (let ((count (length values)))
      (and (>= count min)
           (or (null max)
               (<= count max))))))

(defun %normalize-row-arguments (row args)
  (let* ((argument-keys (runtime-callable-row-argument-keys row))
         (normalized-plist (%normalized-argument-plist args))
         (normalized-values (%normalized-argument-values args))
         (input-schema (runtime-callable-row-input-schema row)))
    (cond
      ((or (null argument-keys)
           (equal (second input-schema) :algorithm-specific))
       (values t normalized-values nil))
      (t
       (multiple-value-bind (required-count max-count)
           (%schema-arity-bounds input-schema)
         (let* ((supplied-keys (loop for key in normalized-plist by #'cddr
                                     collect key))
                (unknown-keys (set-difference supplied-keys argument-keys))
                (required-keys (subseq argument-keys 0 required-count)))
           (cond
             (unknown-keys
              (values nil
                      nil
                      (list :reason :unknown-argument-key
                            :unknown-keys unknown-keys
                            :allowed-keys argument-keys)))
             ((not (every (lambda (key)
                            (member key supplied-keys))
                          required-keys))
              (values nil
                      nil
                      (list :reason :missing-required-arguments
                            :required-keys required-keys
                            :supplied-keys supplied-keys)))
             (t
              (let ((ordered-values
                      (loop for key in argument-keys
                            collect (if (member key supplied-keys)
                                        (getf normalized-plist key)
                                        nil))))
                (if (%arguments-match-schema-p input-schema ordered-values)
                    (values t ordered-values nil)
                    (values nil
                            nil
                            (list :reason :schema-mismatch
                                  :required-count required-count
                                  :max-count max-count
                                  :supplied-keys supplied-keys
                                  :input-schema input-schema))))))))))))

(defun plan-formal-capability-invocation
    (operation-id &key capability mutation-kind caller-class args)
  (let* ((capability* (or capability (current-formal-capability-class)))
         (operation (find-formal-capability-operation
                     (formal-capability-class-operations capability*)
                     operation-id))
         (policy (formal-capability-class-admission-policy capability*)))
    (cond
      ((null operation)
       (make-formal-capability-plan
        :operation-id operation-id
        :admissible-p nil
        :reason :unknown-operation
        :mutation-kind mutation-kind
        :diagnostics (list :caller-class caller-class)))
      ((and mutation-kind
            (member mutation-kind
                    (formal-admission-policy-forbidden-mutations policy)))
       (make-formal-capability-plan
        :operation-id operation-id
        :admissible-p nil
        :reason :forbidden-mutation
        :operation operation
        :mutation-kind mutation-kind
        :diagnostics (list :caller-class caller-class)))
      ((and caller-class
            (not (member caller-class
                         (formal-capability-operation-admissible-caller-classes
                          operation))))
       (make-formal-capability-plan
        :operation-id operation-id
        :admissible-p nil
        :reason :caller-class-not-admitted
        :operation operation
        :mutation-kind mutation-kind
        :diagnostics (list :caller-class caller-class
                           :allowed
                           (formal-capability-operation-admissible-caller-classes
                            operation))))
      ((not (member (runtime-callable-row-evidence-kind
                     (formal-capability-operation-callable-row operation))
                    (formal-admission-policy-required-evidence policy)))
       (make-formal-capability-plan
        :operation-id operation-id
        :admissible-p nil
        :reason :unsupported-evidence
        :operation operation
        :mutation-kind mutation-kind
        :diagnostics (list :caller-class caller-class)))
      (t
       (multiple-value-bind (admissible-p ordered-values issue)
           (%normalize-row-arguments
            (formal-capability-operation-callable-row operation)
            args)
         (declare (ignore ordered-values))
         (if admissible-p
             (make-formal-capability-plan
              :operation-id operation-id
              :admissible-p t
              :reason :admitted
              :operation operation
              :mutation-kind mutation-kind
              :diagnostics (list :caller-class caller-class
                                 :argument-keys
                                 (runtime-callable-row-argument-keys
                                  (formal-capability-operation-callable-row operation))))
             (make-formal-capability-plan
              :operation-id operation-id
              :admissible-p nil
              :reason (getf issue :reason)
              :operation operation
              :mutation-kind mutation-kind
              :diagnostics (list* :caller-class caller-class issue))))))))

(defun check-formal-capability-invocation
    (operation-id &key capability mutation-kind caller-class args)
  (formal-capability-plan-admissible-p
   (plan-formal-capability-invocation
    operation-id
    :capability capability
    :mutation-kind mutation-kind
    :caller-class caller-class
    :args args)))

(defun invoke-formal-capability
    (operation-id &rest args &key capability mutation-kind caller-class &allow-other-keys)
  (let* ((capability* (or capability (current-formal-capability-class)))
         (plan (plan-formal-capability-invocation
                operation-id
                :capability capability*
                :mutation-kind mutation-kind
                :caller-class caller-class
                :args args)))
    (unless (formal-capability-plan-admissible-p plan)
      (return-from invoke-formal-capability
        (make-formal-capability-result
         :operation-id operation-id
         :status :rejected
         :rejection-reason (formal-capability-plan-reason plan)
         :diagnostics (formal-capability-plan-diagnostics plan))))
    (let* ((operation (formal-capability-plan-operation plan))
           (row (formal-capability-operation-callable-row operation))
           (ordered-values
             (multiple-value-bind (admissible-p values issue)
                 (%normalize-row-arguments row args)
               (declare (ignore issue))
               (unless admissible-p
                 (error "formal capability invocation admitted but failed to normalize arguments for ~S"
                        operation-id))
               values))
           (payload
             (apply (symbol-function (runtime-callable-row-callable row))
                    ordered-values)))
      (make-formal-capability-result
       :operation-id (formal-capability-operation-id operation)
       :status :accepted
       :evidence-kind (runtime-callable-row-evidence-kind row)
       :payload payload
       :trusted-boundaries
       (copy-list (formal-capability-operation-trusted-boundaries operation))
       :diagnostics (formal-capability-plan-diagnostics plan)))))

(defun formal-capability-operations-for-constraint-class
    (constraint-class-id &optional (capability (current-formal-capability-class)))
  (find-formal-capability-operations-by-constraint-class
   (formal-capability-class-operations capability)
   constraint-class-id))

(defun %resolve-formal-constraint-class-operation (constraint-class-id capability)
  (let* ((constraint
           (find constraint-class-id
                 (formal-capability-class-constraint-classes capability)
                 :key #'formal-constraint-class-id
                 :test #'equal))
         (operations
           (and constraint
                (formal-capability-operations-for-constraint-class
                 constraint-class-id capability))))
    (values
     constraint
     (cond
       ((null operations) nil)
       ((= (length operations) 1) (first operations))
       (constraint
        (or
         (find (formal-constraint-class-callable constraint)
               operations
               :key #'formal-capability-operation-id
               :test #'eq)
         (find (formal-constraint-class-callable constraint)
               operations
               :key (lambda (operation)
                      (runtime-callable-row-callable
                       (formal-capability-operation-callable-row operation)))
               :test #'eq)))
       (t nil))
     operations)))

(defun invoke-formal-constraint-class
    (constraint-class-id &rest args &key capability caller-class mutation-kind &allow-other-keys)
  (let* ((capability* (or capability (current-formal-capability-class)))
         (constraint nil)
         (resolved-operation nil)
         (operations nil))
    (multiple-value-setq (constraint resolved-operation operations)
      (%resolve-formal-constraint-class-operation constraint-class-id capability*))
    (cond
      ((null constraint)
       (make-formal-capability-result
        :operation-id constraint-class-id
        :status :rejected
        :rejection-reason :unknown-constraint-class
        :diagnostics (list :constraint-class-id constraint-class-id)))
      ((null resolved-operation)
       (make-formal-capability-result
        :operation-id constraint-class-id
        :status :rejected
        :rejection-reason :ambiguous-constraint-class
        :diagnostics (list :constraint-class-id constraint-class-id
                           :candidate-operations
                           (mapcar #'formal-capability-operation-id operations))))
      (t
       (apply #'invoke-formal-capability
              (formal-capability-operation-id resolved-operation)
              :capability capability*
              :caller-class caller-class
              :mutation-kind mutation-kind
              args)))))

(defun evaluate-formal-synthesis-scenario
    (&optional (capability (current-formal-capability-class)))
  (let* ((kernel-spec (make-frozen-kernel-core-spec))
         (kernel-plan
           (plan-formal-capability-invocation
            :check-kernel-spec-kr
            :capability capability
            :caller-class :synth
            :args (list :spec kernel-spec)))
         (bridge-plan
           (plan-formal-capability-invocation
            :j-smt-admitted-obligation-bridge
            :capability capability
            :caller-class :synth
            :args (list :obligation-id :o-closed-boolean-unsat
                        :formula '(:and (:bool t) (:not (:bool t))))))
         (kernel-result
           (invoke-formal-capability
            :check-kernel-spec-kr
            :caller-class :synth
            :spec kernel-spec))
         (bridge-result
           (invoke-formal-capability
            :j-smt-admitted-obligation-bridge
            :caller-class :synth
            :obligation-id :o-closed-boolean-unsat
            :formula '(:and (:bool t) (:not (:bool t))))))
     (list
     :kernel-plan (formal-capability-plan-admissible-p kernel-plan)
     :bridge-plan (formal-capability-plan-admissible-p bridge-plan)
     :kernel-status (formal-capability-result-status kernel-result)
     :bridge-status (formal-capability-result-status bridge-result)
     :kernel-operation :check-kernel-spec-kr
     :bridge-operation :j-smt-admitted-obligation-bridge
     :admissiblep (and (formal-capability-plan-admissible-p kernel-plan)
                       (formal-capability-plan-admissible-p bridge-plan)
                       (eq :accepted (formal-capability-result-status kernel-result))
                       (eq :accepted (formal-capability-result-status bridge-result))))))

(defun formal-capability-manifest-object
    (&optional (capability (current-formal-capability-class)))
  (list
   (cons "id" (%runtime-name-string (formal-capability-class-id capability)))
   (cons "operations"
         (mapcar (lambda (operation)
                   (let ((row (formal-capability-operation-callable-row operation)))
                     (list
                      (cons "id"
                            (%runtime-name-string
                             (formal-capability-operation-id operation)))
                      (cons "callable_row_name"
                            (runtime-callable-row-name row))
                      (cons "argument_keys"
                            (mapcar #'%runtime-name-string
                                    (runtime-callable-row-argument-keys row)))
                      (cons "input_schema" (runtime-callable-row-input-schema row))
                      (cons "output_schema" (runtime-callable-row-output-schema row))
                      (cons "effect_kind"
                            (%runtime-name-string
                             (runtime-callable-row-effect-kind row)))
                      (cons "evidence_kind"
                            (%runtime-name-string
                             (runtime-callable-row-evidence-kind row)))
                      (cons "trusted_boundaries"
                            (mapcar #'%runtime-name-string
                                    (formal-capability-operation-trusted-boundaries
                                     operation)))
                     (cons "constraint_classes"
                            (mapcar #'%runtime-name-string
                                    (formal-capability-operation-constraint-classes
                                     operation)))
                      (cons "required_evidence"
                            (mapcar #'%runtime-name-string
                                    (formal-capability-operation-required-evidence
                                     operation)))
                      (cons "admissible_caller_classes"
                            (mapcar #'%runtime-name-string
                                    (formal-capability-operation-admissible-caller-classes
                                     operation))))))
                 (formal-capability-class-operations capability)))
   (cons "required_evidence"
         (mapcar #'%runtime-name-string
                 (formal-admission-policy-required-evidence
                  (formal-capability-class-admission-policy capability))))
   (cons "forbidden_mutations"
         (mapcar #'%runtime-name-string
                 (formal-admission-policy-forbidden-mutations
                  (formal-capability-class-admission-policy capability))))
   (cons "cegis_families" (list-cegis-family-manifest-objects))
   (cons "cegis_spaces" (mapcar #'cegis-artifact-json-object
                                (list-cegis-spaces)))
   (cons "cegis_search_irs" (mapcar #'cegis-artifact-json-object
                                    (list-cegis-search-irs)))
   (cons "compiler_families" (list-compiler-families))
   (cons "compiler_obligation_kinds" (list-compiler-obligation-kinds))
   (cons "search_evidence_statuses" (list-search-evidence-statuses))
   (cons "search_evidence_frontier_ops"
         (list "search/evaluate-evidence-frontier"
               "search/evaluate-supersession-consistency"))
   (cons "search_legality_clauses" (list-search-legality-clauses))
   (cons "search_operator_classes" (list-search-operator-classes))
   (cons "search_obligation_kinds" (list-search-kernel-obligation-kinds))
   (cons "search_admission_laws" (list-search-admission-laws))
   (cons "closure_status" (closure-backlog-summary))))

(defun %kernel-core-algorithm-manifest (entry)
  (list
   (cons "id" (%runtime-name-string (kernel-core-algorithm-id entry)))
   (cons "layer" (%runtime-name-string (kernel-core-algorithm-layer entry)))
   (cons "status" (%runtime-name-string (kernel-core-algorithm-status entry)))
   (cons "theorem_target" (%runtime-name-string (kernel-core-algorithm-theorem-target entry)))
   (cons "callable" (%runtime-name-string (kernel-core-algorithm-callable entry)))
   (cons "note" (kernel-core-algorithm-note entry))))

(defun %smt-core-algorithm-manifest (entry)
  (list
   (cons "id" (%runtime-name-string (smt-core-algorithm-id entry)))
   (cons "layer" (%runtime-name-string (smt-core-algorithm-layer entry)))
   (cons "status" (%runtime-name-string (smt-core-algorithm-status entry)))
   (cons "theorem_target" (%runtime-name-string (smt-core-algorithm-theorem-target entry)))
   (cons "callable" (%runtime-name-string (smt-core-algorithm-callable entry)))
   (cons "note" (smt-core-algorithm-note entry))))

(defun %admitted-obligation-manifest (entry)
  (list
   (cons "id" (%runtime-name-string (admitted-obligation-class-id entry)))
   (cons "source_lane" (%runtime-name-string (admitted-obligation-class-source-lane entry)))
   (cons "target_lane" (%runtime-name-string (admitted-obligation-class-target-lane entry)))
   (cons "smt_obligation_class_id"
         (%runtime-name-string
          (admitted-obligation-class-smt-obligation-class-id entry)))
   (cons "result_polarity"
         (%runtime-name-string (admitted-obligation-class-result-polarity entry)))
   (cons "theorem_target"
         (%runtime-name-string (admitted-obligation-class-theorem-target entry)))
   (cons "statement" (admitted-obligation-class-statement entry))))

(defun %theorem-bridge-binding-manifest (entry)
  (list
   (cons "theorem_obligation_id"
         (%runtime-name-string
          (theorem-bridge-binding-theorem-obligation-id entry)))
   (cons "admitted_obligation_id"
         (%runtime-name-string
          (theorem-bridge-binding-admitted-obligation-id entry)))
   (cons "result_polarity"
         (%runtime-name-string (theorem-bridge-binding-result-polarity entry)))
   (cons "note" (theorem-bridge-binding-note entry))))

(defun make-runtime-constitution-manifests
    (&key (kernel-algorithms (list-kernel-core-algorithms))
          (smt-algorithms (list-smt-core-algorithms))
          (admitted-obligations (list-admitted-obligation-classes))
          (theorem-bindings (list-theorem-bridge-bindings))
          (closure-backlog *closure-backlog*))
  (list
   (cons "kernel_core_algorithms"
         (mapcar #'%kernel-core-algorithm-manifest kernel-algorithms))
   (cons "smt_core_algorithms"
         (mapcar #'%smt-core-algorithm-manifest smt-algorithms))
   (cons "admitted_obligations"
         (mapcar #'%admitted-obligation-manifest admitted-obligations))
   (cons "theorem_bridge_bindings"
         (mapcar #'%theorem-bridge-binding-manifest theorem-bindings))
   (cons "closure_backlog"
         (mapcar (lambda (entry)
                   (list
                    (cons "id" (%runtime-name-string (closure-backlog-entry-id entry)))
                    (cons "lane" (%runtime-name-string (closure-backlog-entry-lane entry)))
                    (cons "current_status"
                          (%runtime-name-string
                           (closure-backlog-entry-current-status entry)))
                    (cons "target_relation"
                          (%runtime-name-string
                           (closure-backlog-entry-target-relation entry)))
                    (cons "required_theorem"
                          (%runtime-name-string
                           (closure-backlog-entry-required-theorem entry)))
                    (cons "blocking_dependency"
                          (and (closure-backlog-entry-blocking-dependency entry)
                               (%runtime-name-string
                                (closure-backlog-entry-blocking-dependency entry))))
                    (cons "dependencies"
                          (mapcar #'%runtime-name-string
                                  (closure-backlog-entry-dependencies entry)))
                    (cons "notes" (closure-backlog-entry-notes entry))))
                 closure-backlog))))

(defun %runtime-constitution-machine-state
    (&key authority-ref machine-ref manifests registry-digest capability-classes)
  (let ((callable-rows (%sort-runtime-callable-rows
                        (loop for capability in capability-classes
                              append (copy-list
                                      (runtime-capability-class-callable-rows capability))))))
    (list
     :j (list :authority-ref authority-ref
              :manifest-digest (artifact-digest manifests)
              :manifest-count (length manifests))
     :l (list :machine-ref machine-ref
              :callable-count (length callable-rows)
              :capability-count (length capability-classes))
     :r (list :rehydration-kind :registry-manifest
              :registry-digest registry-digest
              :alignment-targets '(:lsip-j :lsip-l :lsip-r :lsip-s))
     :s (list :synchronization-kind :registry-snapshot
              :closure-summary (closure-backlog-summary)))))

(defun %runtime-constitution-source-object (authority-ref machine-ref)
  (let* ((kernel-algorithms (list-kernel-core-algorithms))
         (smt-algorithms (list-smt-core-algorithms))
         (admitted-obligations (list-admitted-obligation-classes))
         (theorem-bindings (list-theorem-bridge-bindings))
         (closure-backlog *closure-backlog*)
         (audit-ids (sort (mapcar #'car *theorem-audit-runners*)
                          #'string<
                          :key #'%runtime-name-string))
         (manifests (make-runtime-constitution-manifests
                     :kernel-algorithms kernel-algorithms
                     :smt-algorithms smt-algorithms
                     :admitted-obligations admitted-obligations
                     :theorem-bindings theorem-bindings
                     :closure-backlog closure-backlog)))
    (list
     (cons "authority_ref" authority-ref)
     (cons "machine_ref" machine-ref)
     (cons "manifests" manifests)
     (cons "kernel_algorithm_ids"
           (mapcar (lambda (entry) (%runtime-name-string (kernel-core-algorithm-id entry)))
                   kernel-algorithms))
     (cons "smt_algorithm_ids"
           (mapcar (lambda (entry) (%runtime-name-string (smt-core-algorithm-id entry)))
                   smt-algorithms))
     (cons "admitted_obligation_ids"
           (mapcar (lambda (entry)
                     (%runtime-name-string (admitted-obligation-class-id entry)))
                   admitted-obligations))
     (cons "theorem_binding_ids"
           (mapcar (lambda (entry)
                     (%runtime-name-string
                      (theorem-bridge-binding-theorem-obligation-id entry)))
                   theorem-bindings))
     (cons "closure_backlog_ids"
           (mapcar (lambda (entry) (%runtime-name-string (closure-backlog-entry-id entry)))
                   closure-backlog))
     (cons "audit_ids" audit-ids))))

(defun runtime-constitution-id-for-state
    (&key (authority-ref "formal://constitution")
          (machine-ref "formal://live-runtime"))
  (let* ((source (%runtime-constitution-source-object authority-ref machine-ref))
         (digest (artifact-digest source)))
    (format nil "runtime-constitution:~A:~X"
            machine-ref
            digest)))

(defun %register-runtime-callable-row (table row)
  (setf (gethash (runtime-callable-row-name row) table) row)
  row)

(defun %base-runtime-callable-rows ()
  (list
   (make-runtime-callable-row
    :operation-id :current-runtime-constitution
    :name "constitution/current-runtime-constitution"
    :callable 'current-runtime-constitution
    :kind :constitution
    :lane :formal
    :ref-id :current-runtime-constitution
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :runtime-constitution
    :effect-kind :read
    :evidence-kind :constitution-state
    :note "Rehydrate the current FORMAL runtime constitution from live registries.")
   (make-runtime-callable-row
    :operation-id :runtime-constitution-witness-object
    :name "constitution/runtime-constitution-witness-object"
    :callable 'runtime-constitution-witness-object
    :kind :constitution
    :lane :formal
    :ref-id :runtime-constitution-witness
    :argument-keys '(:runtime-constitution)
    :input-schema '(:args (runtime-constitution))
    :output-schema :constitutional-witness
    :effect-kind :read
    :evidence-kind :constitution-state
    :note "Project the current FORMAL constitution into an LSIP-ingestible witness object.")
   (make-runtime-callable-row
    :operation-id :current-formal-capability-class
    :name "capability/current-formal-capability-class"
    :callable 'current-formal-capability-class
    :kind :capability
    :lane :formal
    :ref-id :formal-capability-class
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :formal-capability-class
    :effect-kind :read
    :evidence-kind :constitution-state
    :note "Resolve the synthesis-facing FORMAL capability class.")
   (make-runtime-callable-row
    :operation-id :evaluate-formal-capability-report
    :name "capability/evaluate-formal-capability-report"
    :callable 'evaluate-formal-capability-report
    :kind :capability
    :lane :formal
    :ref-id :formal-capability-report
    :argument-keys '(:capability)
    :input-schema '(:args (&optional formal-capability-class))
    :output-schema :formal-capability-report
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Report the current FORMAL capability surface, constraints, and admission policy.")
   (make-runtime-callable-row
    :operation-id :check-kernel-spec-kr
    :name "kernel/check-kernel-spec-kr"
    :callable 'check-kernel-spec-kr
    :kind :kernel-service
    :lane :kernel
    :ref-id :kr
    :argument-keys '(:spec :reference-env)
    :input-schema '(:args (kernel-spec &optional reference-env))
    :output-schema :kernel-status
    :effect-kind :check
    :evidence-kind :kernel-status
    :note "Reference-kernel evaluation over shared kernel-spec carriers.")
   (make-runtime-callable-row
    :operation-id :check-kernel-spec-kl
    :name "kernel/check-kernel-spec-kl"
    :callable 'check-kernel-spec-kl
    :kind :kernel-service
    :lane :kernel
    :ref-id :kl
    :argument-keys '(:spec)
    :input-schema '(:args (kernel-spec))
    :output-schema :kernel-status
    :effect-kind :check
    :evidence-kind :kernel-status
    :note "Implementation-kernel evaluation over shared kernel-spec carriers.")
   (make-runtime-callable-row
    :operation-id :check-kernel-spec-defir
    :name "kernel/check-kernel-spec-defir"
    :callable 'check-kernel-spec-defir
    :kind :kernel-service
    :lane :kernel
    :ref-id :defir
    :argument-keys '(:spec)
    :input-schema '(:args (kernel-spec))
    :output-schema :kernel-status
    :effect-kind :check
    :evidence-kind :kernel-status
    :note "DefIR-backed kernel evaluation over shared kernel-spec carriers.")
   (make-runtime-callable-row
    :operation-id :compare-kernel-spec-kr-kl-defir
    :name "kernel/compare-kernel-spec-kr-kl-defir"
    :callable 'compare-kernel-spec-kr-kl-defir
    :kind :kernel-service
    :lane :kernel
    :ref-id :kr-kl-defir-parity
    :argument-keys '(:spec :reference-env)
    :input-schema '(:args (kernel-spec &optional reference-env))
    :output-schema :parity-report
    :effect-kind :check
    :evidence-kind :parity-report
    :note "Three-lane KR/KL/DefIR parity over shared kernel-spec carriers.")
   (make-runtime-callable-row
    :operation-id :run-smt-check
    :name "smt/run-smt-check"
    :callable 'run-smt-check
    :kind :smt-service
    :lane :smt
    :ref-id :runtime
    :argument-keys '(:store :query)
    :input-schema '(:args (advisory-store query))
    :output-schema :smt-status
    :effect-kind :check
    :evidence-kind :bridge-status
    :note "Primary SMT runtime entrypoint on the admitted Bool/BV/Int fragment.")
   (make-runtime-callable-row
    :operation-id :check-smt-spec
    :name "smt/check-smt-spec"
    :callable 'check-smt-spec
    :kind :smt-service
    :lane :smt
    :ref-id :native-spec
    :argument-keys '(:spec)
    :input-schema '(:args (smt-spec))
    :output-schema :smt-status
    :effect-kind :check
    :evidence-kind :bridge-status
    :note "Native Lisp-authored SMT specification checking.")
   (make-runtime-callable-row
    :operation-id :run-smt-cegis
    :name "cegis/run-smt-cegis"
    :callable 'run-smt-cegis
    :kind :cegis-service
    :lane :smt
    :ref-id :cegis
    :argument-keys '(:problem :state :max-iterations)
    :input-schema '(:args (smt-cegis-problem &optional cegis-run-state integer))
    :output-schema :cegis-run-state
    :effect-kind :synthesis
    :evidence-kind :cegis-state
    :note "Counterexample-guided synthesis over the admitted SMT constraint fragment.")
   (make-runtime-callable-row
    :operation-id :run-lsip-edge-policy-cegis
    :name "cegis/run-lsip-edge-policy-cegis"
    :callable 'run-lsip-edge-policy-cegis
    :kind :cegis-service
    :lane :lsip
    :ref-id :cegis
    :argument-keys '(:problem :state :max-iterations)
    :input-schema '(:args (lsip-edge-policy-cegis-problem &optional cegis-run-state integer))
   :output-schema :cegis-run-state
   :effect-kind :synthesis
   :evidence-kind :cegis-state
   :note "Counterexample-guided synthesis over LSIP edge-policy law selection.")
   (make-runtime-callable-row
    :operation-id :run-compiler-mutation-cegis
    :name "cegis/run-compiler-mutation-cegis"
    :callable 'run-compiler-mutation-cegis
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis
    :argument-keys '(:problem :state :max-iterations)
    :input-schema '(:args (compiler-mutation-cegis-problem &optional cegis-run-state integer))
    :output-schema :cegis-run-state
    :effect-kind :synthesis
    :evidence-kind :cegis-state
    :note "Counterexample-guided synthesis over compiler-search mutation constraints.")
   (make-runtime-callable-row
    :operation-id :run-cegis-family
    :name "cegis/run-cegis-family"
    :callable 'run-cegis-family
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis
    :argument-keys '(:family :problem :state :max-iterations)
    :input-schema '(:args (cegis-family-id cegis-problem &optional cegis-run-state integer))
    :output-schema :cegis-run-state
    :effect-kind :synthesis
    :evidence-kind :cegis-state
    :note "Generic manifest-indexed CEGIS family dispatch.")
   (make-runtime-callable-row
    :operation-id :run-cegis-step
    :name "cegis/run-cegis-step"
    :callable 'run-cegis-step-artifact
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-step
    :argument-keys '(:problem :state)
    :input-schema '(:args (cegis-problem &optional cegis-run-state))
    :output-schema :cegis-step-artifact
    :effect-kind :synthesis
    :evidence-kind :cegis-state
    :note "Run one CEGIS iteration and return the state plus trace-step artifact.")
   (make-runtime-callable-row
    :operation-id :run-cegis-trace
    :name "cegis/run-cegis-trace"
    :callable 'run-cegis-trace
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-trace
    :argument-keys '(:family :problem :state :max-iterations)
    :input-schema '(:args (cegis-family-id cegis-problem &optional cegis-run-state integer))
    :output-schema :cegis-trace
    :effect-kind :synthesis
    :evidence-kind :cegis-trace
    :note "Run a manifest-indexed CEGIS family and return replayable trace evidence.")
   (make-runtime-callable-row
    :operation-id :replay-cegis-trace
    :name "cegis/replay-cegis-trace"
    :callable 'replay-cegis-trace
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-trace-replay
    :argument-keys '(:problem :trace)
    :input-schema '(:args (cegis-problem cegis-trace))
    :output-schema :cegis-replay-report
    :effect-kind :check
    :evidence-kind :cegis-trace
    :note "Replay recorded CEGIS refinements against the problem semantics.")
   (make-runtime-callable-row
    :operation-id :list-cegis-family-manifests
    :name "cegis/list-cegis-family-manifests"
    :callable 'list-cegis-family-manifest-objects
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-manifest
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :cegis-family-manifest-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen CEGIS family and refinement manifest catalog.")
   (make-runtime-callable-row
    :operation-id :list-cegis-spaces
    :name "cegis/list-cegis-spaces"
    :callable 'list-cegis-spaces
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-space
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :cegis-space-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return first-class CEGIS search spaces derived from the family catalog.")
   (make-runtime-callable-row
    :operation-id :describe-cegis-space
    :name "cegis/describe-cegis-space"
    :callable 'describe-cegis-space
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-space
    :argument-keys '(:family)
    :input-schema '(:args (cegis-family-id))
   :output-schema :cegis-space
   :effect-kind :read
   :evidence-kind :audit-result
   :note "Return the first-class CEGIS search space for one family.")
   (make-runtime-callable-row
    :operation-id :list-cegis-search-irs
    :name "cegis/list-cegis-search-irs"
    :callable 'list-cegis-search-irs
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-search-ir
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :cegis-search-ir-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return family-indexed search/projection IR objects for the public CEGIS surface.")
   (make-runtime-callable-row
    :operation-id :describe-cegis-search-ir
    :name "cegis/describe-cegis-search-ir"
    :callable 'describe-cegis-search-ir
    :kind :cegis-service
    :lane :formal
    :ref-id :cegis-search-ir
    :argument-keys '(:family)
   :input-schema '(:args (cegis-family-id))
    :output-schema :cegis-search-ir
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the explicit search/projection IR for one CEGIS family.")
   (make-runtime-callable-row
    :operation-id :list-compiler-families
    :name "compiler/list-families"
    :callable 'list-compiler-families
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-family
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :compiler-family-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen compiler-family catalog for the executable compiler lane.")
   (make-runtime-callable-row
    :operation-id :describe-compiler-family
    :name "compiler/describe-family"
    :callable 'describe-compiler-family
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-family
    :argument-keys '(:family)
    :input-schema '(:args (compiler-family-id))
    :output-schema :compiler-family
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Describe one registered compiler family and its adapter surface.")
   (make-runtime-callable-row
    :operation-id :list-compiler-obligation-kinds
    :name "compiler/list-obligation-kinds"
    :callable 'list-compiler-obligation-kinds
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-obligation-kind
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :compiler-obligation-kind-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen compiler obligation catalog for the generic compiler-family lane.")
   (make-runtime-callable-row
    :operation-id :check-compiler-schema
    :name "compiler/check-schema"
    :callable 'check-compiler-schema
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id)
    :input-schema '(:args (compiler-family-id &optional t t))
    :output-schema :compiler-check-result
    :effect-kind :check
    :evidence-kind :compiler-check-result
   :note "Check family entrypoints, field-layout contracts, and core artifact formation for one compiler family.")
   (make-runtime-callable-row
    :operation-id :check-compiler-control-determinism
    :name "compiler/check-control-determinism"
    :callable 'check-compiler-control-determinism
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id)
    :input-schema '(:args (compiler-family-id &optional t t))
    :output-schema :compiler-check-result
    :effect-kind :check
    :evidence-kind :compiler-check-result
    :note "Check that repeated compiler-family evaluation yields stable artifacts for a fixed source/control input.")
   (make-runtime-callable-row
    :operation-id :check-compiler-lowering-totality
    :name "compiler/check-lowering-totality"
    :callable 'check-compiler-lowering-totality
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id)
    :input-schema '(:args (compiler-family-id &optional t t))
   :output-schema :compiler-check-result
   :effect-kind :check
   :evidence-kind :compiler-check-result
    :note "Check that each declared compiler lowering edge produces a non-null, well-typed artifact.")
   (make-runtime-callable-row
    :operation-id :check-compiler-installed-generation
    :name "compiler/check-installed-generation"
    :callable 'check-compiler-installed-generation
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id)
    :input-schema '(:args (compiler-family-id &optional t t))
    :output-schema :compiler-check-result
    :effect-kind :check
    :evidence-kind :compiler-check-result
    :note "Check that installed-generation artifacts agree with the source-side action and step artifacts.")
   (make-runtime-callable-row
    :operation-id :check-compiler-layout
    :name "compiler/check-layout"
    :callable 'check-compiler-layout
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id)
    :input-schema '(:args (compiler-family-id &optional t t))
    :output-schema :compiler-check-result
    :effect-kind :check
    :evidence-kind :compiler-check-result
    :note "Check monotone assembly layout and label-PC consistency for one compiler family.")
   (make-runtime-callable-row
    :operation-id :check-compiler-roundtrip
    :name "compiler/check-roundtrip"
    :callable 'check-compiler-roundtrip
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id)
    :input-schema '(:args (compiler-family-id &optional t t))
    :output-schema :compiler-check-result
    :effect-kind :check
    :evidence-kind :compiler-check-result
    :note "Check encode/decode parity for the registered compiler family and selected carrier.")
   (make-runtime-callable-row
    :operation-id :check-compiler-image-closure
    :name "compiler/check-image-closure"
    :callable 'check-compiler-image-closure
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id)
    :input-schema '(:args (compiler-family-id &optional t t))
    :output-schema :compiler-check-result
    :effect-kind :check
    :evidence-kind :compiler-check-result
    :note "Check resident compiler-image closure for the registered compiler family.")
   (make-runtime-callable-row
    :operation-id :check-compiler-trace-parity
    :name "compiler/check-trace-parity"
    :callable 'check-compiler-trace-parity
    :kind :compiler-service
    :lane :formal
    :ref-id :compiler-check-result
    :argument-keys '(:family :source-id :control-id :limit)
    :input-schema '(:args (compiler-family-id &optional t t integer))
    :output-schema :compiler-check-result
    :effect-kind :check
    :evidence-kind :compiler-check-result
    :note "Check bounded trace coherence and alternate-trace parity for the registered compiler family.")
   (make-runtime-callable-row
    :operation-id :list-search-evidence-statuses
    :name "search/list-evidence-statuses"
    :callable 'list-search-evidence-statuses
    :kind :search-service
    :lane :formal
    :ref-id :search-evidence-status
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :search-evidence-status-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen evidence-status lattice for the first search-kernel closure slice.")
   (make-runtime-callable-row
    :operation-id :list-search-legality-clauses
    :name "search/list-legality-clauses"
    :callable 'list-search-legality-clauses
    :kind :search-service
    :lane :formal
    :ref-id :search-legality-clause
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :search-legality-clause-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen legality-clause catalog for the first legal-transition slice.")
   (make-runtime-callable-row
    :operation-id :list-search-operator-classes
    :name "search/list-operator-classes"
    :callable 'list-search-operator-classes
    :kind :search-service
    :lane :formal
    :ref-id :search-operator-class
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :search-operator-class-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen search operator-class catalog for the first legal-transition slice.")
   (make-runtime-callable-row
    :operation-id :list-search-kernel-obligation-kinds
    :name "search/list-formal-obligation-kinds"
    :callable 'list-search-kernel-obligation-kinds
    :kind :search-service
    :lane :formal
    :ref-id :search-obligation-kind
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :search-obligation-kind-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen obligation-kind catalog for the first search-kernel slice.")
   (make-runtime-callable-row
    :operation-id :list-search-admission-laws
    :name "search/list-admission-laws"
    :callable 'list-search-admission-laws
    :kind :search-service
    :lane :formal
    :ref-id :search-admission-law
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :search-admission-law-list
    :effect-kind :read
    :evidence-kind :audit-result
    :note "Return the frozen admission-law catalog for the first search-kernel slice.")
   (make-runtime-callable-row
    :operation-id :build-search-operator-instance
    :name "search/build-operator-instance"
    :callable 'build-search-operator-instance
    :kind :search-service
    :lane :formal
    :ref-id :search-operator-instance
    :argument-keys '(:operator-class :target-zone :source-operation :replay-token
                     :budget-row :metadata)
    :input-schema '(:args (search-operator-class t t
                           &key replay-token budget-row metadata))
    :output-schema :search-operator-instance
    :effect-kind :check
    :evidence-kind :search-operator-instance
    :note "Build a first-class search operator instance for the legality kernel.")
   (make-runtime-callable-row
    :operation-id :build-search-formal-obligation
    :name "search/build-formal-obligation"
    :callable 'build-search-formal-obligation
    :kind :search-service
    :lane :formal
    :ref-id :search-formal-obligation
    :argument-keys '(:kind :scope :projection-seed :source-operation :status :metadata)
    :input-schema '(:args (search-obligation-kind
                           &key scope projection-seed source-operation status metadata))
    :output-schema :search-formal-obligation
    :effect-kind :check
    :evidence-kind :search-obligation
    :note "Build a first-class formal obligation object for the search kernel.")
   (make-runtime-callable-row
    :operation-id :project-search-formal-obligation
    :name "search/project-formal-obligation"
    :callable 'project-search-formal-obligation
    :kind :search-service
    :lane :formal
    :ref-id :search-obligation-projection
    :argument-keys '(:obligation)
    :input-schema '(:args (search-formal-obligation))
    :output-schema :search-obligation-projection
    :effect-kind :check
    :evidence-kind :search-projection
    :note "Project a formal obligation into governed FORMAL payload rows.")
   (make-runtime-callable-row
    :operation-id :evaluate-search-bridge-totality
    :name "search/evaluate-bridge-totality"
    :callable 'evaluate-search-bridge-totality
    :kind :search-service
    :lane :formal
    :ref-id :search-bridge-totality-result
    :argument-keys '(:obligation :capability)
    :input-schema '(:args (search-formal-obligation &optional formal-capability-class))
    :output-schema :search-bridge-totality-result
    :effect-kind :check
    :evidence-kind :search-bridge-totality
    :note "Check that a hard search obligation projects to a governed FORMAL route.")
   (make-runtime-callable-row
    :operation-id :build-search-formal-evidence
    :name "search/build-formal-evidence"
    :callable 'build-search-formal-evidence
    :kind :search-service
    :lane :formal
    :ref-id :search-formal-evidence
    :argument-keys '(:obligation :judgment :certificate :freshness-status :resource-row :metadata)
    :input-schema '(:args (search-formal-obligation
                           &key judgment certificate freshness-status resource-row metadata))
    :output-schema :search-formal-evidence
    :effect-kind :check
    :evidence-kind :search-formal-evidence
    :note "Build evidence for one formal search obligation.")
   (make-runtime-callable-row
    :operation-id :apply-search-evidence-update
    :name "search/apply-evidence-update"
    :callable 'apply-search-evidence-update
    :kind :search-service
    :lane :formal
    :ref-id :search-evidence-update
    :argument-keys '(:state-id :evidence :prior-hard-debt :prior-advisory-debt
                     :prior-evidence-state)
    :input-schema '(:args (t t &key prior-hard-debt prior-advisory-debt
                           prior-evidence-state))
    :output-schema :search-evidence-update
    :effect-kind :check
    :evidence-kind :search-evidence-update
    :note "Apply monotone evidence closure for the first search-kernel slice.")
   (make-runtime-callable-row
    :operation-id :evaluate-search-evidence-monotonicity
    :name "search/evaluate-evidence-monotonicity"
    :callable 'evaluate-search-evidence-monotonicity
   :kind :search-service
    :lane :formal
    :ref-id :search-evidence-monotonicity-result
    :argument-keys '(:current :prior)
    :input-schema '(:args (t &optional t))
    :output-schema :search-evidence-monotonicity-result
    :effect-kind :check
    :evidence-kind :search-evidence-monotonicity
    :note "Audit append-only evidence evolution with explicit supersession coverage.")
   (make-runtime-callable-row
    :operation-id :evaluate-search-evidence-frontier
    :name "search/evaluate-evidence-frontier"
    :callable 'evaluate-search-evidence-frontier
    :kind :search-service
    :lane :formal
    :ref-id :search-evidence-frontier
    :argument-keys '(:state)
    :input-schema '(:args (t))
    :output-schema :search-evidence-frontier
    :effect-kind :check
    :evidence-kind :search-evidence-frontier
    :note "Compute the current per-obligation live frontier for an evidence-closed state.")
   (make-runtime-callable-row
    :operation-id :evaluate-search-supersession-consistency
    :name "search/evaluate-supersession-consistency"
    :callable 'evaluate-search-supersession-consistency
    :kind :search-service
    :lane :formal
    :ref-id :search-supersession-consistency-result
    :argument-keys '(:state)
    :input-schema '(:args (t))
    :output-schema :search-supersession-consistency-result
    :effect-kind :check
    :evidence-kind :search-supersession-consistency
    :note "Check that supersession links remain aligned with the live obligation frontier.")
   (make-runtime-callable-row
    :operation-id :evaluate-search-legal-transition
    :name "search/evaluate-legal-transition"
    :callable 'evaluate-search-legal-transition
    :kind :search-service
    :lane :formal
    :ref-id :search-legal-transition
    :argument-keys '(:operator-instance :state-id :capability :budget-ok-p :kernel-ok-p
                     :replay-ok-p)
    :input-schema '(:args (search-operator-instance t
                           &optional formal-capability-class t t t))
    :output-schema :search-legal-transition
    :effect-kind :check
    :evidence-kind :search-legal-transition
    :note "Evaluate legality over a search operator instance using the first governed legality kernel.")
   (make-runtime-callable-row
    :operation-id :evaluate-search-admission-law
    :name "search/evaluate-admission-law"
    :callable 'evaluate-search-admission-law
    :kind :search-service
    :lane :formal
    :ref-id :search-admission-result
    :argument-keys '(:law :state-id :evidence-update :touched-obligation-kinds)
    :input-schema '(:args (search-admission-law t search-evidence-update
                           &key touched-obligation-kinds))
    :output-schema :search-admission-result
    :effect-kind :check
    :evidence-kind :search-admission-result
    :note "Evaluate admit, quarantine, or reject on an evidence-closed search state.")
   (make-runtime-callable-row
    :operation-id :j-smt-admitted-obligation-bridge
    :name "bridge/j-smt-admitted-obligation-bridge"
    :callable 'j-smt-admitted-obligation-bridge
    :kind :bridge-service
    :lane :bridge
    :ref-id :admitted-obligation
    :argument-keys '(:obligation-id :formula :config)
    :input-schema '(:args (admitted-obligation-id formula &optional config))
    :output-schema :bridge-status
    :effect-kind :check
    :evidence-kind :bridge-status
    :note "Public admitted SMT bridge entrypoint.")
   (make-runtime-callable-row
    :operation-id :check-lsip-law
    :name "lsip/check-lsip-law"
    :callable 'check-lsip-law
    :kind :lsip-service
    :lane :lsip
    :ref-id :structural-lsip-law
    :argument-keys '(:law-id :relation)
    :input-schema '(:args (lsip-law-id lsip-relation))
    :output-schema :lsip-law-result
    :effect-kind :check
    :evidence-kind :lsip-law-result
    :note "Evaluate one registered structural LSIP law over a compiled relation.")
   (make-runtime-callable-row
    :operation-id :check-lsip-edge-gate
    :name "lsip/check-lsip-edge-gate"
    :callable 'check-lsip-edge-gate
   :kind :lsip-service
   :lane :lsip
   :ref-id :structural-lsip-edge-gate
    :argument-keys '(:edge-id :relation)
    :input-schema '(:args (lsip-edge-id lsip-relation))
    :output-schema :lsip-edge-gate-result
    :effect-kind :check
    :evidence-kind :lsip-law-result
    :note "Evaluate the prepared FORMAL gate for one LSIP lowering edge.")
   (make-runtime-callable-row
    :operation-id :evaluate-lsip-formal-preparation-report
    :name "lsip/evaluate-lsip-formal-preparation-report"
    :callable 'evaluate-lsip-formal-preparation-report
    :kind :lsip-service
    :lane :lsip
    :ref-id :lsip-formal-preparation-report
    :argument-keys '()
    :input-schema '(:args ())
    :output-schema :lsip-formal-preparation-report
    :effect-kind :audit
    :evidence-kind :lsip-law-result
    :note "Summarize current LSIP edge-preparation and FORMAL gate coverage.")
   (make-runtime-callable-row
    :operation-id :evaluate-metakernel-closure
    :name "audit/evaluate-metakernel-closure"
    :callable 'evaluate-metakernel-closure
    :kind :audit-service
    :lane :audit
    :ref-id :metakernel-closure
    :argument-keys '(:theorem-obligation-id)
    :input-schema '(:args (theorem-obligation-id))
    :output-schema :audit-result
    :effect-kind :audit
    :evidence-kind :audit-result
    :note "Evaluate selected metakernel closure obligations.")
   (make-runtime-callable-row
    :operation-id :evaluate-metakernel-closure-profile
    :name "audit/evaluate-metakernel-closure-profile"
    :callable 'evaluate-metakernel-closure-profile
    :kind :audit-service
    :lane :audit
    :ref-id :metakernel-closure-profile
    :argument-keys '(:closure-profile-id :config :max-depth :max-context-size :carrier-mode)
    :input-schema '(:args (closure-profile-id &key config max-depth max-context-size carrier-mode))
    :output-schema :audit-result
    :effect-kind :audit
    :evidence-kind :audit-result
    :note "Evaluate one frozen metakernel closure profile.")))

(defun make-formal-runtime-capability-class ()
  (let ((rows (make-hash-table :test #'equal)))
    (dolist (row (%base-runtime-callable-rows))
      (%register-runtime-callable-row rows row))
    (dolist (algorithm (list-kernel-core-algorithms))
      (%register-runtime-callable-row
       rows
       (make-runtime-callable-row
        :operation-id (kernel-core-algorithm-id algorithm)
        :name (format nil "kernel/~A"
                      (%runtime-name-string (kernel-core-algorithm-id algorithm)))
        :callable (kernel-core-algorithm-callable algorithm)
        :kind :kernel-algorithm
        :lane :kernel
        :ref-id (kernel-core-algorithm-id algorithm)
        :argument-keys nil
        :input-schema '(:args :algorithm-specific)
        :output-schema :kernel-term
        :effect-kind :compute
        :evidence-kind :kernel-status
        :note (kernel-core-algorithm-note algorithm))))
    (dolist (algorithm (list-smt-core-algorithms))
      (%register-runtime-callable-row
       rows
       (make-runtime-callable-row
        :operation-id (smt-core-algorithm-id algorithm)
        :name (format nil "smt/~A"
                      (%runtime-name-string (smt-core-algorithm-id algorithm)))
        :callable (smt-core-algorithm-callable algorithm)
        :kind :smt-algorithm
        :lane :smt
        :ref-id (smt-core-algorithm-id algorithm)
        :argument-keys nil
        :input-schema '(:args :algorithm-specific)
        :output-schema :smt-term
        :effect-kind :compute
        :evidence-kind :bridge-status
        :note (smt-core-algorithm-note algorithm))))
    (dolist (entry (list-admitted-obligation-classes))
      (%register-runtime-callable-row
       rows
       (make-runtime-callable-row
        :operation-id (admitted-obligation-class-id entry)
        :name (format nil "bridge/~A"
                      (%runtime-name-string (admitted-obligation-class-id entry)))
        :callable 'j-smt-admitted-obligation-bridge
        :kind :bridge-class
        :lane :bridge
        :ref-id (admitted-obligation-class-id entry)
        :argument-keys '(:formula :config)
        :input-schema '(:args (formula &optional config))
        :output-schema :bridge-status
        :effect-kind :check
        :evidence-kind :bridge-status
        :note (admitted-obligation-class-statement entry))))
    (dolist (binding (list-theorem-bridge-bindings))
      (%register-runtime-callable-row
       rows
       (make-runtime-callable-row
        :operation-id (theorem-bridge-binding-theorem-obligation-id binding)
        :name (format nil "audit/~A"
                      (%runtime-name-string
                       (theorem-bridge-binding-theorem-obligation-id binding)))
        :callable 'run-theorem-obligation-audit
        :kind :audit-obligation
        :lane :audit
        :ref-id (theorem-bridge-binding-theorem-obligation-id binding)
        :argument-keys '()
        :input-schema '(:args ())
        :output-schema :audit-result
        :effect-kind :audit
        :evidence-kind :audit-result
        :note (theorem-bridge-binding-note binding))))
    (make-runtime-capability-class
     :id :formal-runtime
     :lane :formal
     :authority-kind :constitutional
     :callable-rows (%sort-runtime-callable-rows
                     (loop for row being the hash-values of rows collect row))
     :semantic-contract
     '(:authority-surface :registry-backed
       :execution-surface :live-lisp
       :alignment-targets (:lsip-j :lsip-l :lsip-r :lsip-s)
       :capability-target :formal
       :note "FORMAL runtime constitution rehydrated from kernel, SMT, bridge, and closure registries.")
     :meta (list :kernel-count (length (list-kernel-core-algorithms))
                 :smt-count (length (list-smt-core-algorithms))
                 :admitted-obligation-count (length (list-admitted-obligation-classes))
                 :theorem-binding-count (length (list-theorem-bridge-bindings))
                 :closure-backlog-count (length *closure-backlog*)))))

(defun record-runtime-constitution (constitution)
  (setf (gethash (runtime-constitution-id constitution) *runtime-constitution-registry*)
        constitution)
  constitution)

(defun find-runtime-constitution (id)
  (gethash (%runtime-name-string id) *runtime-constitution-registry*))

(defun list-runtime-constitutions ()
  (sort (loop for value being the hash-values of *runtime-constitution-registry*
              collect value)
        #'string<
        :key #'runtime-constitution-id))

(defun reset-runtime-constitution-registry ()
  (clrhash *runtime-constitution-registry*))

(defun runtime-constitution-json-object (constitution)
  (list
   (cons "id" (runtime-constitution-id constitution))
   (cons "authority_ref" (runtime-constitution-authority-ref constitution))
   (cons "machine_ref" (runtime-constitution-machine-ref constitution))
   (cons "registry_digest" (runtime-constitution-registry-digest constitution))
   (cons "manifests" (runtime-constitution-manifests constitution))
   (cons "authority_state" (runtime-constitution-authority-state constitution))
   (cons "live_state" (runtime-constitution-live-state constitution))
   (cons "rehydration_state" (runtime-constitution-rehydration-state constitution))
   (cons "synchronization_state" (runtime-constitution-synchronization-state constitution))
   (cons "capability_classes"
         (mapcar #'runtime-capability-class-json-object
                 (runtime-constitution-capability-classes constitution)))
   (cons "kernel_algorithm_ids"
         (mapcar (lambda (entry) (%runtime-name-string (kernel-core-algorithm-id entry)))
                 (runtime-constitution-kernel-core-algorithms constitution)))
   (cons "smt_algorithm_ids"
         (mapcar (lambda (entry) (%runtime-name-string (smt-core-algorithm-id entry)))
                 (runtime-constitution-smt-core-algorithms constitution)))
   (cons "admitted_obligation_ids"
         (mapcar (lambda (entry)
                   (%runtime-name-string (admitted-obligation-class-id entry)))
                 (runtime-constitution-admitted-obligations constitution)))
   (cons "theorem_binding_ids"
         (mapcar (lambda (entry)
                   (%runtime-name-string
                    (theorem-bridge-binding-theorem-obligation-id entry)))
                 (runtime-constitution-theorem-bindings constitution)))
   (cons "closure_backlog_ids"
         (mapcar (lambda (entry)
                   (%runtime-name-string (closure-backlog-entry-id entry)))
                 (runtime-constitution-closure-backlog constitution)))
   (cons "callable_rows"
         (mapcar (lambda (row)
                   (list
                    (cons "name" (runtime-callable-row-name row))
                    (cons "callable" (%runtime-name-string (runtime-callable-row-callable row)))
                    (cons "kind" (%runtime-name-string (runtime-callable-row-kind row)))
                    (cons "lane" (%runtime-name-string (runtime-callable-row-lane row)))
                    (cons "ref_id"
                          (and (runtime-callable-row-ref-id row)
                               (%runtime-name-string (runtime-callable-row-ref-id row))))
                    (cons "note" (runtime-callable-row-note row))))
                 (runtime-constitution-callable-rows constitution)))
   (cons "meta" (runtime-constitution-meta constitution))))

(defun runtime-constitution-witness-object (constitution)
  (list
   (cons "constitution_id" (runtime-constitution-id constitution))
   (cons "authority_ref" (runtime-constitution-authority-ref constitution))
   (cons "machine_ref" (runtime-constitution-machine-ref constitution))
   (cons "registry_digest" (runtime-constitution-registry-digest constitution))
   (cons "omega_shape" (runtime-constitution-manifests constitution))
   (cons "omega_addr"
         (mapcar (lambda (row)
                   (list
                    (cons "name" (runtime-callable-row-name row))
                    (cons "lane" (%runtime-name-string (runtime-callable-row-lane row)))
                    (cons "kind" (%runtime-name-string (runtime-callable-row-kind row)))))
                 (runtime-constitution-callable-rows constitution)))
   (cons "omega_auth" (runtime-constitution-authority-state constitution))
   (cons "omega_trans"
         (list
          (cons "rehydration_state" (runtime-constitution-rehydration-state constitution))
          (cons "synchronization_state" (runtime-constitution-synchronization-state constitution))))
   (cons "omega_obs"
         (list
          (cons "capability_classes"
                (mapcar (lambda (entry)
                          (%runtime-name-string (runtime-capability-class-id entry)))
                        (runtime-constitution-capability-classes constitution)))
          (cons "closure_summary"
                (getf (runtime-constitution-meta constitution) :closure-summary))
          (cons "callable_count"
                (length (runtime-constitution-callable-rows constitution)))))))

(defun rehydrate-current-runtime-constitution
    (&key (authority-ref "formal://constitution")
          (machine-ref "formal://live-runtime")
          meta)
  (let* ((source (%runtime-constitution-source-object authority-ref machine-ref))
         (manifests (make-runtime-constitution-manifests))
         (registry-digest (artifact-digest source))
         (constitution-id (format nil "runtime-constitution:~A:~X"
                                  machine-ref
                                  registry-digest))
         (capability-classes (list (make-formal-runtime-capability-class)))
         (machine-state (%runtime-constitution-machine-state
                         :authority-ref authority-ref
                         :machine-ref machine-ref
                         :manifests manifests
                         :registry-digest registry-digest
                         :capability-classes capability-classes))
         (existing (find-runtime-constitution constitution-id)))
    (or existing
        (record-runtime-constitution
         (make-runtime-constitution
          :id constitution-id
          :authority-ref authority-ref
          :machine-ref machine-ref
          :registry-digest registry-digest
          :manifests manifests
          :authority-state (getf machine-state :j)
          :live-state (getf machine-state :l)
          :rehydration-state (getf machine-state :r)
          :synchronization-state (getf machine-state :s)
          :capability-classes capability-classes
          :kernel-core-algorithms (list-kernel-core-algorithms)
          :smt-core-algorithms (list-smt-core-algorithms)
          :admitted-obligations (list-admitted-obligation-classes)
          :theorem-bindings (list-theorem-bridge-bindings)
          :closure-backlog (copy-list *closure-backlog*)
          :meta (append (list :closure-summary (closure-backlog-summary)
                              :lsip-alignment '(:j :l :r :s))
                        meta))))))

(defun current-runtime-constitution ()
  (rehydrate-current-runtime-constitution))
