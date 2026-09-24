(in-package :lab.math)

(defparameter *math-asymptotic-relation-kinds-v1*
  '(:big-o :little-o :asymptotic-equivalent :comparable :dominates :uniform-big-o))

(defstruct (math-asymptotic-relation-v1
            (:constructor %make-math-asymptotic-relation-v1))
  relation-ref kind lhs rhs limit-variable limit-direction parameter-domain
  uniformity-variables constant-dependencies provenance metadata proof-effect)

(defstruct (dominant-balance-v1 (:constructor %make-dominant-balance-v1))
  balance-ref source-expression-ref candidate-scale relation assumptions
  diagnostics status metadata proof-effect)

(defun make-math-asymptotic-relation-v1
    (&key relation-ref kind lhs rhs limit-variable limit-direction parameter-domain
      uniformity-variables constant-dependencies provenance metadata)
  (unless (member kind *math-asymptotic-relation-kinds-v1* :test #'eq)
    (error "Unknown asymptotic relation kind ~S" kind))
  (let ((ref (or relation-ref
                 (format nil "math-asymptotic-relation:~A"
                         (%string-key
                          (list kind lhs rhs limit-variable limit-direction
                                parameter-domain uniformity-variables
                                constant-dependencies))))))
    (%make-math-asymptotic-relation-v1
     :relation-ref ref :kind kind :lhs lhs :rhs rhs
     :limit-variable limit-variable :limit-direction limit-direction
     :parameter-domain parameter-domain
     :uniformity-variables (copy-list uniformity-variables)
     :constant-dependencies (copy-list constant-dependencies)
     :provenance (copy-tree provenance) :metadata (copy-tree metadata)
     :proof-effect :none)))

(defun make-dominant-balance-v1
    (&key balance-ref source-expression-ref candidate-scale relation assumptions
      diagnostics (status :candidate) metadata)
  (%make-dominant-balance-v1
   :balance-ref
   (or balance-ref
       (format nil "dominant-balance:~A"
               (%string-key
                (list source-expression-ref candidate-scale relation assumptions))))
   :source-expression-ref source-expression-ref
   :candidate-scale candidate-scale :relation relation
   :assumptions (copy-tree assumptions) :diagnostics (copy-tree diagnostics)
   :status status :metadata (copy-tree metadata) :proof-effect :none))

(export
 '(math-asymptotic-relation-v1 math-asymptotic-relation-v1-relation-ref
   math-asymptotic-relation-v1-kind math-asymptotic-relation-v1-proof-effect
   make-math-asymptotic-relation-v1
   dominant-balance-v1 dominant-balance-v1-balance-ref
   dominant-balance-v1-candidate-scale dominant-balance-v1-status
   dominant-balance-v1-proof-effect make-dominant-balance-v1)
 :lab.math)
