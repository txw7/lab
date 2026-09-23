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


(defun finite-integer-falsification-executor-v1 (claim context provider)
  (let ((variable (getf context :variable))
        (domain (getf context :domain))
        (predicate (getf context :predicate))
        (feature-function (getf context :feature-function)))
    (unless (symbolp variable)
      (error "Finite integer falsification requires symbolic :variable"))
    (unless (and (listp domain)
                 (every #'integerp domain))
      (error "Finite integer falsification requires an explicit integer :domain"))
    (unless (functionp predicate)
      (error "Finite integer falsification requires a predicate function"))
    (dolist (value domain)
      (unless (funcall predicate value)
        (return-from finite-integer-falsification-executor-v1
          (make-math-falsification-result-v1
           :claim-ref (math-object-id claim)
           :provider-ref
           (math-falsification-provider-v1-provider-ref provider)
           :status :counterexample
           :witness
           (list
            :assignment (list variable value)
            :features
            (and feature-function
                 (funcall feature-function value)))
           :tested-domain
           (list :kind :finite-integer-domain
                 :variable variable
                 :values (copy-list domain))
           :provenance
           (list :source :finite-integer-falsification-v1)
           :metadata
           (list :tested-count
                 (1+ (position value domain :test #'eql)))))))
    (make-math-falsification-result-v1
     :claim-ref (math-object-id claim)
     :provider-ref
     (math-falsification-provider-v1-provider-ref provider)
     :status :no-counterexample-found
     :tested-domain
     (list :kind :finite-integer-domain
           :variable variable
           :values (copy-list domain))
     :provenance
     (list :source :finite-integer-falsification-v1)
     :metadata
     (list :tested-count (length domain)))))

(defun make-finite-integer-falsification-provider-v1
    (&key (provider-ref :finite-integer-search) metadata)
  (make-math-falsification-provider-v1
   :provider-ref provider-ref
   :supported-classes '(:math-claim)
   :executor #'finite-integer-falsification-executor-v1
   :cost-class :cheap
   :metadata
   (append
    (list :search-domain :explicit-finite-integers
          :truth-authority :none)
    (copy-tree metadata))))
