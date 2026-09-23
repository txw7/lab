(in-package :lab.theorem-workbench)

(defparameter *theorem-statuses*
  '(:open :candidate :conditionally-proved :proved :disproved
    :bounded-witness :bounded-obstruction :trusted-external :blocked
    :capability-missing :budget-exhausted :superseded :unknown))

(defstruct theorem-target
  id statement domain-id semantic-ref status representations provenance metadata)
(defstruct theorem-statement id premises conclusion domain-id provenance metadata)
(defstruct theorem-status
  target-ref status witness-refs obstruction-refs execution-trace-ref search-trace-ref metadata)
(defstruct theorem-search-policy id allowed-operator-families budget metadata)
(defstruct theorem-witness id target-ref kind payload scope trace-ref metadata)
(defstruct theorem-obstruction id target-ref kind witness scope trace-ref metadata)
(defstruct theorem-search-trace id target-ref source-state-ref operator-ref candidate-ref metadata)
(defstruct theorem-execution-trace id target-ref projection-ref provider-ref result metadata)
(defstruct theorem-domain-adapter
  id compile-target-fn generate-candidate-fn project-obligations-fn check-candidate-fn
  extract-counterexample-fn render-status-fn render-report-fn metadata)

(defparameter *domain-registry* (make-hash-table :test #'equal))
(defparameter *target-registry* (make-hash-table :test #'equal))
(defparameter *definition-registry* (make-hash-table :test #'equal))
(defparameter *operator-family-registry* (make-hash-table :test #'equal))

(defun %ensure-status (status)
  (unless (member status *theorem-statuses* :test #'eq)
    (error "Unknown theorem-workbench status ~S" status))
  status)

(defun %call (designator &rest args)
  (etypecase designator
    (function (apply designator args))
    (symbol (apply (symbol-function designator) args))))

(defun register-domain (adapter)
  (unless (typep adapter 'theorem-domain-adapter)
    (error "Expected TheoremDomainAdapterV1 carrier"))
  (setf (gethash (theorem-domain-adapter-id adapter) *domain-registry*) adapter)
  adapter)

(defun find-domain (id) (gethash id *domain-registry*))

(defun list-domains ()
  (sort (loop for value being the hash-values of *domain-registry* collect value)
        #'string< :key (lambda (value) (princ-to-string (theorem-domain-adapter-id value)))))

(defun register-target (target)
  (unless (typep target 'theorem-target)
    (error "Expected TheoremTargetV1 carrier"))
  (%ensure-status (theorem-target-status target))
  (unless (find-domain (theorem-target-domain-id target))
    (error "Unknown theorem domain ~S" (theorem-target-domain-id target)))
  (setf (gethash (theorem-target-id target) *target-registry*) target)
  target)

(defun find-target (id) (gethash id *target-registry*))

(defun list-targets ()
  (sort (loop for value being the hash-values of *target-registry* collect value)
        #'string< :key #'theorem-target-id))

(defun register-definition (id definition)
  (setf (gethash id *definition-registry*) definition)
  definition)

(defun find-definition (id) (gethash id *definition-registry*))

(defun register-operator-family (id descriptor)
  (setf (gethash id *operator-family-registry*) descriptor)
  descriptor)

(defun find-operator-family (id) (gethash id *operator-family-registry*))

(defun %target-and-adapter (target-or-id)
  (let* ((target (etypecase target-or-id
                   (string (or (find-target target-or-id)
                               (error "Unknown theorem target ~A" target-or-id)))
                   (theorem-target target-or-id)))
         (adapter (or (find-domain (theorem-target-domain-id target))
                      (error "Unknown theorem domain ~S" (theorem-target-domain-id target)))))
    (values target adapter)))

(defun compile-target (target-or-id &key representation policy)
  (multiple-value-bind (target adapter) (%target-and-adapter target-or-id)
    (%call (theorem-domain-adapter-compile-target-fn adapter)
           target representation policy)))

(defun generate-candidate (target-or-id proof-problem operator-family operator-input)
  (multiple-value-bind (target adapter) (%target-and-adapter target-or-id)
    (declare (ignore target))
    (%call (theorem-domain-adapter-generate-candidate-fn adapter)
           proof-problem operator-family operator-input)))

(defun project-obligations (target-or-id candidate source-state-ref operator-ref)
  (multiple-value-bind (target adapter) (%target-and-adapter target-or-id)
    (declare (ignore target))
    (%call (theorem-domain-adapter-project-obligations-fn adapter)
           candidate source-state-ref operator-ref)))

(defun check-candidate (target-or-id candidate source-state-ref operator-ref &key provider-id)
  (multiple-value-bind (target adapter) (%target-and-adapter target-or-id)
    (declare (ignore target))
    (%call (theorem-domain-adapter-check-candidate-fn adapter)
           candidate source-state-ref operator-ref provider-id)))

(defun extract-counterexample (target-or-id candidate result)
  (multiple-value-bind (target adapter) (%target-and-adapter target-or-id)
    (declare (ignore target))
    (%call (theorem-domain-adapter-extract-counterexample-fn adapter) candidate result)))

(defun render-status (target-or-id)
  (multiple-value-bind (target adapter) (%target-and-adapter target-or-id)
    (%call (theorem-domain-adapter-render-status-fn adapter) target)))

(defun render-report (target-or-id &key traces)
  (multiple-value-bind (target adapter) (%target-and-adapter target-or-id)
    (%call (theorem-domain-adapter-render-report-fn adapter) target traces)))
