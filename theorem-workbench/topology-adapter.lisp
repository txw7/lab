(in-package :lab.theorem-workbench)

(defun topology-status->theorem-status (status)
  (cond
    ((string= status "open") :open)
    ((string= status "open_with_success_witness") :bounded-witness)
    ((string= status "open_with_failure_witness") :bounded-obstruction)
    ((string= status "proved_by_bounded_witness") :bounded-witness)
    ((string= status "proved_by_precheck_obstruction") :bounded-obstruction)
    (t :unknown)))

(defun %topology-value (row key)
  (cdr (assoc key row :test #'string=)))

(defun topology-target-row->theorem-target (row &key (domain-id :topology))
  (let ((id (%topology-value row "id"))
        (status (%topology-value row "status")))
    (make-theorem-target
     :id id
     :statement (or (%topology-value row "statement") id)
     :domain-id domain-id
     :semantic-ref id
     :status (topology-status->theorem-status status)
     :representations '(:topology-native)
     :provenance (list :source :topology-workbench
                       :source-status status
                       :witness-schedule-digest (%topology-value row "witness_schedule_digest")
                       :obstruction-witness-digest (%topology-value row "obstruction_witness_digest")
                       :execution-trace-digest (%topology-value row "supporting_execution_trace_digest")
                       :search-trace-digest (%topology-value row "supporting_search_trace_digest"))
     :metadata (list :bounded-status-preserved t))))

(defun %topology-compile-target (target representation policy)
  (declare (ignore representation policy))
  (lab.math:make-math-proof-problem-v1
   :id (format nil "proof-problem:~A" (theorem-target-id target))
   :target-claim
   (lab.math:make-math-claim-v1
    :id (theorem-target-semantic-ref target)
    :statement (theorem-target-statement target)
    :status (theorem-target-status target)
    :provenance (theorem-target-provenance target))
   :representation :topology-native
   :allowed-operator-classes '()
   :policy (list :search-authority :lsip)))

(defun %topology-generate-candidate (problem operator-family operator-input)
  (declare (ignore problem operator-family operator-input))
  (error "Topology adapter delegates generic candidate search to LSIP"))

(defun %topology-project (candidate source-state-ref operator-ref)
  (lab.math:compile-math-search-formal-bridge
   :candidate-ref (lab.math:math-object-id candidate)
   :math-claim candidate
   :operator-ref operator-ref
   :source-state-ref source-state-ref))

(defun %topology-check (candidate source-state-ref operator-ref provider-id)
  (lab.math:discharge-math-search-formal-bridge
   (%topology-project candidate source-state-ref operator-ref)
   :provider-id provider-id))

(defun %topology-counterexample (candidate result)
  (when (eq (lab.math:math-provider-result-status result) :counterexample)
    (lab.math:make-math-counterexample-v1
     :id (format nil "counterexample:~A" (lab.math:math-object-id candidate))
     :target-claim-ref (lab.math:math-object-id candidate)
     :witness (lab.math:math-provider-result-counterexample result)
     :backend (lab.math:math-provider-result-provider-id result)
     :scope :bounded)))

(defun %topology-render-status (target)
  (list :target-id (theorem-target-id target)
        :status (theorem-target-status target)
        :source-status (getf (theorem-target-provenance target) :source-status)))

(defun %topology-render-report (target traces)
  (list :target (%topology-render-status target)
        :traces traces
        :search-authority :lsip
        :formal-authority :lab))

(register-domain
 (make-theorem-domain-adapter
  :id :topology
  :compile-target-fn #'%topology-compile-target
  :generate-candidate-fn #'%topology-generate-candidate
  :project-obligations-fn #'%topology-project
  :check-candidate-fn #'%topology-check
  :extract-counterexample-fn #'%topology-counterexample
  :render-status-fn #'%topology-render-status
  :render-report-fn #'%topology-render-report
  :metadata (list :generic-search-authority :lsip :formal-authority :lab)))
