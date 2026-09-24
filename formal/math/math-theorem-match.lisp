(in-package :lab.math)

(defparameter *math-theorem-hypothesis-statuses-v1*
  '(:already-discharged :derivable :new-subgoal :incompatible :unknown))

(defstruct (math-theorem-match-v1 (:constructor %make-math-theorem-match-v1))
  match-ref theorem-ref target-ref conclusion-status substitution
  hypothesis-statuses diagnostics metadata proof-effect)

(defun %math-expression-unify-v1 (pattern target substitution)
  (cond
    ((and (typep pattern 'math-expression)
          (eq (math-expression-op pattern) :variable)
          (math-expression-name pattern))
     (let ((existing
             (assoc (math-expression-name pattern)
                    substitution :test #'equal)))
       (if existing
           (values
            substitution
            (and (typep target 'math-expression)
                 (string=
                  (math-expression-key (cdr existing))
                  (math-expression-key target))))
           (values
            (acons (math-expression-name pattern) target substitution)
            t))))
    ((or (not (typep pattern 'math-expression))
         (not (typep target 'math-expression))
         (not (eq (math-expression-op pattern)
                  (math-expression-op target)))
         (not (equal (math-expression-value pattern)
                     (math-expression-value target)))
         (not (equal (math-expression-name pattern)
                     (math-expression-name target)))
         (/= (length (math-expression-args pattern))
             (length (math-expression-args target))))
     (values substitution nil))
    (t
     (loop
       with current = substitution
       for p in (math-expression-args pattern)
       for q in (math-expression-args target)
       do
          (multiple-value-bind (next matched-p)
              (%math-expression-unify-v1 p q current)
            (unless matched-p
              (return-from %math-expression-unify-v1
                (values substitution nil)))
            (setf current next))
       finally (return (values current t))))))

(defun %math-expression-substitute-v1 (expression substitution)
  (if (and (typep expression 'math-expression)
           (eq (math-expression-op expression) :variable)
           (math-expression-name expression))
      (or
       (cdr
        (assoc (math-expression-name expression)
               substitution :test #'equal))
       expression)
      (if (typep expression 'math-expression)
          (%make-math-expression
           :op (math-expression-op expression)
           :args
           (mapcar
            (lambda (arg)
              (%math-expression-substitute-v1 arg substitution))
            (math-expression-args expression))
           :value (math-expression-value expression)
           :name (math-expression-name expression)
           :metadata (copy-tree (math-expression-metadata expression)))
          expression)))

(defun %theorem-hypothesis-status-v1
    (required available-hypotheses)
  (let* ((results
           (mapcar
            (lambda (available)
              (math-subsumption-v1 available required))
            available-hypotheses))
         (statuses
           (mapcar #'math-subsumption-result-v1-status results)))
    (cond
      ((some
        (lambda (item)
          (member item '(:equivalent :subsumes) :test #'eq))
        statuses)
       :already-discharged)
      ((null available-hypotheses)
       :new-subgoal)
      ((every
        (lambda (item)
          (eq item :does-not-subsume))
        statuses)
       :incompatible)
      ((some
        (lambda (item)
          (eq item :unknown))
        statuses)
       :unknown)
      (t :new-subgoal))))

(defun match-math-theorem-v1
    (&key theorem-ref theorem-conclusion target-ref target-expression
      required-hypotheses available-hypotheses metadata)
  (multiple-value-bind (substitution unified-p)
      (%math-expression-unify-v1
       theorem-conclusion target-expression '())
    (let* ((conclusion-result
             (unless unified-p
               (math-subsumption-v1
                theorem-conclusion target-expression)))
           (conclusion-status
             (if unified-p
                 :matched
                 (case
                     (math-subsumption-result-v1-status
                      conclusion-result)
                   ((:equivalent :subsumes) :matched)
                   (:does-not-subsume :incompatible)
                   (otherwise :unknown))))
           (hypothesis-statuses
             (mapcar
              (lambda (required)
                (let* ((required*
                         (%math-expression-substitute-v1
                          required substitution))
                       (status
                         (%theorem-hypothesis-status-v1
                          required* available-hypotheses)))
                  (unless
                      (member
                       status
                       *math-theorem-hypothesis-statuses-v1*
                       :test #'eq)
                    (error
                     "Unknown theorem-match hypothesis status ~S"
                     status))
                  (list
                   :required
                   (math-expression-key required*)
                   :status status)))
              required-hypotheses))
           (substitution-row
             (mapcar
              (lambda (pair)
                (cons
                 (car pair)
                 (math-expression-key (cdr pair))))
              substitution))
           (fields
             (list theorem-ref target-ref conclusion-status
                   substitution-row hypothesis-statuses metadata))
           (ref
             (format nil "math-theorem-match:~A"
                     (%string-key fields))))
      (%make-math-theorem-match-v1
       :match-ref ref
       :theorem-ref theorem-ref
       :target-ref target-ref
       :conclusion-status conclusion-status
       :substitution substitution-row
       :hypothesis-statuses hypothesis-statuses
       :diagnostics
       (cond
         ((eq conclusion-status :incompatible)
          (list :conclusion-mismatch t))
         ((eq conclusion-status :unknown)
          (list :conclusion-match-unknown t))
         (t '()))
       :metadata (copy-tree metadata)
       :proof-effect :none))))

(export
 '(math-theorem-match-v1
   math-theorem-match-v1-match-ref
   math-theorem-match-v1-conclusion-status
   math-theorem-match-v1-substitution
   math-theorem-match-v1-hypothesis-statuses
   math-theorem-match-v1-proof-effect
   match-math-theorem-v1)
 :lab.math)
