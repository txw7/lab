(in-package :lab.rh-workbench)

(defparameter *rh-first-contact-target-id* "RH_GAUSSIAN_FIRST_CONTACT_EXCLUSION_V1")

(defparameter *rh-representations*
  '(:li-circle-view :toeplitz-cnd-view :central-pick-view
    :horizontal-stieltjes-view :gaussian-heat-view :matched-prime-discrepancy-view))

(defparameter *rh-operator-families*
  '(:contact-substitute-prime-side :contact-differentiate :contact-second-derivative
    :prime-log-block-decompose :prime-block-demodulate :prime-block-center
    :combine-value-gradient-curvature :derive-block-bias :apply-large-value-bound
    :apply-short-interval-bound :search-local-rigidity-inequality
    :search-synthetic-counterexample :switch-rh-representation))

(defun %v (name)
  (lab.math:make-math-expression-v1 :variable :name name))

(defun %app (name &rest args)
  (apply #'lab.math:make-math-expression-v1
         :application
         (lab.math:make-math-expression-v1 :variable :name name)
         args))

(defun rh-first-contact-claim ()
  (let* ((r (%v "r"))
         (height (%v "T"))
         (field (%app "H" r height))
         (d1 (lab.math:make-math-expression-v1 :derivative field height))
         (d2 (lab.math:make-math-expression-v1 :derivative d1 height))
         (zero (lab.math:make-math-expression-v1 :constant :value 0))
         (contact
           (lab.math:make-math-expression-v1
            :and
            (lab.math:make-math-expression-v1 :gt r zero)
            (lab.math:make-math-expression-v1 :equality field zero)
            (lab.math:make-math-expression-v1 :equality d1 zero)
            (lab.math:make-math-expression-v1 :ge d2 zero)))
         (exists-height (lab.math:make-math-expression-v1 :exists height contact))
         (exists-contact (lab.math:make-math-expression-v1 :exists r exists-height))
         (statement
           "No positive heat scale and real height form a Gaussian-Weil first contact with zero value, zero first height derivative, and nonnegative second height derivative"))
    (lab.math:make-math-claim-v1
     :id *rh-first-contact-target-id*
     :statement statement
     :expression (lab.math:make-math-expression-v1 :not exists-contact)
     :domain-ref "riemann-hypothesis/gaussian-weil"
     :status :open
     :provenance (list :source-system :txw7/research
                       :frontier-schema "ActiveRHFrontierV1"
                       :authority :research-input-not-formal-proof)
     :metadata (list :representations *rh-representations*))))

