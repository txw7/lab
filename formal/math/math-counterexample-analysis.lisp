(in-package :lab.math)

(defparameter *counterexample-analysis-feature-kinds-v1*
  '(:sign :monotonicity :convexity :positivity :near-maximality :rank
    :dimension :support-size :frequency-spread :symmetry :smoothness
    :decay :nondegeneracy :localization :spectral-gap :phase-concentration))

(defstruct (repair-condition-candidate-v1
            (:constructor %make-repair-condition-candidate-v1))
  condition-ref feature-kind condition-row counterexample-exclusion
  positive-example-preservation mathematical-simplicity theorem-compatibility
  formalizability rank-key metadata proof-effect)

(defstruct (counterexample-analysis-v1
            (:constructor %make-counterexample-analysis-v1))
  analysis-ref target-claim-ref counterexample-ref positive-example-refs
  feature-observations repair-candidates metadata proof-effect)

(defun make-repair-condition-candidate-v1
    (&key feature-kind condition-row counterexample-exclusion
      positive-example-preservation mathematical-simplicity theorem-compatibility
      formalizability metadata)
  (unless (member feature-kind *counterexample-analysis-feature-kinds-v1* :test #'eq)
    (error "Unknown repair feature kind ~S" feature-kind))
  (let* ((rank-key
           (list
            (- (or counterexample-exclusion 0))
            (- (or positive-example-preservation 0))
            (- (or mathematical-simplicity 0))
            (- (or theorem-compatibility 0))
            (- (or formalizability 0))))
         (ref
           (format nil "repair-condition:~A"
                   (%string-key
                    (list feature-kind condition-row rank-key metadata)))))
    (%make-repair-condition-candidate-v1
     :condition-ref ref :feature-kind feature-kind
     :condition-row (copy-tree condition-row)
     :counterexample-exclusion counterexample-exclusion
     :positive-example-preservation positive-example-preservation
     :mathematical-simplicity mathematical-simplicity
     :theorem-compatibility theorem-compatibility
     :formalizability formalizability
     :rank-key rank-key :metadata (copy-tree metadata)
     :proof-effect :none)))

(defun %repair-rank-less-p-v1 (left right)
  (loop for a in left for b in right
        when (< a b) do (return t)
        when (> a b) do (return nil)
        finally (return nil)))

(defun analyze-math-counterexample-v1
    (&key target-claim-ref counterexample-ref positive-example-refs
      feature-observations repair-candidates metadata)
  (dolist (row repair-candidates)
    (unless (typep row 'repair-condition-candidate-v1)
      (error "Counterexample repair candidate ~S has wrong type" row)))
  (let* ((ranked
           (sort (copy-list repair-candidates)
                 (lambda (a b)
                   (%repair-rank-less-p-v1
                    (repair-condition-candidate-v1-rank-key a)
                    (repair-condition-candidate-v1-rank-key b)))))
         (ref
           (format nil "counterexample-analysis:~A"
                   (%string-key
                    (list target-claim-ref counterexample-ref
                          positive-example-refs feature-observations
                          (mapcar #'repair-condition-candidate-v1-condition-ref ranked))))))
    (%make-counterexample-analysis-v1
     :analysis-ref ref :target-claim-ref target-claim-ref
     :counterexample-ref counterexample-ref
     :positive-example-refs (copy-list positive-example-refs)
     :feature-observations (copy-tree feature-observations)
     :repair-candidates ranked :metadata (copy-tree metadata)
     :proof-effect :none)))

(export
 '(*counterexample-analysis-feature-kinds-v1*
   repair-condition-candidate-v1 repair-condition-candidate-v1-condition-ref
   repair-condition-candidate-v1-feature-kind repair-condition-candidate-v1-rank-key
   repair-condition-candidate-v1-proof-effect
   make-repair-condition-candidate-v1
   counterexample-analysis-v1 counterexample-analysis-v1-analysis-ref
   counterexample-analysis-v1-repair-candidates
   counterexample-analysis-v1-proof-effect analyze-math-counterexample-v1)
 :lab.math)
