(in-package :lab.math)

(defparameter *math-experiment-classes-v1*
  '(:parameter-scan :finite-truncation :randomized-model
    :adversarial-optimization :symbolic-simplification
    :asymptotic-scaling :extremizer-search :equality-case-search
    :sensitivity-analysis))

(defstruct (math-experiment-v1 (:constructor %make-math-experiment-v1))
  experiment-ref class hypothesis expected-result configuration result
  interpretation-status status provenance metadata proof-effect)

(defun make-math-experiment-v1
    (&key experiment-ref class hypothesis expected-result configuration
      (status :proposed) provenance metadata)
  (unless (member class *math-experiment-classes-v1* :test #'eq)
    (error "Unknown MathExperimentV1 class ~S" class))
  (%make-math-experiment-v1
   :experiment-ref
   (or experiment-ref
       (format nil "math-experiment:~A"
               (%string-key
                (list class hypothesis expected-result configuration provenance))))
   :class class :hypothesis hypothesis :expected-result expected-result
   :configuration (copy-tree configuration) :result nil
   :interpretation-status :not-run :status status
   :provenance (copy-tree provenance) :metadata (copy-tree metadata)
   :proof-effect :none))

(defun complete-math-experiment-v1
    (experiment result interpretation-status &key metadata)
  (%make-math-experiment-v1
   :experiment-ref (math-experiment-v1-experiment-ref experiment)
   :class (math-experiment-v1-class experiment)
   :hypothesis (math-experiment-v1-hypothesis experiment)
   :expected-result (math-experiment-v1-expected-result experiment)
   :configuration (copy-tree (math-experiment-v1-configuration experiment))
   :result (copy-tree result)
   :interpretation-status interpretation-status
   :status :completed
   :provenance (copy-tree (math-experiment-v1-provenance experiment))
   :metadata (append (copy-tree (math-experiment-v1-metadata experiment))
                     (copy-tree metadata))
   :proof-effect :none))

(export
 '(math-experiment-v1 math-experiment-v1-experiment-ref
   math-experiment-v1-class math-experiment-v1-result
   math-experiment-v1-interpretation-status math-experiment-v1-status
   math-experiment-v1-proof-effect make-math-experiment-v1
   complete-math-experiment-v1)
 :lab.math)
