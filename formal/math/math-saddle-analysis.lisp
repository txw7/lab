(in-package :lab.math)

(defstruct (saddle-analysis-v1 (:constructor %make-saddle-analysis-v1))
  analysis-ref source-expression-ref variable-ref stationary-point curvature
  width dominant-region tail-estimate assumptions diagnostics status
  provenance metadata proof-effect)

(defun make-saddle-analysis-v1
    (&key analysis-ref source-expression-ref variable-ref stationary-point
      curvature width dominant-region tail-estimate assumptions diagnostics
      (status :candidate) provenance metadata)
  (%make-saddle-analysis-v1
   :analysis-ref
   (or analysis-ref
       (format nil "saddle-analysis:~A"
               (%string-key
                (list source-expression-ref variable-ref stationary-point
                      curvature width dominant-region tail-estimate
                      assumptions diagnostics))))
   :source-expression-ref source-expression-ref
   :variable-ref variable-ref
   :stationary-point stationary-point
   :curvature curvature
   :width width
   :dominant-region dominant-region
   :tail-estimate tail-estimate
   :assumptions (copy-tree assumptions)
   :diagnostics (copy-tree diagnostics)
   :status status
   :provenance (copy-tree provenance)
   :metadata (copy-tree metadata)
   :proof-effect :none))

(export
 '(saddle-analysis-v1
   saddle-analysis-v1-analysis-ref
   saddle-analysis-v1-stationary-point
   saddle-analysis-v1-curvature
   saddle-analysis-v1-width
   saddle-analysis-v1-dominant-region
   saddle-analysis-v1-tail-estimate
   saddle-analysis-v1-status
   saddle-analysis-v1-proof-effect
   make-saddle-analysis-v1)
 :lab.math)
