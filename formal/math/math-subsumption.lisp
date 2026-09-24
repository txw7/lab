(in-package :lab.math)

(defstruct (math-subsumption-result-v1
            (:constructor %make-math-subsumption-result-v1))
  status stronger-ref weaker-ref evidence-row diagnostics proof-effect)

(defun %comparison-shape-v1 (expression)
  (when (and (typep expression 'math-expression)
             (member (math-expression-op expression)
                     '(:gt :ge :lt :le) :test #'eq)
             (= 2 (length (math-expression-args expression))))
    (let ((left (first (math-expression-args expression)))
          (right (second (math-expression-args expression))))
      (when (and (typep left 'math-expression)
                 (eq (math-expression-op left) :variable)
                 (typep right 'math-expression)
                 (eq (math-expression-op right) :constant)
                 (numberp (math-expression-value right)))
        (list :op (math-expression-op expression)
              :variable (math-expression-name left)
              :bound (math-expression-value right))))))

(defun math-subsumption-v1 (stronger weaker)
  (cond
    ((string= (math-expression-key stronger)
              (math-expression-key weaker))
     (%make-math-subsumption-result-v1
      :status :equivalent
      :stronger-ref (math-expression-key stronger)
      :weaker-ref (math-expression-key weaker)
      :evidence-row (list :kind :canonical-expression-equality)
      :diagnostics '()
      :proof-effect :none))
    (t
     (let ((a (%comparison-shape-v1 stronger))
           (b (%comparison-shape-v1 weaker)))
       (if (and a b
                (equal (getf a :variable) (getf b :variable)))
           (let* ((op (getf a :op))
                  (required-op (getf b :op))
                  (x (getf a :bound))
                  (y (getf b :bound))
                  (subsumes
                    (cond
                      ((and (member op '(:gt :ge) :test #'eq)
                            (member required-op '(:gt :ge) :test #'eq))
                       (or (> x y)
                           (and (= x y)
                                (or (eq op :gt)
                                    (eq required-op :ge)))))
                      ((and (member op '(:lt :le) :test #'eq)
                            (member required-op '(:lt :le) :test #'eq))
                       (or (< x y)
                           (and (= x y)
                                (or (eq op :lt)
                                    (eq required-op :le)))))
                      (t nil))))
             (%make-math-subsumption-result-v1
              :status (if subsumes :subsumes :does-not-subsume)
              :stronger-ref (math-expression-key stronger)
              :weaker-ref (math-expression-key weaker)
              :evidence-row
              (list :kind :ordered-bound-comparison
                    :stronger-operator op :required-operator required-op
                    :stronger-bound x :weaker-bound y)
              :diagnostics '()
              :proof-effect :none))
           (%make-math-subsumption-result-v1
            :status :unknown
            :stronger-ref (math-expression-key stronger)
            :weaker-ref (math-expression-key weaker)
            :evidence-row nil
            :diagnostics (list :unsupported-shape t)
            :proof-effect :none))))))

(export
 '(math-subsumption-result-v1 math-subsumption-result-v1-status
   math-subsumption-result-v1-evidence-row
   math-subsumption-result-v1-diagnostics
   math-subsumption-result-v1-proof-effect
   math-subsumption-v1)
 :lab.math)
