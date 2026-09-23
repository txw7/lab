(in-package :lab.math)

(defparameter *math-theorem-hypothesis-statuses-v1*
  '(:already-discharged :derivable :new-subgoal :incompatible :unknown))

(defstruct (math-theorem-match-v1 (:constructor %make-math-theorem-match-v1))
  match-ref theorem-ref target-ref conclusion-status substitution
  hypothesis-statuses diagnostics metadata proof-effect)

(defun %rename-math-expression-v1 (expression notation-map)
  (unless (typep expression 'math-expression)
    (error "Expected MathExpressionV1 for notation renaming"))
  (if (eq (math-expression-op expression) :variable)
      (let* ((name (math-expression-name expression))
             (mapped (cdr (assoc name notation-map :test #'string=))))
        (make-math-expression-v1
         :variable
         :name (or mapped name)
         :metadata (copy-tree (math-expression-metadata expression))))
      (apply
       #'make-math-expression-v1
       (math-expression-op expression)
       (append
        (mapcar
         (lambda (arg)
           (if (typep arg 'math-expression)
               (%rename-math-expression-v1 arg notation-map)
               arg))
         (math-expression-args expression))
        (when (math-expression-value expression)
          (list :value (math-expression-value expression)))
        (when (math-expression-name expression)
          (list :name (math-expression-name expression)))
        (list :metadata
              (copy-tree (math-expression-metadata expression)))))))

(defun match-math-theorem-v1
    (&key theorem-ref theorem-conclusion target-ref target-expression
      required-hypotheses available-hypotheses notation-map metadata)
  (let* ((normalized-conclusion
           (%rename-math-expression-v1
            theorem-conclusion
            (or notation-map '())))
         (normalized-hypotheses
           (mapcar
            (lambda (required)
              (%rename-math-expression-v1 required (or notation-map '())))
            required-hypotheses))
         (conclusion-result
           (math-subsumption-v1 normalized-conclusion target-expression))
         (conclusion-status
           (case (math-subsumption-result-v1-status conclusion-result)
             ((:equivalent :subsumes) :matched)
             (:does-not-subsume :incompatible)
             (otherwise :unknown)))
         (hypothesis-statuses
           (mapcar
            (lambda (required)
              (let ((status
                      (cond
                        ((find-if
                          (lambda (available)
                            (member
                             (math-subsumption-result-v1-status
                              (math-subsumption-v1 available required))
                             '(:equivalent :subsumes)
                             :test #'eq))
                          available-hypotheses)
                         :already-discharged)
                        (t :new-subgoal))))
                (unless
                    (member status *math-theorem-hypothesis-statuses-v1*
                            :test #'eq)
                  (error "Unknown theorem-match hypothesis status ~S" status))
                (list :required (math-expression-key required)
                      :status status)))
            normalized-hypotheses))
         (fields (list theorem-ref target-ref conclusion-status
                       notation-map hypothesis-statuses metadata))
         (ref (format nil "math-theorem-match:~A" (%string-key fields))))
    (%make-math-theorem-match-v1
     :match-ref ref :theorem-ref theorem-ref :target-ref target-ref
     :conclusion-status conclusion-status
     :substitution (copy-tree notation-map)
     :hypothesis-statuses hypothesis-statuses
     :diagnostics
     (if (eq conclusion-status :incompatible)
         (list :conclusion-mismatch t)
         '())
     :metadata (copy-tree metadata) :proof-effect :none)))

(export
 '(math-theorem-match-v1 math-theorem-match-v1-match-ref
   math-theorem-match-v1-conclusion-status
   math-theorem-match-v1-hypothesis-statuses
   math-theorem-match-v1-proof-effect
   match-math-theorem-v1)
 :lab.math)
