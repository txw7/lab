(in-package :mini-kernel)

(defun %literal-var-index (literal)
  (1- (abs literal)))

(defun %literal-value (literal assignment)
  (let ((value (aref assignment (%literal-var-index literal))))
    (cond
      ((eq value :unassigned) :unassigned)
      ((minusp literal) (not value))
      (t value))))

(defun %set-literal! (literal assignment)
  (let* ((index (%literal-var-index literal))
         (target (plusp literal))
         (current (aref assignment index)))
    (cond
      ((eq current :unassigned)
       (setf (aref assignment index) target)
       t)
      ((eql current target)
       t)
      (t
       nil))))

(defun %unit-propagate! (clauses assignment)
  (loop
    with changed = nil
    do (setf changed nil)
       (dolist (clause clauses)
         (let ((satisfied nil)
               (unassigned '()))
           (dolist (literal clause)
             (let ((value (%literal-value literal assignment)))
               (cond
                 ((eq value t)
                  (setf satisfied t)
                  (return))
                 ((eq value :unassigned)
                  (push literal unassigned)))))
           (unless satisfied
             (cond
               ((endp unassigned)
                (return-from %unit-propagate! nil))
               ((endp (rest unassigned))
                (unless (%set-literal! (first unassigned) assignment)
                  (return-from %unit-propagate! nil))
                (setf changed t))))))
    while changed
    finally (return t)))

(defun %choose-unassigned-var (assignment)
  (position :unassigned assignment))

(defun %copy-assignment (assignment)
  (let ((copy (make-array (length assignment))))
    (dotimes (i (length assignment))
      (setf (aref copy i) (aref assignment i)))
    copy))

(defun solve-cnf-dpll (cnf)
  (solve-cnf-under-assumptions-dpll cnf))
