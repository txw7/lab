(in-package :lab.math)

(defparameter *analytic-side-condition-kinds-v1*
  '(:absolute-convergence :uniform-convergence :dominated-convergence
    :local-uniformity :holomorphic-domain :meromorphic-pole-exclusion
    :integrability :boundary-decay :termwise-differentiability
    :termwise-integrability :contour-admissibility
    :distributional-validity))

(defstruct (analytic-side-condition-v1
            (:constructor %make-analytic-side-condition-v1))
  condition-ref kind target-ref condition-expression domain-ref status
  provenance metadata proof-effect)

(defstruct (saddle-analysis-v1
            (:constructor %make-saddle-analysis-v1))
  analysis-ref source-expression-ref stationary-point curvature width
  dominant-region tail-estimates assumptions diagnostics status
  provenance metadata proof-effect)

(defstruct (extremizer-search-v1
            (:constructor %make-extremizer-search-v1))
  search-ref target-claim-ref equality-cases near-equality-cases extremizers
  generated-conjecture-refs normalization-refs missing-hypothesis-refs
  model-family-refs status provenance metadata proof-effect)

(defun make-analytic-side-condition-v1
    (&key condition-ref kind target-ref condition-expression domain-ref
      (status :open) provenance metadata)
  (unless (member kind *analytic-side-condition-kinds-v1* :test #'eq)
    (error "Unknown AnalyticSideConditionV1 kind ~S." kind))
  (%make-analytic-side-condition-v1
   :condition-ref
   (or condition-ref
       (format nil "analytic-side-condition:~A"
               (%string-key
                (list kind target-ref condition-expression domain-ref
                      status provenance))))
   :kind kind :target-ref target-ref
   :condition-expression condition-expression
   :domain-ref domain-ref :status status
   :provenance (copy-tree provenance)
   :metadata (copy-tree metadata)
   :proof-effect :none))

(defun make-saddle-analysis-v1
    (&key analysis-ref source-expression-ref stationary-point curvature width
      dominant-region tail-estimates assumptions diagnostics
      (status :candidate) provenance metadata)
  (%make-saddle-analysis-v1
   :analysis-ref
   (or analysis-ref
       (format nil "saddle-analysis:~A"
               (%string-key
                (list source-expression-ref stationary-point curvature width
                      dominant-region tail-estimates assumptions
                      diagnostics status provenance))))
   :source-expression-ref source-expression-ref
   :stationary-point stationary-point
   :curvature curvature
   :width width
   :dominant-region (copy-tree dominant-region)
   :tail-estimates (copy-tree tail-estimates)
   :assumptions (copy-tree assumptions)
   :diagnostics (copy-tree diagnostics)
   :status status
   :provenance (copy-tree provenance)
   :metadata (copy-tree metadata)
   :proof-effect :none))

(defun make-extremizer-search-v1
    (&key search-ref target-claim-ref equality-cases near-equality-cases
      extremizers generated-conjecture-refs normalization-refs
      missing-hypothesis-refs model-family-refs
      (status :candidate) provenance metadata)
  (%make-extremizer-search-v1
   :search-ref
   (or search-ref
       (format nil "extremizer-search:~A"
               (%string-key
                (list target-claim-ref equality-cases near-equality-cases
                      extremizers generated-conjecture-refs
                      normalization-refs missing-hypothesis-refs
                      model-family-refs status provenance))))
   :target-claim-ref target-claim-ref
   :equality-cases (copy-tree equality-cases)
   :near-equality-cases (copy-tree near-equality-cases)
   :extremizers (copy-tree extremizers)
   :generated-conjecture-refs (copy-list generated-conjecture-refs)
   :normalization-refs (copy-list normalization-refs)
   :missing-hypothesis-refs (copy-list missing-hypothesis-refs)
   :model-family-refs (copy-list model-family-refs)
   :status status
   :provenance (copy-tree provenance)
   :metadata (copy-tree metadata)
   :proof-effect :none))

(export
 '(*analytic-side-condition-kinds-v1*
   analytic-side-condition-v1
   analytic-side-condition-v1-condition-ref
   analytic-side-condition-v1-kind
   analytic-side-condition-v1-status
   analytic-side-condition-v1-proof-effect
   make-analytic-side-condition-v1
   saddle-analysis-v1 saddle-analysis-v1-analysis-ref
   saddle-analysis-v1-stationary-point saddle-analysis-v1-curvature
   saddle-analysis-v1-width saddle-analysis-v1-status
   saddle-analysis-v1-proof-effect make-saddle-analysis-v1
   extremizer-search-v1 extremizer-search-v1-search-ref
   extremizer-search-v1-target-claim-ref
   extremizer-search-v1-equality-cases
   extremizer-search-v1-near-equality-cases
   extremizer-search-v1-extremizers
   extremizer-search-v1-missing-hypothesis-refs
   extremizer-search-v1-status extremizer-search-v1-proof-effect
   make-extremizer-search-v1)
 :lab.math)
