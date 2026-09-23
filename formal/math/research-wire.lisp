(in-package :lab.math)

(defstruct research-graph-math-bridge
  source-system source-logical-id source-object-id math-object-id direction provenance)

(defun %alist-value (object key)
  (cdr (assoc key object :test #'string=)))

(defun %research-status->math-status (status)
  (cond
    ((null status) :unknown)
    ((string= status "CANDIDATE") :candidate)
    ((string= status "UNPROVEN") :open)
    ((string= status "CHECKING") :candidate)
    ((string= status "PROVED") :trusted-external)
    ((string= status "IMPORTED_CHECKED") :trusted-external)
    ((string= status "FALSIFIED") :disproved)
    ((string= status "BLOCKED") :blocked)
    ((string= status "SUPERSEDED") :superseded)
    (t :unknown)))

(defun %keyword-op (name)
  (let ((normalized (substitute #\- #\_ (string-upcase name))))
    (intern normalized :keyword)))

(defun research-expression->math-expression (record)
  (let* ((op-name (%alist-value record "op"))
         (op (%keyword-op op-name))
         (args (mapcar (lambda (arg)
                         (if (and (listp arg) (assoc "op" arg :test #'string=))
                             (research-expression->math-expression arg)
                             arg))
                       (or (%alist-value record "args") '()))))
    (unless (member op *math-expression-operators* :test #'eq)
      (setf op :special-function
            args (list (cons :research-op op-name) args)))
    (apply #'make-math-expression-v1
           op
           (append args
                   (when (%alist-value record "value")
                     (list :value (%alist-value record "value")))
                   (when (%alist-value record "name")
                     (list :name (%alist-value record "name")))
                   (list :metadata (list :source-schema (%alist-value record "schema")))))))

(defun research-proof-object->math-object (record)
  (let* ((schema (%alist-value record "schema"))
         (object-type (%alist-value record "object_type"))
         (object-id (%alist-value record "object_id"))
         (metadata (%alist-value record "metadata"))
         (logical-id (or (and (listp metadata) (%alist-value metadata "logical_id"))
                         object-id))
         (statement (or (%alist-value record "statement_canonical") ""))
         (source-status (%alist-value record "status"))
         (status (%research-status->math-status source-status))
         (provenance (list :source-system :research-autoproof
                           :source-schema schema
                           :source-object-id object-id
                           :source-proof-status source-status
                           :source-provenance (%alist-value record "provenance"))))
    (cond
      ((member object-type '("TheoremGoal" "EquivalentGoal" "LemmaCandidate" "FormalLemma"
                             "SymbolicIdentity" "IntegralRepresentation" "OperatorRepresentation"
                             "KernelRepresentation" "BoundedCertificate" "ResearchAttempt"
                             "RejectedCandidate") :test #'string=)
       (make-math-claim-v1
        :id logical-id :statement statement :status status
        :dependencies (%alist-value record "dependencies")
        :provenance provenance :metadata metadata))
      ((string= object-type "Counterexample")
       (make-math-counterexample-v1
        :id logical-id
        :target-claim-ref (first (%alist-value record "dependencies"))
        :witness (%alist-value record "evidence_refs")
        :backend :research-import
        :scope (%alist-value record "domain_constraints")
        :provenance provenance :metadata metadata))
      (t
       (make-math-claim-v1
        :id logical-id :statement statement :status status
        :dependencies (%alist-value record "dependencies")
        :provenance provenance
        :metadata (list :source-object-type object-type :source-metadata metadata))))))

(defun math-object->research-record (object)
  (etypecase object
    (math-claim
     (list (cons "schema" "LabMathResearchExportV1")
           (cons "kind" "claim")
           (cons "logical_id" (math-claim-id object))
           (cons "statement" (math-claim-statement object))
           (cons "status" (string-downcase (symbol-name (math-claim-status object))))
           (cons "dependencies" (copy-list (math-claim-dependencies object)))
           (cons "provenance" (math-claim-provenance object))))
    (math-counterexample
     (list (cons "schema" "LabMathResearchExportV1")
           (cons "kind" "counterexample")
           (cons "logical_id" (math-counterexample-id object))
           (cons "target_claim_ref" (math-counterexample-target-claim-ref object))
           (cons "witness" (math-counterexample-witness object))
           (cons "backend" (princ-to-string (math-counterexample-backend object)))
           (cons "provenance" (math-counterexample-provenance object))))
    (math-no-go
     (list (cons "schema" "LabMathResearchExportV1")
           (cons "kind" "no_go")
           (cons "logical_id" (math-no-go-id object))
           (cons "strategy" (math-no-go-strategy object))
           (cons "target_refs" (copy-list (math-no-go-target-refs object)))
           (cons "provenance" (math-no-go-provenance object))))))
