(in-package :lab.math)

(defstruct math-formal-projection-law
  id source-claim-class supported-domain target-backend translator
  target-proposition-builder trusted-boundary reconstruction-description
  unsupported-behavior version)

(defstruct math-formal-projection
  id projection-law-ref source-claim-ref target-backend target-proposition payload
  trusted-boundary supported-p diagnostics)

(defstruct math-provider
  id trust-class supported-claim-classes candidate-input-schema result-schema
  certificate-type counterexample-type cost-class replay-semantics executor)

(defstruct math-provider-result
  provider-id status evidence certificate counterexample trusted-boundaries diagnostics)

(defstruct math-search-formal-bridge
  id candidate-ref math-claim-ref operator-ref source-state-ref projection status metadata)

(defparameter *math-formal-projection-laws* (make-hash-table :test #'equal))
(defparameter *math-providers* (make-hash-table :test #'equal))

(defun clear-math-formal-projection-laws ()
  (clrhash *math-formal-projection-laws*)
  t)

(defun register-math-formal-projection-law (law)
  (unless (typep law 'math-formal-projection-law)
    (error "Expected MathFormalProjectionLawV1 carrier"))
  (unless (math-formal-projection-law-id law)
    (error "Projection law needs an id"))
  (setf (gethash (math-formal-projection-law-id law) *math-formal-projection-laws*) law)
  law)

(defun find-math-formal-projection-law (id)
  (gethash id *math-formal-projection-laws*))

(defun list-math-formal-projection-laws ()
  (sort (loop for law being the hash-values of *math-formal-projection-laws* collect law)
        #'string< :key (lambda (law) (princ-to-string (math-formal-projection-law-id law)))))

(defun %projection-law-applicable-p (law claim)
  (and (typep claim (math-formal-projection-law-source-claim-class law))
       (let ((domain (math-formal-projection-law-supported-domain law)))
         (or (null domain)
             (and (typep claim 'math-claim)
                  (equal domain (math-claim-domain-ref claim)))))))

(defun %call-designator (designator &rest args)
  (etypecase designator
    (function (apply designator args))
    (symbol (apply (symbol-function designator) args))))

(defun project-math-claim (claim &key law-id)
  (unless (typep claim 'math-claim)
    (error "Math-to-FORMAL projection accepts MathClaimV1 carriers"))
  (let* ((law (if law-id
                  (find-math-formal-projection-law law-id)
                  (find-if (lambda (candidate) (%projection-law-applicable-p candidate claim))
                           (list-math-formal-projection-laws))))
         (source-id (math-claim-id claim)))
    (if (and law (%projection-law-applicable-p law claim))
        (handler-case
            (let* ((payload (%call-designator (math-formal-projection-law-translator law) claim))
                   (proposition (%call-designator
                                 (math-formal-projection-law-target-proposition-builder law)
                                 claim payload))
                   (projection-id
                     (format nil "math-formal-projection:~A:~A:~A"
                             source-id
                             (math-formal-projection-law-id law)
                             (math-formal-projection-law-version law))))
              (make-math-formal-projection
               :id projection-id
               :projection-law-ref (math-formal-projection-law-id law)
               :source-claim-ref source-id
               :target-backend (math-formal-projection-law-target-backend law)
               :target-proposition proposition
               :payload payload
               :trusted-boundary (math-formal-projection-law-trusted-boundary law)
               :supported-p t
               :diagnostics '()))
          (error (condition)
            (make-math-formal-projection
             :id (format nil "math-formal-projection:~A:error" source-id)
             :projection-law-ref (math-formal-projection-law-id law)
             :source-claim-ref source-id
             :target-backend (math-formal-projection-law-target-backend law)
             :target-proposition nil
             :payload nil
             :trusted-boundary (math-formal-projection-law-trusted-boundary law)
             :supported-p nil
             :diagnostics (list :projection-error (princ-to-string condition)))))
        (make-math-formal-projection
         :id (format nil "math-formal-projection:~A:unsupported" source-id)
         :projection-law-ref law-id
         :source-claim-ref source-id
         :target-backend nil
         :target-proposition nil
         :payload nil
         :trusted-boundary nil
         :supported-p nil
         :diagnostics (list :unsupported t :claim-id source-id)))))

(defun register-math-provider (provider)
  (unless (typep provider 'math-provider)
    (error "Expected mathematical provider carrier"))
  (unless (member (math-provider-trust-class provider) '(:trusted :checked :advisory) :test #'eq)
    (error "Unknown provider trust class ~S" (math-provider-trust-class provider)))
  (setf (gethash (math-provider-id provider) *math-providers*) provider)
  provider)

(defun find-math-provider (id)
  (gethash id *math-providers*))

(defun list-math-providers ()
  (sort (loop for provider being the hash-values of *math-providers* collect provider)
        #'string< :key (lambda (provider) (princ-to-string (math-provider-id provider)))))

(defun %mini-kernel-formal-capability-executor (projection)
  (let* ((package (find-package :mini-kernel))
         (symbol (and package (find-symbol "INVOKE-FORMAL-CAPABILITY" package))))
    (if (and symbol (fboundp symbol))
        (let* ((payload (math-formal-projection-payload projection))
               (operation-id (getf payload :operation-id))
               (args (copy-list (getf payload :args)))
               (result (apply (symbol-function symbol) operation-id args)))
          (labels ((access (name)
                     (let ((accessor (find-symbol name package)))
                       (and accessor (fboundp accessor)
                            (funcall (symbol-function accessor) result)))))
            (make-math-provider-result
             :provider-id :lab-formal-capability
             :status (or (access "FORMAL-CAPABILITY-RESULT-STATUS") :accepted)
             :evidence result
             :certificate nil
             :counterexample nil
             :trusted-boundaries
             (or (access "FORMAL-CAPABILITY-RESULT-TRUSTED-BOUNDARIES")
                 (list (math-formal-projection-trusted-boundary projection)))
             :diagnostics
             (or (access "FORMAL-CAPABILITY-RESULT-DIAGNOSTICS") '()))))
        (make-math-provider-result
         :provider-id :lab-formal-capability
         :status :capability-missing
         :evidence nil
         :certificate nil
         :counterexample nil
         :trusted-boundaries '()
         :diagnostics (list :mini-kernel-runtime-unavailable t)))))

(defun initialize-default-math-providers ()
  (clrhash *math-providers*)
  (register-math-provider
   (make-math-provider
    :id :lab-formal-capability
    :trust-class :checked
    :supported-claim-classes '(math-claim)
    :candidate-input-schema :math-formal-projection-v1
    :result-schema :formal-capability-result
    :certificate-type :formal-capability-evidence
    :counterexample-type :formal-counterexample
    :cost-class :backend-dependent
    :replay-semantics :pinned-inputs
    :executor #'%mini-kernel-formal-capability-executor))
  (dolist (spec '((:kernel-proof-provider :trusted :kernel-certificate)
                  (:lean-provider :checked :lean-checker-receipt)
                  (:smt-provider :checked :smt-certificate-or-model)
                  (:exact-algebra-provider :checked :exact-algebra-certificate)
                  (:arb-provider :checked :interval-certificate)
                  (:flint-provider :checked :exact-arithmetic-certificate)
                  (:cegis-provider :advisory :cegis-trace)
                  (:finite-search-provider :checked :finite-search-certificate)
                  (:simulation-provider :advisory :simulation-trace)
                  (:literature-theorem-provider :advisory :literature-reference)
                  (:numerical-falsification-provider :advisory :numerical-counterexample)))
    (destructuring-bind (id trust certificate-type) spec
      (register-math-provider
       (make-math-provider
        :id id :trust-class trust :supported-claim-classes '(math-claim)
        :candidate-input-schema :math-formal-projection-v1
        :result-schema :math-provider-result-v1 :certificate-type certificate-type
        :counterexample-type :math-counterexample-v1 :cost-class :declared
        :replay-semantics :provider-specific :executor nil))))
  t)

(defun invoke-math-provider (provider-id projection)
  (let ((provider (find-math-provider provider-id)))
    (unless provider
      (error "Unknown mathematical provider ~S" provider-id))
    (unless (math-formal-projection-supported-p projection)
      (return-from invoke-math-provider
        (make-math-provider-result
         :provider-id provider-id :status :unsupported :evidence nil
         :certificate nil :counterexample nil :trusted-boundaries '()
         :diagnostics (math-formal-projection-diagnostics projection))))
    (let ((executor (math-provider-executor provider)))
      (if executor
          (%call-designator executor projection)
          (make-math-provider-result
           :provider-id provider-id :status :capability-missing :evidence nil
           :certificate nil :counterexample nil :trusted-boundaries '()
           :diagnostics (list :provider-declared-not-bound t))))))

(defun compile-math-search-formal-bridge
    (&key candidate-ref math-claim operator-ref source-state-ref law-id metadata)
  (let* ((projection (project-math-claim math-claim :law-id law-id))
         (bridge-id (format nil "math-search-formal-bridge:~A:~A:~A"
                            candidate-ref operator-ref (math-claim-id math-claim))))
    (make-math-search-formal-bridge
     :id bridge-id
     :candidate-ref candidate-ref
     :math-claim-ref (math-claim-id math-claim)
     :operator-ref operator-ref
     :source-state-ref source-state-ref
     :projection projection
     :status (if (math-formal-projection-supported-p projection) :projected :unsupported)
     :metadata metadata)))

(defun discharge-math-search-formal-bridge (bridge &key provider-id)
  (unless (typep bridge 'math-search-formal-bridge)
    (error "Expected MathSearchFormalBridgeV1 carrier"))
  (let* ((projection (math-search-formal-bridge-projection bridge))
         (provider (or provider-id (math-formal-projection-target-backend projection))))
    (if provider
        (invoke-math-provider provider projection)
        (make-math-provider-result
         :provider-id nil :status :unsupported :evidence nil :certificate nil
         :counterexample nil :trusted-boundaries '()
         :diagnostics (list :no-provider-selected t)))))

(initialize-default-math-providers)
