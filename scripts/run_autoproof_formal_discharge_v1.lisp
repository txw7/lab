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
(asdf:load-system "formal")

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
             (otherwise (write-char char stream))))
  (write-char #\" stream))

(defun %json-write (value stream)
  (cond
    ((eq value :json-null)
     (write-string "null" stream))
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

(defun %result-row (search-result)
  (let* ((candidate (%json-get search-result "candidate"))
         (candidate-ref
           (and candidate
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
              (payload
                (%wire-decode
                 (%json-get obligation "payload_row"))))
         (case operation-id
           (:check-smt-spec
            (let* ((spec (%smt-spec-from-row payload))
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
    (let* ((search-result
             (mini-kernel::read-json-file input-path))
           (result (%result-row search-result)))
      (with-open-file
          (stream output-path
                  :direction :output
                  :if-exists :supersede
                  :if-does-not-exist :create)
        (%json-write result stream)
        (terpri stream)))))