(defun %rh-compile-target (target representation policy)
  (let ((representation (or representation :gaussian-heat-view)))
    (unless (member representation *rh-representations* :test #'eq)
      (error "Unknown RH representation ~S" representation))
    (lab.math:make-math-proof-problem-v1
     :id (format nil "proof-problem:~A:~A" (lab.theorem-workbench:theorem-target-id target) representation)
     :target-claim (rh-first-contact-claim)
     :representation representation
     :allowed-operator-classes *rh-operator-families*
     :policy (or policy (list :generic-search-authority :lsip
                              :formal-authority :lab
                              :arbitrary-operator-synthesis nil))
     :provenance (lab.theorem-workbench:theorem-target-provenance target))))

(defun %rh-generate-candidate (problem operator-family operator-input)
  (unless (member operator-family *rh-operator-families* :test #'eq)
    (error "Operator family is outside the RH domain catalog ~S" operator-family))
  (list :schema :rh-domain-candidate-v1
        :proof-problem-ref (lab.math:math-proof-problem-id problem)
        :operator-family operator-family
        :operator-input operator-input
        :authority :candidate-construction-only))

(defun %rh-project (candidate source-state-ref operator-ref)
  (let ((claim (cond
                 ((typep candidate 'lab.math:math-claim) candidate)
                 ((and (listp candidate) (getf candidate :math-claim))
                  (getf candidate :math-claim))
                 (t (error "RH formal projection needs a MathClaimV1 candidate")))))
    (lab.math:compile-math-search-formal-bridge
     :candidate-ref (lab.math:math-object-id claim)
     :math-claim claim
     :operator-ref operator-ref
     :source-state-ref source-state-ref
     :metadata (list :domain :rh))))

(defun %rh-check (candidate source-state-ref operator-ref provider-id)
  (lab.math:discharge-math-search-formal-bridge
   (%rh-project candidate source-state-ref operator-ref)
   :provider-id provider-id))

(defun %rh-counterexample (candidate result)
  (when (eq (lab.math:math-provider-result-status result) :counterexample)
    (let ((claim (if (typep candidate 'lab.math:math-claim)
                     candidate
                     (getf candidate :math-claim))))
      (lab.math:make-math-counterexample-v1
       :id (format nil "rh-counterexample:~A" (lab.math:math-object-id claim))
       :target-claim-ref (lab.math:math-object-id claim)
       :witness (lab.math:math-provider-result-counterexample result)
       :backend (lab.math:math-provider-result-provider-id result)
       :scope :provider-reported
       :provenance (list :domain :rh)))))

(defun %rh-render-status (target)
  (list :target-id (lab.theorem-workbench:theorem-target-id target)
        :status (lab.theorem-workbench:theorem-target-status target)
        :representations (lab.theorem-workbench:theorem-target-representations target)
        :generic-search-authority :lsip
        :formal-authority :lab))

(defun %rh-render-report (target traces)
  (list :target (%rh-render-status target)
        :operator-families *rh-operator-families*
        :traces traces))

(defun %alist-value (object key)
  (cdr (assoc key object :test #'string=)))

(defun research-frontier-line->rh-target (line)
  (let* ((goal (%alist-value line "goal"))
         (metadata (%alist-value goal "metadata"))
         (source-logical-id (or (%alist-value goal "logical_id")
                                (%alist-value goal "alias")))
         (statement (%alist-value goal "statement_canonical")))
    (lab.theorem-workbench:make-theorem-target
     :id source-logical-id
     :statement statement
     :domain-id :rh
     :semantic-ref source-logical-id
     :status :open
     :representations *rh-representations*
     :provenance (list :source-system :txw7/research
                       :source-schema "ActiveRHFrontierV1"
                       :line-id (%alist-value line "line_id")
                       :source-paths (%alist-value line "source_paths")
                       :frontier-commits (%alist-value line "frontier_commits"))
     :metadata (list :source-metadata metadata
                     :authority :research-input-not-formal-proof))))

(defun register-rh-workbench ()
  (lab.theorem-workbench:register-domain
   (lab.theorem-workbench:make-theorem-domain-adapter
    :id :rh
    :compile-target-fn #'%rh-compile-target
    :generate-candidate-fn #'%rh-generate-candidate
    :project-obligations-fn #'%rh-project
    :check-candidate-fn #'%rh-check
    :extract-counterexample-fn #'%rh-counterexample
    :render-status-fn #'%rh-render-status
    :render-report-fn #'%rh-render-report
    :metadata (list :generic-search-authority :lsip
                    :formal-authority :lab
                    :research-authority :txw7/research)))
  (dolist (operator *rh-operator-families*)
    (lab.theorem-workbench:register-operator-family
     operator (list :domain :rh :search-authority :lsip)))
  (let ((target
          (lab.theorem-workbench:make-theorem-target
           :id *rh-first-contact-target-id*
           :statement (lab.math:math-claim-statement (rh-first-contact-claim))
           :domain-id :rh
           :semantic-ref *rh-first-contact-target-id*
           :status :open
           :representations *rh-representations*
           :provenance (lab.math:math-claim-provenance (rh-first-contact-claim))
           :metadata (list :initial-target :gaussian-first-contact))))
    (lab.theorem-workbench:register-target target))
  t)

(register-rh-workbench)
