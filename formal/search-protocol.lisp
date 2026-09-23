(in-package :mini-kernel)

(defstruct (successor-state
            (:constructor make-successor-state
                (&key next label metadata)))
  next
  label
  metadata)

(defstruct (search-branch
            (:constructor make-search-branch
                (&key state history)))
  state
  history)

(defgeneric one-step-successors (domain state &key &allow-other-keys))

(defgeneric state-key (domain state))

(defgeneric branch-closes-p (domain initial current))

(defmethod state-key ((domain t) state)
  (declare (ignore domain))
  (artifact-digest state))

(defmethod branch-closes-p ((domain t) initial current)
  (declare (ignore domain))
  (equal initial current))

(defun term-one-step-successors (env term)
  (loop for next in (d-step-results env term)
        for index from 0
        collect
        (make-successor-state
         :next next
         :label (list :term-reduction-step index)
         :metadata (list :domain :term-reduction
                         :env-digest (artifact-digest env)))))

(defun runtime-one-step-successors (program runtime)
  (multiple-value-bind (next-runtime fragment)
      (stage1-step-runtime program runtime)
    (if fragment
        (let* ((compiler (stage1-fragment-compiler fragment))
               (control (stage1-fragment-control fragment)))
          (list
           (make-successor-state
            :next next-runtime
            :label (list :stage1-step
                         :compiler (stage1-compiler-instance-name compiler)
                         :next-compiler (stage1-control-next-compiler control)
                         :next-form (stage1-control-next-form control))
            :metadata (list :domain :stage1-runtime
                            :fragment fragment
                            :lineage (stage1-fragment-lineage fragment)))))
        '())))

(defmethod one-step-successors ((domain (eql :term-reduction)) state
                                &key env &allow-other-keys)
  (unless env
    (kernel-error "term reduction successor enumeration requires :env"))
  (term-one-step-successors env state))

(defmethod one-step-successors ((domain (eql :stage1-runtime)) state
                                &key program &allow-other-keys)
  (unless program
    (kernel-error "stage1 runtime successor enumeration requires :program"))
  (runtime-one-step-successors program state))

(defun %frontier-seen-table (seen)
  (cond
    ((hash-table-p seen) seen)
    ((null seen) (make-hash-table :test #'equal))
    ((listp seen)
     (let ((table (make-hash-table :test #'equal)))
       (dolist (key seen table)
         (setf (gethash key table) t))))
    (t
     (kernel-error "unsupported seen set carrier: ~S" seen))))

(defun %frontier-branch (item)
  (if (typep item 'search-branch)
      item
      (make-search-branch :state item :history '())))

(defun %successor-key (key-fn domain state)
  (if (or (null key-fn)
          (eq key-fn #'state-key)
          (and (symbolp key-fn) (eq key-fn 'state-key)))
      (state-key domain state)
      (funcall key-fn state)))

(defun expand-frontier-once (domain frontier &rest args
                              &key seen key-fn
                              &allow-other-keys)
  (let* ((pass-through
           (loop for (key value) on args by #'cddr
                 unless (member key '(:seen :key-fn))
                 append (list key value)))
         (seen-table (%frontier-seen-table seen))
         (next-frontier '())
         (edges '()))
    (dolist (item frontier)
      (let* ((branch (%frontier-branch item))
             (current (search-branch-state branch))
             (successors (apply #'one-step-successors domain current pass-through)))
        (dolist (successor successors)
          (let* ((next (successor-state-next successor))
                 (key (%successor-key key-fn domain next)))
            (unless (gethash key seen-table)
              (setf (gethash key seen-table) t)
              (let ((next-branch
                      (make-search-branch
                       :state next
                       :history (append (search-branch-history branch)
                                        (list successor)))))
                (push next-branch next-frontier)
                (push (list :from current
                            :successor successor
                            :branch next-branch)
                      edges)))))))
    (values (nreverse next-frontier)
            (nreverse edges)
            seen-table)))
