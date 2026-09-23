(in-package :lab.math)

(defun %math-native-formal-fields (claim)
  (if (typep claim 'math-formal-native-claim)
      (list
       :formal-operation-id
       (math-formal-native-claim-formal-operation-id claim)
       :formal-argument-row
       (copy-tree
        (math-formal-native-claim-formal-args claim))
       :formal-proposition
       (copy-tree
        (math-formal-native-claim-target-proposition claim)))
      (list
       :formal-operation-id nil
       :formal-argument-row nil
       :formal-proposition nil)))

(defun math-claim->lsip-search-wire-v1
    (claim &key allowed-operator-family-refs representation revision-ref metadata)
  (unless (typep claim 'math-claim)
    (error "Expected MathClaimV1 carrier, got ~S" claim))
  (append
   (list
    :schema :lab-math-claim-v1
    :id (math-claim-id claim)
    :carrier-kind :formal-goal
    :statement (math-claim-statement claim)
    :status (math-claim-status claim)
    :domain-ref (math-claim-domain-ref claim)
    :dependency-refs
    (copy-list (math-claim-dependencies claim))
    :allowed-operator-family-refs
    (copy-list allowed-operator-family-refs)
    :representation representation
    :revision-ref revision-ref
    :provenance (copy-tree (math-claim-provenance claim))
    :metadata
    (append
     (copy-tree (math-claim-metadata claim))
     (copy-tree metadata)))
   (%math-native-formal-fields claim)))

(defun math-proof-problem->lsip-search-wire-v1
    (problem &key revision-ref metadata)
  (unless (typep problem 'math-proof-problem)
    (error "Expected MathProofProblemV1 carrier, got ~S" problem))
  (let ((claim
          (math-proof-problem-target-claim problem)))
    (unless (typep claim 'math-claim)
      (error "MathProofProblemV1 target must be a MathClaimV1 carrier for LSIP export"))
    (let ((row
            (math-claim->lsip-search-wire-v1
             claim
             :allowed-operator-family-refs
             (math-proof-problem-allowed-operator-classes problem)
             :representation
             (math-proof-problem-representation problem)
             :revision-ref revision-ref
             :metadata
             (append
              (list
               :proof-problem-id
               (math-proof-problem-id problem)
               :search-authority :lsip)
              (copy-tree
               (math-proof-problem-metadata problem))
              (copy-tree metadata)))))
      (setf (getf row :schema) :lab-math-proof-problem-v1)
      (setf (getf row :id) (math-proof-problem-id problem))
      (setf
       (getf row :provenance)
       (append
        (copy-tree
         (math-proof-problem-provenance problem))
        (list
         :target-claim-id
         (math-claim-id claim))))
      row)))
