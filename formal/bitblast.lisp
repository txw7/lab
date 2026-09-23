(in-package :mini-kernel)

(defun %smt-bool-var-for-bit (name index)
  (smt-var (list name index) (smt-bool-sort)))

(defun %bitblast-bv-term (term env &optional bool-bitblaster)
  (labels
      ((bb (current)
         (case (smt-tag current)
           (:bv-lit
            (let ((width (smt-bv-width current))
                  (value (smt-bv-value current)))
              (loop for i from 0 below width
                    collect (smt-bool-const (logbitp i value)))))
           (:var
            (destructuring-bind (_ name sort) current
              (declare (ignore _))
              (unless (equal (smt-sort-kind sort) :BV)
                (kernel-error "bit-blast expected BV var, got ~S" current))
              (or (gethash current env)
                  (setf (gethash current env)
                        (loop for i from 0 below (second sort)
                              collect (%smt-bool-var-for-bit name i))))))
           (:bvnot
            (mapcar #'smt-not (bb (second current))))
           (:bvand
            (mapcar #'smt-and (bb (second current)) (bb (third current))))
           (:bvor
            (mapcar #'smt-or (bb (second current)) (bb (third current))))
           (:bvxor
            (mapcar #'smt-xor (bb (second current)) (bb (third current))))
           (:bvadd
            (let* ((lhs (bb (second current)))
                   (rhs (bb (third current)))
                   (carry (smt-bool-const nil))
                   (result '()))
              (dotimes (i (length lhs) (nreverse result))
                (let* ((a (nth i lhs))
                       (b (nth i rhs))
                       (sum (smt-xor a (smt-xor b carry)))
                       (next-carry (smt-or (smt-and a b)
                                           (smt-or (smt-and a carry)
                                                   (smt-and b carry)))))
                  (push sum result)
                  (setf carry next-carry)))))
           (:bvsub
            (bb (smt-bvadd (second current)
                           (smt-bvadd (smt-bvnot (third current))
                                      (smt-bv-lit (length (bb (third current))) 1))))
           )
           (:concat
            (append (bb (third current)) (bb (second current))))
           (:extract
            (destructuring-bind (_ hi lo inner) current
              (declare (ignore _))
              (subseq (bb inner) lo (1+ hi))))
           (:ite
            (unless bool-bitblaster
              (kernel-error "bit-blast expected Boolean bitblaster for BV ite term: ~S"
                            current))
            (let ((condition (funcall bool-bitblaster (second current)))
                  (then-bits (bb (third current)))
                  (else-bits (bb (fourth current))))
              (mapcar (lambda (then-bit else-bit)
                        (smt-ite condition then-bit else-bit))
                      then-bits
                      else-bits)))
           (otherwise
            (kernel-error "bit-blast does not support BV term: ~S" current)))))
    (bb term)))

(defun %bitblast-bv-eq (lhs rhs env &optional bool-bitblaster)
  (let ((lhs-bits (%bitblast-bv-term lhs env bool-bitblaster))
        (rhs-bits (%bitblast-bv-term rhs env bool-bitblaster)))
    (apply #'smt-and
           (mapcar (lambda (a b) (smt-eq a b)) lhs-bits rhs-bits))))

(defun %bitblast-bv-ult (lhs rhs env &optional bool-bitblaster)
  (let ((lhs-bits (%bitblast-bv-term lhs env bool-bitblaster))
        (rhs-bits (%bitblast-bv-term rhs env bool-bitblaster)))
    (labels
        ((ult-rec (xs ys)
           (if (endp xs)
               (smt-bool-const nil)
               (let* ((a (car (last xs)))
                      (b (car (last ys)))
                      (rest-x (butlast xs))
                      (rest-y (butlast ys))
                      (lower (ult-rec rest-x rest-y)))
                 (smt-or (smt-and (smt-not a) b)
                         (smt-and (smt-eq a b) lower))))))
      (ult-rec lhs-bits rhs-bits))))

(defun %bitblastable-bv-term-p (term)
  (case (smt-tag term)
    (:bv-lit t)
    (:var (equal (smt-sort-kind (third term)) :BV))
    ((:bvnot) (%bitblastable-bv-term-p (second term)))
    ((:bvand :bvor :bvxor :bvadd :bvsub :concat)
     (and (%bitblastable-bv-term-p (second term))
          (%bitblastable-bv-term-p (third term))))
    (:ite
     (and (%bitblastable-bv-term-p (third term))
          (%bitblastable-bv-term-p (fourth term))))
    (:extract (%bitblastable-bv-term-p (fourth term)))
    (otherwise nil)))

(defun bitblast-smt-term (term &optional (env (make-hash-table :test #'equal)))
  (labels
      ((bb (current)
         (case (smt-tag current)
           (:bool current)
           (:var current)
           (:not (smt-not (bb (second current))))
           (:and (apply #'smt-and (mapcar #'bb (rest current))))
           (:or (apply #'smt-or (mapcar #'bb (rest current))))
           (:xor (smt-xor (bb (second current)) (bb (third current))))
           (:=> (smt-implies (bb (second current)) (bb (third current))))
           (:ite (smt-ite (bb (second current))
                          (bb (third current))
                          (bb (fourth current))))
           (:= (let ((lhs (second current))
                     (rhs (third current)))
                 (cond
                   ((and (%bitblastable-bv-term-p lhs) (%bitblastable-bv-term-p rhs))
                    (%bitblast-bv-eq lhs rhs env #'bb))
                   (t (smt-eq (bb lhs) (bb rhs))))))
           (:ult (%bitblast-bv-ult (second current) (third current) env #'bb))
           (otherwise
            (kernel-error "bit-blast does not support SMT term: ~S" current)))))
    (normalize-smt-term (bb term))))
