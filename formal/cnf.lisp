(in-package :mini-kernel)

(defstruct smt-cnf
  var-count
  clauses
  root-literal
  atom-table
  assumptions)

(defun lower-smt-to-boolean-core (term)
  (labels
      ((lower (current)
         (case (smt-tag current)
           (:bool current)
           (:var current)
           (:not (smt-not (lower (second current))))
           (:and (apply #'smt-and (mapcar #'lower (rest current))))
           (:or (apply #'smt-or (mapcar #'lower (rest current))))
           (:xor
            (let ((a (lower (second current)))
                  (b (lower (third current))))
              (smt-or (smt-and a (smt-not b))
                      (smt-and (smt-not a) b))))
           (:=>
            (lower (smt-or (smt-not (second current)) (third current))))
           (:ite
            (let ((c (lower (second current)))
                  (t-branch (lower (third current)))
                  (e-branch (lower (fourth current))))
              (smt-or (smt-and c t-branch)
                      (smt-and (smt-not c) e-branch))))
           (:= 
            (let ((a (lower (second current)))
                  (b (lower (third current))))
              (smt-or (smt-and a b)
                      (smt-and (smt-not a) (smt-not b)))))
           (otherwise
            (kernel-error "term is not in Boolean CNF fragment: ~S" current)))))
    (normalize-smt-term (lower term))))

(defun compile-boolean-core-to-cnf (core)
  (let ((next-var 0)
        (clauses '())
        (atom-table (make-hash-table :test #'equal))
        (assumptions '()))
    (labels
        ((fresh-var ()
           (incf next-var))
         (emit (&rest clause)
           (push clause clauses))
         (atom-var (atom)
           (or (gethash atom atom-table)
               (setf (gethash atom atom-table) (fresh-var))))
         (lit-for (current)
           (case (smt-tag current)
             (:bool
              (let ((v (fresh-var)))
                (emit (if (smt-bool-true-p current) v (- v)))
                v))
             (:var
              (atom-var current))
             (:not
              (- (lit-for (second current))))
             (:and
              (let* ((children (mapcar #'lit-for (rest current)))
                     (v (fresh-var)))
                (dolist (child children)
                  (emit (- v) child))
                (emit v)
                (dolist (child children)
                  (setf (car clauses) (append (car clauses) (list (- child)))))
                v))
             (:or
              (let* ((children (mapcar #'lit-for (rest current)))
                     (v (fresh-var)))
                (dolist (child children)
                  (emit v (- child)))
                (emit (- v))
                (dolist (child children)
                  (setf (car clauses) (append (car clauses) (list child))))
                v))
             (otherwise
              (kernel-error "CNF compiler expected Boolean core term, got ~S" current)))))
      (let ((root (lit-for core)))
        (emit root)
        (make-smt-cnf
         :var-count next-var
         :clauses (nreverse clauses)
         :root-literal root
         :atom-table atom-table
         :assumptions (nreverse assumptions))))))

(defun compile-smt-to-cnf (term)
  (compile-boolean-core-to-cnf (lower-smt-to-boolean-core term)))

(defun compile-boolean-core-to-cnf-with-assumptions (assumptions formula-core)
  (let* ((cnf (compile-boolean-core-to-cnf formula-core))
         (next-var (smt-cnf-var-count cnf))
         (clauses (copy-list (smt-cnf-clauses cnf)))
         (table (make-hash-table :test #'equal))
         (entries '()))
    (maphash (lambda (k v) (setf (gethash k table) v))
             (smt-cnf-atom-table cnf))
    (dolist (entry assumptions)
      (destructuring-bind (assumption-id assumption-term) entry
        (let ((literal
                 (labels
                     ((fresh-var ()
                        (incf next-var))
                      (emit (&rest clause)
                        (push clause clauses))
                      (atom-var (atom)
                        (or (gethash atom table)
                            (setf (gethash atom table) (fresh-var))))
                      (lit-for (current)
                        (case (smt-tag current)
                          (:bool
                           (let ((v (fresh-var)))
                             (emit (if (smt-bool-true-p current) v (- v)))
                             v))
                          (:var (atom-var current))
                          (:not (- (lit-for (second current))))
                          (:and
                           (let* ((children (mapcar #'lit-for (rest current)))
                                  (v (fresh-var)))
                             (dolist (child children)
                               (emit (- v) child))
                             (emit v)
                             (dolist (child children)
                               (setf (car clauses) (append (car clauses) (list (- child)))))
                             v))
                          (:or
                           (let* ((children (mapcar #'lit-for (rest current)))
                                  (v (fresh-var)))
                             (dolist (child children)
                               (emit v (- child)))
                             (emit (- v))
                             (dolist (child children)
                               (setf (car clauses) (append (car clauses) (list child))))
                             v))
                          (otherwise
                           (kernel-error "CNF compiler expected Boolean core term, got ~S" current)))))
                   (lit-for assumption-term))))
          (push (list assumption-id literal) entries))))
    (make-smt-cnf
     :var-count next-var
     :clauses (nreverse clauses)
     :root-literal (smt-cnf-root-literal cnf)
     :atom-table table
     :assumptions (nreverse entries))))

(defun compile-smt-to-cnf-with-assumptions (assumptions formula)
  (compile-boolean-core-to-cnf-with-assumptions
   (mapcar (lambda (entry)
             (destructuring-bind (assumption-id assumption-term) entry
               (list assumption-id (lower-smt-to-boolean-core assumption-term))))
           assumptions)
   (lower-smt-to-boolean-core formula)))

(defun eval-cnf-clause (clause assignment)
  (some (lambda (literal)
          (let* ((index (1- (abs literal)))
                 (value (aref assignment index)))
            (if (minusp literal) (not value) value)))
        clause))

(defun eval-cnf (cnf assignment)
  (every (lambda (clause) (eval-cnf-clause clause assignment))
         (smt-cnf-clauses cnf)))

(defun smt-cnf-sat-bruteforce (cnf)
  (let* ((n (smt-cnf-var-count cnf))
         (limit (ash 1 n)))
    (loop for mask from 0 below limit
          thereis
          (let ((assignment (make-array n :element-type 'boolean :initial-element nil)))
            (dotimes (i n)
              (setf (aref assignment i) (not (zerop (logand mask (ash 1 i))))))
            (when (eval-cnf cnf assignment)
              assignment)))))

(defun solve-cnf-under-assumptions-dpll (cnf &optional assumptions)
  (let ((assignment (make-array (smt-cnf-var-count cnf) :initial-element :unassigned)))
    (dolist (assumption assumptions)
      (unless (%set-literal! assumption assignment)
        (return-from solve-cnf-under-assumptions-dpll nil)))
    (labels
        ((dpll-search (current)
           (when (%unit-propagate! (smt-cnf-clauses cnf) current)
             (let ((next (%choose-unassigned-var current)))
               (if (null next)
                   current
                   (or (let ((left (%copy-assignment current)))
                         (setf (aref left next) t)
                         (dpll-search left))
                       (let ((right (%copy-assignment current)))
                         (setf (aref right next) nil)
                         (dpll-search right))))))))
      (dpll-search assignment))))

(defun smt-cnf-unsat-core (cnf)
  (let ((entries (smt-cnf-assumptions cnf)))
    (when (solve-cnf-under-assumptions-dpll cnf (mapcar #'second entries))
      (return-from smt-cnf-unsat-core nil))
    (let ((core (copy-list entries)))
      (dolist (entry entries)
        (let* ((trial (remove entry core :test #'equal))
               (trial-lits (mapcar #'second trial)))
          (unless (solve-cnf-under-assumptions-dpll cnf trial-lits)
            (setf core trial))))
      (mapcar #'first core))))
