#!/usr/bin/env sbcl --script
(require :asdf)

(defparameter *autoproof-formal-root*
  (truename
   (merge-pathnames
    "../"
    (uiop:pathname-directory-pathname
     *load-truename*))))

(asdf:initialize-source-registry
 (list
  :source-registry
  (list :directory
        (merge-pathnames "formal/" *autoproof-formal-root*))
  :inherit-configuration))

(setf *compile-verbose* nil
      *compile-print* nil)

(asdf:load-asd
 (merge-pathnames "formal/formal.asd" *autoproof-formal-root*))
(load (merge-pathnames "formal/package.lisp" *autoproof-formal-root*))
(load (merge-pathnames "formal/json-lite.lisp" *autoproof-formal-root*))

(defun %json-get (object key)
  (cdr (assoc key object :test #'string=)))

(defun %keyword-from-wire-string (value)
  (and
   (stringp value)
   (intern
    (string-upcase
     (substitute #\- #\_ value))
    :keyword)))

(defun %wire-decode (value)
  (cond
    ((or (eq value mini-kernel::*json-empty-array*)
         (eq value mini-kernel::*json-false*))
     nil)
    ((eq value :null) nil)
    ((and
      (listp value)
      (every
       (lambda (item)
         (and (consp item)
              (stringp (car item))))
       value))
     (let ((keyword-row (%json-get value "$keyword"))
           (symbol-row (%json-get value "$symbol")))
       (cond
         (keyword-row
          (intern keyword-row :keyword))
         (symbol-row
          (let* ((package-name (%json-get value "$package"))
                 (package
                   (or
                    (and package-name
                         (find-package package-name))
                    (find-package :cl-user))))
            (intern symbol-row package)))
         (t
          (mapcar
           (lambda (item)
             (cons
              (car item)
              (%wire-decode (cdr item))))
           value)))))
    ((listp value)
     (mapcar #'%wire-decode value))
    (t value)))

(defun %json-escape-string (value stream)
  (write-char #\" stream)
  (loop for char across value
        do
           (case char
             (#\" (write-string "\\\"" stream))
             (#\\ (write-string "\\\\" stream))
             (#\Newline (write-string "\\n" stream))
             (#\Return (write-string "\\r" stream))
             (#\Tab (write-string "\\t" stream))
             (otherwise
              (if (< (char-code char) 32)
                  (format stream "\\u~4,'0X" (char-code char))
                  (write-char char stream)))))
  (write-char #\" stream))

(defun %json-write (value stream)
  (cond
    ((member value '(:json-null :null) :test #'eq)
     (write-string "null" stream))
    ((eq value :json-empty-object)
     (write-string "{}" stream))
    ((eq value mini-kernel::*json-empty-array*)
     (write-string "[]" stream))
    ((eq value mini-kernel::*json-false*)
     (write-string "false" stream))
    ((eq value t)
     (write-string "true" stream))
    ((null value)
     (write-string "null" stream))
    ((stringp value)
     (%json-escape-string value stream))
    ((integerp value)
     (princ value stream))
    ((and
      (listp value)
      (every
       (lambda (item)
         (and
          (consp item)
          (stringp (car item))))
       value))
     (write-char #\{ stream)
     (loop for item in value
           for first = t then nil
           do
              (unless first (write-char #\, stream))
              (%json-escape-string (car item) stream)
              (write-char #\: stream)
              (%json-write (cdr item) stream))
     (write-char #\} stream))
    ((listp value)
     (write-char #\[ stream)
     (loop for item in value
           for first = t then nil
           do
              (unless first (write-char #\, stream))
              (%json-write item stream))
     (write-char #\] stream))
    (t
     (%json-escape-string (princ-to-string value) stream))))

(defun %status-string (value)
  (and
   value
   (string-downcase
    (substitute #\_ #\-
                (symbol-name value)))))

(defun %sort-from-row (row)
  (cond
    ((eq row :int) '(:Int))
    ((eq row :bool) '(:Bool))
    ((and (consp row) (eq (first row) :bv))
     (list :BV (second row)))
    ((and (consp row)
          (member (first row) '(:Int :Bool :BV) :test #'eq))
     row)
    (t
     (error "Unsupported SMT sort row ~S" row))))

(defun %smt-obligation-from-row (row)
  (mini-kernel:make-smt-obligation
   :id (getf row :id)
   :label (getf row :label)
   :logic (or (getf row :logic) :qf_lia)
   :vars
   (loop for (name sort) in (getf row :vars)
         collect
         (list name (%sort-from-row sort)))
   :assumptions (copy-tree (getf row :assumptions))
   :goal (copy-tree (getf row :goal))
   :polarity (or (getf row :polarity) :expect-status)
   :expected-status
   (or (getf row :expected-status) :accepted)
   :unknown-policy
   (or (getf row :unknown-policy) :forbidden)
   :semantic-tags
   (copy-list (getf row :semantic-tags))
   :source-ref (getf row :source-ref)
   :metadata (copy-tree (getf row :metadata))))

(defun %smt-spec-from-row (row)
  (unless (eq (getf row :kind) :smt-spec)
    (error "Expected :SMT-SPEC payload, got ~S" row))
  (mini-kernel:make-smt-spec
   :id (getf row :id)
   :logic (or (getf row :logic) :qf_lia)
   :obligations
   (mapcar #'%smt-obligation-from-row
           (getf row :obligations))
   :source-path (getf row :source-path)
   :semantic-tags
   (copy-list (getf row :semantic-tags))
   :metadata (copy-tree (getf row :metadata))))

(defun %nonempty-pin-string-p (value)
  (and (stringp value)
       (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                  value)))))

(defun %sha256-pin-p (value)
  (and (stringp value)
       (= 64 (length value))
       (every (lambda (char) (find char "0123456789abcdef")) value)))

(defun %require-pin-fields (row label fields &key digestp)
  (dolist (field fields)
    (unless (and (listp row)
                 (funcall (if digestp #'%sha256-pin-p #'%nonempty-pin-string-p)
                          (%json-get row field)))
      (error "~A is missing a valid ~A pin" label field))))

(defun %require-dependency-digests (row label)
  ;; An explicit empty dependency map is valid. A missing field or JSON null
  ;; is not a declaration that the checked module has no local dependencies.
  (let ((entry (and (listp row)
                    (assoc "dependency_source_digests" row :test #'string=))))
    (unless (and entry
                 (listp (cdr entry))
                 (every (lambda (digest)
                          (and (consp digest)
                               (%nonempty-pin-string-p (car digest))
                               (%sha256-pin-p (cdr digest))))
                        (cdr entry)))
      (error "~A is missing valid dependency_source_digests" label))))

(defun %dependency-digests-equal-p (left right)
  ;; The original Research producer compares JSON maps, independently of
  ;; member order. Shapes and digest values are validated before this call.
  (and (= (length left) (length right))
       (= (length left) (length (remove-duplicates left :key #'car :test #'equal)))
       (= (length right) (length (remove-duplicates right :key #'car :test #'equal)))
       (every (lambda (entry)
                (let ((other (assoc (car entry) right :test #'equal)))
                  (and other (equal (cdr entry) (cdr other)))))
              left)))

(defun %require-target-checker-context (metadata plan)
  ;; Mirrors the exact context contract in the original Research owner's
  ;; promote.py::_verify_target_context; no new theorem authority is created.
  (let* ((context (%json-get metadata "checker_context"))
         (fields '("module_path" "module_source_sha256" "dependency_source_digests"
                   "lean_version" "mathlib_revision" "lake_manifest_sha256")))
    (unless (and (listp context)
                 (= (length fields) (length context))
                 (every (lambda (field)
                          (= 1 (count field context :key #'car :test #'equal)))
                        fields))
      (error "theorem checker_context must contain its exact pinned source context"))
    (%require-dependency-digests context "theorem checker_context")
    (unless (and
             (equal (%json-get context "module_path") (%json-get plan "lean_module"))
             (equal (%json-get context "module_source_sha256")
                    (%json-get plan "target_source_sha256"))
             (%dependency-digests-equal-p
              (%json-get context "dependency_source_digests")
              (%json-get plan "dependency_source_digests"))
             (every (lambda (field)
                      (equal (%json-get context field) (%json-get plan field)))
                    '("lean_version" "mathlib_revision" "lake_manifest_sha256")))
      (error "checker plan differs from the theorem's pinned source context"))))

(defun %require-receipt-request (search-result obligation payload)
  ;; Reconstruct the correlation exactly as Research promote.py does. This is
  ;; a receipt/request check, not reconstruction of a Lean proposition.
  (unless (and (equal (%json-get search-result "schema")
                      "LSIPTheoremMathSearchResultV1")
               (equal (%json-get search-result "status") "FORMAL_RECEIPT_SUBMITTED")
               (eq (%json-get search-result "candidate") :null)
               (equal (%json-get obligation "operation_id") "judge_lean_checker_receipt")
               (equal (%json-get obligation "obligation_id")
                      (format nil "autoproof-lean-receipt:~A:~A"
                              (%json-get payload "target_ref")
                              (%json-get payload "checker_result_ref"))))
    (error "receipt request differs from the original Research envelope or exact correlation")))

(defun %checker-context-evidence (payload)
  ;; Preserve the owner's context, including explicit {} rather than null.
  (let* ((target (%json-get payload "target_record"))
         (context (copy-tree (%json-get (%json-get target "metadata") "checker_context")))
         (dependencies (assoc "dependency_source_digests" context :test #'equal)))
    (when (null (cdr dependencies))
      (setf (cdr dependencies) :json-empty-object))
    context))

(defun %lean-receipt-judgment (payload)
  (let* ((target-ref (%json-get payload "target_ref"))
         (occurrence-ref (%json-get payload "target_occurrence_ref"))
         (snapshot-ref (%json-get payload "subject_snapshot_ref"))
         (program-graph-address (%json-get payload "program_graph_address"))
         (plan-ref (%json-get payload "checker_plan_ref"))
         (result-ref (%json-get payload "checker_result_ref"))
         (target (%json-get payload "target_record"))
         (plan (%json-get payload "checker_plan"))
         (result (%json-get payload "checker_result"))
         (metadata (%json-get target "metadata")))
    (%require-pin-fields
     payload "receipt payload"
     '("target_ref" "target_occurrence_ref" "subject_snapshot_ref"
       "checker_plan_ref" "checker_result_ref"))
    (%require-pin-fields
     program-graph-address "program graph address"
     '("authority_ref" "source_revision" "source_graph_root"
       "h001_graph_object_ref" "h001_bundle_ref" "h002_address_ref"
       "h002_containment_witness_ref" "mapping_witness_ref"
       "target_occurrence_ref" "subject_snapshot_ref"))
    (%require-pin-fields metadata "theorem metadata" '("expected_theorem"))
    (%require-pin-fields metadata "theorem metadata" '("target_source_sha256")
                         :digestp t)
    (%require-pin-fields
     plan "checker plan"
     '("expected_theorem" "lean_module" "lean_version" "mathlib_revision"))
    (%require-pin-fields
     plan "checker plan" '("target_source_sha256" "lake_manifest_sha256")
     :digestp t)
    (%require-pin-fields
     result "checker result"
     '("expected_theorem" "module_path" "lean_version" "mathlib_revision"))
    (%require-pin-fields
     result "checker result"
     '("source_sha256" "module_source_sha256" "lake_manifest_sha256"
       "stdout_sha256" "stderr_sha256")
     :digestp t)
    (%require-dependency-digests plan "checker plan")
    (%require-dependency-digests result "checker result")
    (%require-target-checker-context metadata plan)
    (unless (and target-ref occurrence-ref snapshot-ref plan-ref result-ref
                 (equal "ProgramGraphAddressBindingV1"
                        (%json-get program-graph-address "schema"))
                 (%json-get program-graph-address "authority_ref")
                 (%json-get program-graph-address "source_revision")
                 (%json-get program-graph-address "source_graph_root")
                 (%json-get program-graph-address "h001_graph_object_ref")
                 (%json-get program-graph-address "h001_bundle_ref")
                 (%json-get program-graph-address "h002_address_ref")
                 (%json-get program-graph-address "h002_containment_witness_ref")
                 (%json-get program-graph-address "mapping_witness_ref")
                 (equal occurrence-ref
                        (%json-get program-graph-address "target_occurrence_ref"))
                 (equal snapshot-ref
                        (%json-get program-graph-address "subject_snapshot_ref"))
                 (equal program-graph-address
                        (%json-get metadata "program_graph_address"))
                 (equal target-ref (%json-get target "object_id"))
                 (equal plan-ref (%json-get plan "object_id"))
                 (equal result-ref (%json-get result "object_id"))
                 (equal "ProofObjectV1" (%json-get target "schema"))
                 (equal "FormalLemma" (%json-get target "object_type"))
                 (member (%json-get target "status")
                         '("CANDIDATE" "UNPROVEN" "CHECKING")
                         :test #'equal)
                 (equal occurrence-ref (%json-get metadata "target_occurrence_ref"))
                 (equal snapshot-ref (%json-get metadata "subject_snapshot_ref")))
      (error "target identity is incomplete or differs from the addressed theorem"))
    (unless (and
             (equal "ProofCheckPlanV1" (%json-get plan "schema"))
             (equal "ProofCheckPlan" (%json-get plan "object_type"))
             (equal target-ref (%json-get plan "goal_ref"))
             (equal (%json-get metadata "expected_theorem")
                    (%json-get plan "expected_theorem"))
             (equal (%json-get metadata "target_source_sha256")
                    (%json-get plan "target_source_sha256")))
      (error "checker plan does not identify the exact theorem target"))
    (unless (and
             (equal "CheckerResultV1" (%json-get result "schema"))
             (equal "CheckerResult" (%json-get result "object_type"))
             (equal "lean4" (%json-get result "checker"))
             (eq :null (%json-get result "failure_class"))
             (equal result-ref (%json-get result "object_id"))
             (equal "CHECKED" (%json-get result "status"))
             (eq t (%json-get result "trusted"))
             (eql 0 (%json-get result "process_status"))
             (eql 0 (%json-get result "exit_status"))
             (equal plan-ref (%json-get result "plan_ref"))
             (equal (%json-get plan "expected_theorem")
                    (%json-get result "expected_theorem"))
             (equal (%json-get plan "lean_module")
                    (%json-get result "module_path"))
             (equal (%json-get plan "target_source_sha256")
                    (%json-get result "source_sha256"))
             (equal (%json-get plan "target_source_sha256")
                    (%json-get result "module_source_sha256"))
             (%dependency-digests-equal-p
              (%json-get plan "dependency_source_digests")
              (%json-get result "dependency_source_digests"))
             (equal (%json-get plan "lean_version")
                    (%json-get result "lean_version"))
             (equal (%json-get plan "mathlib_revision")
                    (%json-get result "mathlib_revision"))
             (equal (%json-get plan "lake_manifest_sha256")
                    (%json-get result "lake_manifest_sha256")))
      (error "Lean checker receipt is not a successful result for this exact plan"))
    (list
     (cons "kind" "LEAN_CHECKED_THEOREM_V1")
     (cons "target_ref" target-ref)
     (cons "target_occurrence_ref" occurrence-ref)
     (cons "subject_snapshot_ref" snapshot-ref)
     (cons "program_graph_address" program-graph-address)
     (cons "checker_result_ref" result-ref)
     (cons "checker_plan_ref" plan-ref))))

(defun %result-row (search-result)
  (unless (equal (%json-get search-result "schema") "LSIPTheoremMathSearchResultV1")
    (error "unsupported formal-discharge request schema"))
  (let* ((candidate (%json-get search-result "candidate"))
         (candidate-ref
           (and (listp candidate)
                (%json-get candidate "carrier_ref")))
         (obligation
           (%json-get search-result "formal_obligation")))
    (cond
      ((or (null obligation)
           (eq obligation :null))
       (list
        (cons "schema" "LabFormalDischargeResultV1")
        (cons "candidate_ref" candidate-ref)
        (cons "status" "NO_FORMAL_OBLIGATION")
        (cons "theorem_status_effect" "NONE")
        (cons "evidence" :json-null)))
      (t
       (let* ((operation-id
                (%keyword-from-wire-string
                 (%json-get obligation "operation_id")))
              (payload (%json-get obligation "payload_row")))
         (case operation-id
           (:judge-lean-checker-receipt
            (multiple-value-bind (judgment rejection)
                (handler-case
                    ;; Receipt records are ordinary JSON, not the SMT Lisp
                    ;; wire format. Preserve JSON null so it cannot equal an
                    ;; explicitly empty dependency map after wire decoding.
                    (progn
                      (%require-receipt-request search-result obligation payload)
                      (values (%lean-receipt-judgment payload) nil))
                  (error (condition)
                    (values nil (princ-to-string condition))))
              (list
               (cons "schema" "LabFormalDischargeResultV1")
               (cons "candidate_ref" candidate-ref)
               (cons "formal_obligation_id"
                     (%json-get obligation "obligation_id"))
               (cons "formal_operation_id" "judge_lean_checker_receipt")
               (cons "status" (if judgment "CHECKED" "REJECTED"))
               (cons "theorem_status_effect" "NONE")
               (cons "formal_judgment" (or judgment :json-null))
               (cons "evidence"
                     (if judgment
                         (list
                          (cons "evidence_kind" "pinned_checker_receipt_binding")
                          (cons "trusted_boundaries"
                                '("lean_checker_execution" "research_checker_receipt_validation"))
                          (cons "checker_result_ref"
                                (%json-get payload "checker_result_ref"))
                          (cons "checker_plan_ref"
                                (%json-get payload "checker_plan_ref"))
                          (cons "checker_context" (%checker-context-evidence payload))
                          (cons "expected_theorem"
                                (%json-get (%json-get payload "checker_plan") "expected_theorem"))
                          (cons "stdout_sha256"
                                (%json-get (%json-get payload "checker_result") "stdout_sha256"))
                          (cons "stderr_sha256"
                                (%json-get (%json-get payload "checker_result") "stderr_sha256")))
                         (list
                          (cons "evidence_kind" "receipt_binding_rejected")
                          (cons "rejection_reason" rejection)))))))
           (:check-smt-spec
            (asdf:load-system "formal")
            (let* ((spec (%smt-spec-from-row (%wire-decode payload)))
                   (result
                     (mini-kernel:invoke-formal-capability
                      :check-smt-spec
                      :caller-class :synth
                      :spec spec)))
              (list
               (cons "schema" "LabFormalDischargeResultV1")
               (cons "candidate_ref" candidate-ref)
               (cons "formal_obligation_id"
                     (%json-get obligation "obligation_id"))
               (cons "formal_operation_id"
                     "check_smt_spec")
               (cons "status"
                     (%status-string
                      (mini-kernel:formal-capability-result-status
                       result)))
               (cons "theorem_status_effect" "NONE")
               (cons
                "evidence"
                (list
                 (cons "evidence_kind"
                       (%status-string
                        (mini-kernel:formal-capability-result-evidence-kind
                         result)))
                 (cons "trusted_boundaries"
                       (mapcar
                        #'%status-string
                        (mini-kernel:formal-capability-result-trusted-boundaries
                         result)))
                 (cons "rejection_reason"
                       (or
                        (mini-kernel:formal-capability-result-rejection-reason
                         result)
                        :json-null))
                 (cons "diagnostics"
                       (mapcar
                        #'princ-to-string
                        (mini-kernel:formal-capability-result-diagnostics
                         result))))))))
           (otherwise
            (list
             (cons "schema" "LabFormalDischargeResultV1")
             (cons "candidate_ref" candidate-ref)
             (cons "formal_obligation_id"
                   (%json-get obligation "obligation_id"))
             (cons "formal_operation_id"
                   (or
                    (%json-get obligation "operation_id")
                    :json-null))
             (cons "status" "CAPABILITY_MISSING")
             (cons "theorem_status_effect" "NONE")
             (cons "evidence" :json-null)))))))))

(let ((args (uiop:command-line-arguments)))
  (unless (= 2 (length args))
    (error
     "usage: run_autoproof_formal_discharge_v1.lisp SEARCH-RESULT.json EVIDENCE.json"))
  (destructuring-bind (input-path output-path) args
    (let ((result
            (handler-case
                (%result-row
                 (mini-kernel::read-json-file
                  input-path :preserve-container-types t :strict t
                  :max-bytes 1048576 :max-depth 64 :max-container-items 4096))
              (error (condition)
                (list
                 (cons "schema" "LabFormalDischargeResultV1")
                 (cons "candidate_ref" :json-null)
                 (cons "status" "REJECTED")
                 (cons "theorem_status_effect" "NONE")
                 (cons "formal_judgment" :json-null)
                 (cons "evidence"
                       (list (cons "evidence_kind" "request_decode_rejected")
                             (cons "rejection_reason" (princ-to-string condition)))))))))
      (with-open-file
          (stream output-path
                  :direction :output
                  :if-exists :supersede
                  :if-does-not-exist :create)
        (%json-write result stream)
        (terpri stream)))))
