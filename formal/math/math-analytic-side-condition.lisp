(in-package :lab.math)

(defparameter *analytic-side-condition-kinds-v1*
  '(:absolute-convergence :uniform-convergence :dominated-convergence
    :local-uniformity :holomorphic-domain :meromorphic-pole-exclusion
    :integrability :boundary-decay :termwise-differentiability
    :termwise-integrability :contour-admissibility :distributional-validity))

(defstruct (analytic-side-condition-v1
            (:constructor %make-analytic-side-condition-v1))
  condition-ref kind source-transformation-ref subject-ref domain-row
  statement status evidence-ref provenance metadata proof-effect)

(defun make-analytic-side-condition-v1
    (&key condition-ref kind source-transformation-ref subject-ref domain-row
      statement (status :open) evidence-ref provenance metadata)
  (unless (member kind *analytic-side-condition-kinds-v1* :test #'eq)
    (error "Unknown AnalyticSideConditionV1 kind ~S" kind))
  (%make-analytic-side-condition-v1
   :condition-ref
   (or condition-ref
       (format nil "analytic-side-condition:~A"
               (%string-key
                (list kind source-transformation-ref subject-ref
                      domain-row statement status))))
   :kind kind
   :source-transformation-ref source-transformation-ref
   :subject-ref subject-ref
   :domain-row (copy-tree domain-row)
   :statement statement
   :status status
   :evidence-ref evidence-ref
   :provenance (copy-tree provenance)
   :metadata (copy-tree metadata)
   :proof-effect :none))

(defun analytic-side-conditions-for-transformation-v1
    (transformation-kind &key source-transformation-ref subject-ref domain-row)
  (let ((kinds
          (case transformation-kind
            (:differentiate-under-integral
             '(:dominated-convergence :termwise-differentiability))
            (:interchange-limit-integral
             '(:dominated-convergence :local-uniformity))
            (:exchange-infinite-sums
             '(:absolute-convergence :uniform-convergence))
            (:termwise-integration
             '(:termwise-integrability :absolute-convergence))
            (:fourier-inversion
             '(:integrability :boundary-decay))
            (:mellin-inversion
             '(:integrability :holomorphic-domain :boundary-decay))
            (:contour-displacement
             '(:contour-admissibility :meromorphic-pole-exclusion
               :boundary-decay))
            (:improper-integration-by-parts
             '(:integrability :boundary-decay))
            (:analytic-continuation
             '(:holomorphic-domain :meromorphic-pole-exclusion))
            (otherwise
             (error "Unsupported analytic transformation ~S"
                    transformation-kind)))))
    (mapcar
     (lambda (kind)
       (make-analytic-side-condition-v1
        :kind kind
        :source-transformation-ref source-transformation-ref
        :subject-ref subject-ref
        :domain-row domain-row
        :statement
        (format nil "~(~A~) required for ~(~A~)"
                kind transformation-kind)
        :metadata (list :transformation-kind transformation-kind)))
     kinds)))

(export
 '(*analytic-side-condition-kinds-v1*
   analytic-side-condition-v1
   analytic-side-condition-v1-condition-ref
   analytic-side-condition-v1-kind
   analytic-side-condition-v1-status
   analytic-side-condition-v1-proof-effect
   make-analytic-side-condition-v1
   analytic-side-conditions-for-transformation-v1)
 :lab.math)
