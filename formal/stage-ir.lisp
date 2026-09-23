(in-package :mini-kernel)

(defparameter *checker-statuses*
  '(:accepted :rejected :counterexample :inconclusive
    :replay-mismatch :schema-invalid :audit-failed
    :unknown :timeout))

(defun valid-checker-status-p (status)
  (member status *checker-statuses* :test #'eq))

(defun ensure-checker-status (status &optional (source 'checker))
  (unless (valid-checker-status-p status)
    (kernel-error "invalid checker status from ~S: ~S" source status))
  status)

(defun artifact-digest (payload)
  (sxhash payload))

(defstruct (smt-obligation-bundle
            (:constructor %make-smt-obligation-bundle (&key
                                                          obligation-id
                                                          logic
                                                          input
                                                          input-digest
                                                          normalized-digest
                                                          normalized-term
                                                          assumption-ids
                                                          unsat-core
                                                          status
                                                          evidence-kind
                                                          solver-lane
                                                          trace-ref)))
  obligation-id
  logic
  input
  input-digest
  normalized-digest
  normalized-term
  assumption-ids
  unsat-core
  status
  evidence-kind
  solver-lane
  trace-ref)

(defstruct (smt-cnf-bundle
            (:constructor %make-smt-cnf-bundle (&key
                                                   obligation-id
                                                   logic
                                                   input-digest
                                                   normalized-digest
                                                   cnf-digest
                                                   var-count
                                                   clause-count
                                                   root-literal
                                                   assumption-ids
                                                   unsat-core
                                                   status
                                                   solver-lane
                                                   trace-ref)))
  obligation-id
  logic
  input-digest
  normalized-digest
  cnf-digest
  var-count
  clause-count
  root-literal
  assumption-ids
  unsat-core
  status
  solver-lane
  trace-ref)

(defstruct (protocol-check-bundle
            (:constructor %make-protocol-check-bundle (&key
                                                          protocol-id
                                                          query
                                                          query-digest
                                                          result-digest
                                                          status
                                                          evidence-kind
                                                          checker-lane
                                                          trace-ref)))
  protocol-id
  query
  query-digest
  result-digest
  status
  evidence-kind
  checker-lane
  trace-ref)

(defstruct (external-report-bundle
            (:constructor %make-external-report-bundle (&key
                                                           artifact-id
                                                           source-path
                                                           source-digest
                                                           report-kind
                                                           summary
                                                           summary-digest
                                                           status
                                                           trace-ref)))
  artifact-id
  source-path
  source-digest
  report-kind
  summary
  summary-digest
  status
  trace-ref)

(defun make-smt-obligation-bundle (&key obligation-id
                                        (logic :qf_bv)
                                        input
                                        normalized-term
                                        (assumption-ids '())
                                        (unsat-core '())
                                        status
                                        (evidence-kind :normalized-form)
                                        (solver-lane 'smt-check)
                                        trace-ref)
  (%make-smt-obligation-bundle
   :obligation-id (or obligation-id (gensym "SMT-OBL-"))
   :logic logic
   :input input
   :input-digest (artifact-digest input)
   :normalized-digest (artifact-digest normalized-term)
   :normalized-term normalized-term
   :assumption-ids (copy-list assumption-ids)
   :unsat-core (copy-list unsat-core)
   :status (ensure-checker-status status 'smt-obligation-bundle)
   :evidence-kind evidence-kind
   :solver-lane solver-lane
   :trace-ref trace-ref))

(defun make-smt-cnf-bundle (&key obligation-id
                                 (logic :qf_bool)
                                 input
                                 normalized-term
                                 cnf
                                 (assumption-ids '())
                                 (unsat-core '())
                                 status
                                 (solver-lane 'smt-check)
                                 trace-ref)
  (%make-smt-cnf-bundle
   :obligation-id (or obligation-id (gensym "SMT-CNF-"))
   :logic logic
   :input-digest (artifact-digest input)
   :normalized-digest (artifact-digest normalized-term)
   :cnf-digest (artifact-digest (smt-cnf-clauses cnf))
   :var-count (smt-cnf-var-count cnf)
   :clause-count (length (smt-cnf-clauses cnf))
   :root-literal (smt-cnf-root-literal cnf)
   :assumption-ids (copy-list assumption-ids)
   :unsat-core (copy-list unsat-core)
   :status (ensure-checker-status status 'smt-cnf-bundle)
   :solver-lane solver-lane
   :trace-ref trace-ref))

(defun make-protocol-check-bundle (&key protocol-id
                                        query
                                        result-payload
                                        status
                                        (evidence-kind :invariant)
                                        (checker-lane 'model-check)
                                        trace-ref)
  (%make-protocol-check-bundle
   :protocol-id (or protocol-id (gensym "PROTO-CHK-"))
   :query query
   :query-digest (artifact-digest query)
   :result-digest (artifact-digest result-payload)
   :status (ensure-checker-status status 'protocol-check-bundle)
   :evidence-kind evidence-kind
   :checker-lane checker-lane
   :trace-ref trace-ref))

(defun make-external-report-bundle (&key artifact-id
                                         source-path
                                         source-payload
                                         report-kind
                                         summary
                                         status
                                         trace-ref)
  (%make-external-report-bundle
   :artifact-id (or artifact-id (gensym "EXT-REPORT-"))
   :source-path source-path
   :source-digest (artifact-digest source-payload)
   :report-kind report-kind
   :summary summary
   :summary-digest (artifact-digest summary)
   :status (ensure-checker-status status 'external-report-bundle)
   :trace-ref trace-ref))
