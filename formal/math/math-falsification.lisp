(in-package :lab.math)

(defparameter *math-falsification-statuses-v1*
  '(:no-counterexample-found :counterexample :domain-error :inconclusive))

(defstruct (math-falsification-result-v1
            (:constructor %make-math-falsification-result-v1))
  result-ref claim-ref provider-ref status witness tested-domain diagnostics
  provenance metadata proof-effect)

(defstruct (math-falsification-provider-v1
            (:constructor make-math-falsification-provider-v1))
  provider-ref supported-classes executor cost-class metadata)

(defvar *math-falsification-providers-v1* (make-hash-table :test #'equal))

(defun make-math-falsification-result-v1
    (&key result-ref claim-ref provider-ref status witness tested-domain
      diagnostics provenance metadata)
  (unless (member status *math-falsification-statuses-v1* :test #'eq)
    (error "Unknown MathFalsificationResultV1 status ~S" status))
  (%make-math-falsification-result-v1
   :result-ref
   (or result-ref
       (format nil "math-falsification:~A"
               (%string-key
                (list claim-ref provider-ref status witness tested-domain diagnostics))))
   :claim-ref claim-ref :provider-ref provider-ref :status status
   :witness (copy-tree witness) :tested-domain (copy-tree tested-domain)
   :diagnostics (copy-tree diagnostics) :provenance (copy-tree provenance)
   :metadata (copy-tree metadata) :proof-effect :none))

(defun register-math-falsification-provider-v1 (provider)
  (setf (gethash
         (math-falsification-provider-v1-provider-ref provider)
         *math-falsification-providers-v1*)
        provider)
  provider)

(defun run-math-falsification-pipeline-v1 (claim provider-refs &key context)
  (let ((results '()))
    (dolist (provider-ref provider-refs)
      (let* ((provider
               (or (gethash provider-ref *math-falsification-providers-v1*)
                   (error "Unknown falsification provider ~S" provider-ref)))
             (executor (math-falsification-provider-v1-executor provider))
             (result (funcall executor claim context provider)))
        (unless (typep result 'math-falsification-result-v1)
          (error "Falsification provider ~S returned ~S" provider-ref result))
        (push result results)
        (when (member (math-falsification-result-v1-status result)
                      '(:counterexample :domain-error) :test #'eq)
          (return-from run-math-falsification-pipeline-v1
            (values result (nreverse results))))))
    (let ((rows (nreverse results)))
      (values
       (or
        (find :no-counterexample-found rows
              :key #'math-falsification-result-v1-status :test #'eq)
        (find :inconclusive rows
              :key #'math-falsification-result-v1-status :test #'eq)
        (make-math-falsification-result-v1
         :claim-ref (math-object-id claim)
         :provider-ref :none
         :status :inconclusive
         :diagnostics (list :no-provider-result t)))
       rows))))

(export
 '(math-falsification-result-v1 math-falsification-result-v1-result-ref
   math-falsification-result-v1-status math-falsification-result-v1-witness
   math-falsification-result-v1-proof-effect
   make-math-falsification-result-v1
   math-falsification-provider-v1 make-math-falsification-provider-v1
   math-falsification-provider-v1-provider-ref
   register-math-falsification-provider-v1
   run-math-falsification-pipeline-v1)
 :lab.math)
