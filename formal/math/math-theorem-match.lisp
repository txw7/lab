(in-package :lab.math)

(defparameter *math-theorem-hypothesis-statuses-v1*
  '(:already-discharged :derivable :new-subgoal :incompatible :unknown))

(defstruct (math-theorem-match-v1 (:constructor %make-math-theorem-match-v1))
  match-ref theorem-ref target-ref conclusion-status substitution
  hypothesis-statuses diagnostics metadata proof-effect)

(defun match-math-theorem-v1
    (&key theorem-ref theorem-conclusion target-ref target-expression
      required-hypotheses available-hypotheses metadata)
  (let* ((conclusion-result
           (math-subsumption-v1 theorem-conclusion target-expression))
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
            required-hypotheses))
         (fields (list theorem-ref target-ref conclusion-status
                       hypothesis-statuses metadata))
         (ref (format nil "math-theorem-match:~A" (%string-key fields))))
    (%make-math-theorem-match-v1
     :match-ref ref :theorem-ref theorem-ref :target-ref target-ref
     :conclusion-status conclusion-status :substitution nil
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
