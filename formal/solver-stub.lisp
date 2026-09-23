(in-package :mini-kernel)

(defun %emit-smt-normalization-bundle (store query normalized status)
  (let* ((bundle (make-smt-obligation-bundle
                  :input query
                  :normalized-term normalized
                  :status status
                  :evidence-kind :normalized-form
                  :trace-ref '(:normalization-pass normalize-smt-term)))
         (artifact-kind (if (eq status :rejected) :unsat-core :summary)))
    (values bundle
            (emit-advisory-artifact
             store
             'smt-check
             artifact-kind
             bundle
             '(:solver normalize-only)))))

(defun %boolean-fragment-term-p (term)
  (case (smt-tag term)
    ((:bool :var) t)
    (:not (%boolean-fragment-term-p (second term)))
    ((:and :or)
     (every #'%boolean-fragment-term-p (rest term)))
    ((:xor :=> :=)
     (and (%boolean-fragment-term-p (second term))
          (%boolean-fragment-term-p (third term))))
    (:ite
     (and (%boolean-fragment-term-p (second term))
          (%boolean-fragment-term-p (third term))
          (%boolean-fragment-term-p (fourth term))))
    (otherwise nil)))

(defun %int-fragment-term-p (term)
  (case (smt-tag term)
    ((:bool :int-lit :bv-lit) t)
    (:var t)
    (:not (%int-fragment-term-p (second term)))
    ((:and :or :xor :=>)
     (every #'%int-fragment-term-p (rest term)))
    (:ite
     (and (%int-fragment-term-p (second term))
          (%int-fragment-term-p (third term))
          (%int-fragment-term-p (fourth term))))
    (:= (and (%int-fragment-term-p (second term))
             (%int-fragment-term-p (third term))))
    ((:int-add)
     (every #'%int-fragment-term-p (rest term)))
    ((:int-sub :int-mod :int-lt :int-le :int-gt :int-ge)
     (and (%int-fragment-term-p (second term))
          (%int-fragment-term-p (third term))))
    (otherwise nil)))

(defun %smt-occurs-in-term-p (name term)
  (cond
    ((atom term) nil)
    ((and (eq (smt-tag term) :var)
          (eql (second term) name))
     t)
    (t
     (some (lambda (subterm)
             (%smt-occurs-in-term-p name subterm))
           (rest term)))))

(defun %smt-substitute-var (name replacement term)
  (cond
    ((atom term) term)
    ((and (eq (smt-tag term) :var)
          (eql (second term) name))
     replacement)
    (t
     (cons (first term)
           (mapcar (lambda (subterm)
                     (%smt-substitute-var name replacement subterm))
                   (rest term))))))

(defun %extract-smt-substitution (term)
  (when (eq (smt-tag term) :=)
    (let ((lhs (second term))
          (rhs (third term)))
      (cond
        ((and (eq (smt-tag lhs) :var)
              (not (equal lhs rhs))
              (not (%smt-occurs-in-term-p (second lhs) rhs)))
         (values (second lhs) rhs))
        ((and (eq (smt-tag rhs) :var)
              (not (equal lhs rhs))
              (not (%smt-occurs-in-term-p (second rhs) lhs)))
         (values (second rhs) lhs))
        (t
         (values nil nil))))))

(defun %collapse-smt-conjunction (terms)
  (cond
    ((null terms) (smt-bool-const t))
    ((null (rest terms)) (first terms))
    (t (apply #'smt-and terms))))

(defun %int-affine-add-coeff (coeffs name delta)
  (let ((cell (assoc name coeffs)))
    (cond
      (cell
       (let ((new (+ (cdr cell) delta)))
         (if (zerop new)
             (remove name coeffs :key #'car :test #'eql)
             (acons name new (remove name coeffs :key #'car :test #'eql)))))
      ((zerop delta) coeffs)
      (t
       (acons name delta coeffs)))))

(defun %int-affine-merge (lhs rhs scale)
  (reduce (lambda (acc entry)
            (%int-affine-add-coeff acc (car entry) (* scale (cdr entry))))
          rhs
          :initial-value lhs))

(defun %int-affine-expr (term)
  (case (smt-tag term)
    (:int-lit
     (values '() (second term) t))
    (:var
     (values (list (cons (second term) 1)) 0 t))
    (:int-add
     (loop with coeffs = '()
           with constant = 0
           for arg in (rest term)
           do (multiple-value-bind (arg-coeffs arg-const okp)
                  (%int-affine-expr arg)
                (unless okp
                  (return (values nil nil nil)))
                (setf coeffs (%int-affine-merge coeffs arg-coeffs 1)
                      constant (+ constant arg-const)))
           finally (return (values coeffs constant t))))
    (:int-sub
     (multiple-value-bind (lhs-coeffs lhs-const lhs-okp)
         (%int-affine-expr (second term))
       (multiple-value-bind (rhs-coeffs rhs-const rhs-okp)
           (%int-affine-expr (third term))
         (if (and lhs-okp rhs-okp)
             (values (%int-affine-merge lhs-coeffs rhs-coeffs -1)
                     (- lhs-const rhs-const)
                     t)
             (values nil nil nil)))))
    (otherwise
     (values nil nil nil))))

(defun %int-affine-single-var-bound (coeffs constant relation)
  (when (= (length coeffs) 1)
    (let* ((entry (first coeffs))
           (name (car entry))
           (coeff (cdr entry)))
      (cond
        ((= coeff 1)
         (case relation
           (:= (list name :eq (- constant)))
           (:int-le (list name :ub (- constant)))
           (:int-lt (list name :ub (1- (- constant))))
           (:int-ge (list name :lb (- constant)))
           (:int-gt (list name :lb (1+ (- constant))))
           (otherwise nil)))
        ((= coeff -1)
         (case relation
           (:= (list name :eq constant))
           (:int-le (list name :lb constant))
           (:int-lt (list name :lb (1+ constant)))
           (:int-ge (list name :ub constant))
           (:int-gt (list name :ub (1- constant)))
           (otherwise nil)))
        (t nil)))))

(defun %int-constraint-from-literal (term)
  (case (smt-tag term)
    (:bool
     (if (second term)
         (values :trivial nil)
         (values :conflict nil)))
    ((:= :int-le :int-lt :int-ge :int-gt)
     (multiple-value-bind (lhs-coeffs lhs-const lhs-okp)
         (%int-affine-expr (second term))
       (multiple-value-bind (rhs-coeffs rhs-const rhs-okp)
           (%int-affine-expr (third term))
         (if (and lhs-okp rhs-okp)
             (let ((coeffs (%int-affine-merge lhs-coeffs rhs-coeffs -1))
                   (constant (- lhs-const rhs-const)))
               (cond
                 ((null coeffs)
                  (case (smt-tag term)
                    (:= (values (if (zerop constant) :trivial :conflict) nil))
                    (:int-le (values (if (<= constant 0) :trivial :conflict) nil))
                    (:int-lt (values (if (< constant 0) :trivial :conflict) nil))
                    (:int-ge (values (if (>= constant 0) :trivial :conflict) nil))
                    (:int-gt (values (if (> constant 0) :trivial :conflict) nil))
                    (otherwise (values :unsupported nil))))
                 (t
                  (let ((bound (%int-affine-single-var-bound coeffs constant (smt-tag term))))
                    (if bound
                        (values :bound bound)
                        (values :unsupported nil))))))
             (values :unsupported nil)))))
    (otherwise
     (values :unsupported nil))))

(defun %int-apply-bound (table bound)
  (destructuring-bind (name kind value) bound
    (let ((cell (or (gethash name table)
                    (setf (gethash name table) (list :lb nil :ub nil :eq nil)))))
      (ecase kind
        (:eq
         (setf (getf cell :eq) value))
        (:lb
         (setf (getf cell :lb)
               (if (null (getf cell :lb)) value (max value (getf cell :lb)))))
        (:ub
         (setf (getf cell :ub)
               (if (null (getf cell :ub)) value (min value (getf cell :ub))))))
      (let ((eqv (getf cell :eq)))
        (when eqv
          (setf (getf cell :lb)
                (if (null (getf cell :lb)) eqv (max eqv (getf cell :lb)))
                (getf cell :ub)
                (if (null (getf cell :ub)) eqv (min eqv (getf cell :ub))))))
      (setf (gethash name table) cell)
      (let ((lb (getf cell :lb))
            (ub (getf cell :ub)))
        (and lb ub (> lb ub))))))

(defun %solve-int-conjunction (formula)
  (let ((terms (if (eq (smt-tag formula) :and)
                   (rest formula)
                   (list formula)))
        (bounds (make-hash-table :test #'eql))
        (unsupported nil))
    (dolist (term terms)
      (multiple-value-bind (kind payload)
          (%int-constraint-from-literal term)
        (case kind
          (:conflict
           (return-from %solve-int-conjunction :rejected))
          (:bound
           (when (%int-apply-bound bounds payload)
             (return-from %solve-int-conjunction :rejected)))
          (:unsupported
           (setf unsupported t))
          (otherwise nil))))
    (if unsupported :unknown :accepted)))

(defun %normalize-int-conjunction (formula)
  (labels ((normalize-list (terms)
             (let ((normalized (mapcar #'normalize-smt-term terms)))
               (when (some #'smt-bool-false-p normalized)
                 (return-from %normalize-int-conjunction (smt-bool-const nil)))
               (remove-if #'smt-bool-true-p normalized))))
    (let ((terms (if (eq (smt-tag formula) :and)
                     (rest formula)
                     (list formula))))
      (loop
        with current = (normalize-list terms)
        do (multiple-value-bind (name replacement)
               (loop for term in current
                     do (multiple-value-bind (candidate-name candidate-replacement)
                            (%extract-smt-substitution term)
                          (when candidate-name
                            (return (values candidate-name candidate-replacement))))
                     finally (return (values nil nil)))
             (if (null name)
                 (return (%collapse-smt-conjunction current))
                 (setf current
                       (normalize-list
                        (mapcar (lambda (term)
                                  (%smt-substitute-var name replacement term))
                                current)))))))))

(defun %emit-smt-cnf-bundle (store query normalized cnf status)
  (declare (ignore store))
  (let* ((core (and (eq status :rejected) (smt-cnf-unsat-core cnf)))
         (assumption-ids (mapcar #'first (smt-cnf-assumptions cnf)))
         (obligation-bundle (make-smt-obligation-bundle
                             :input query
                             :normalized-term normalized
                             :assumption-ids assumption-ids
                             :unsat-core core
                             :status status
                             :evidence-kind :cnf-form
                             :trace-ref (list :cnf-var-count (smt-cnf-var-count cnf)
                                              :cnf-clause-count (length (smt-cnf-clauses cnf)))))
         (cnf-bundle (make-smt-cnf-bundle
                      :input query
                      :normalized-term normalized
                      :cnf cnf
                      :assumption-ids assumption-ids
                      :unsat-core core
                      :status status
                      :trace-ref '(:cnf-pass compile-smt-to-cnf :sat-pass solve-cnf-dpll)))
         (artifact-kind (if (eq status :rejected) :unsat-core :summary)))
    (values obligation-bundle cnf-bundle artifact-kind)))

(defun %cnf-model-payload (cnf assignment)
  (let ((table (smt-cnf-atom-table cnf))
        (entries '()))
    (cond
      ((hash-table-p table)
       (maphash
        (lambda (atom literal)
          (let ((value (aref assignment (1- (abs literal)))))
            (unless (eq value :unassigned)
              (push (cons atom value) entries))))
        table))
      ((listp table)
       (dolist (binding table)
         (destructuring-bind (atom literal) binding
           (let ((value (aref assignment (1- (abs literal)))))
             (unless (eq value :unassigned)
               (push (cons atom value) entries))))))
      (t
       (return-from %cnf-model-payload
         (list :assignment (coerce assignment 'list)))))
    (sort entries #'string<
          :key (lambda (entry)
                 (prin1-to-string (car entry))))))

(defun %query-assumptions (query)
  (if (and (consp query) (eq (first query) :assuming))
      (values (second query) (third query))
      (values '() query)))

(defun normalize-smt-term-defir
    (term &key (program (make-smt-core-defir-program
                         :metadata (list :lane :smt
                                         :fragment :normalize-core
                                         :execution-lane :defir))))
  (call-defir-function program 'normalize-smt-term term))

(defun lower-smt-to-boolean-core-defir
    (term &key (program (make-smt-core-defir-program
                         :metadata (list :lane :smt
                                         :fragment :boolean-core-lowering
                                         :execution-lane :defir))))
  (call-defir-function program 'lower-smt-to-boolean-core term))

(defun compile-boolean-core-to-cnf-defir
    (term &key (program (make-smt-core-defir-program
                         :metadata (list :lane :smt
                                         :fragment :cnf-lowering
                                         :execution-lane :defir))))
  (call-defir-function program 'compile-boolean-core-to-cnf term))

(defun compile-boolean-core-to-cnf-with-assumptions-defir
    (assumptions term
     &key (program (make-smt-core-defir-program
                    :metadata (list :lane :smt
                                    :fragment :cnf-lowering-assumptions
                                    :execution-lane :defir))))
  (call-defir-function program 'compile-boolean-core-to-cnf-with-assumptions assumptions term))

(defun bitblast-smt-term-defir
    (term &key (program (make-smt-core-defir-program
                         :metadata (list :lane :smt
                                         :fragment :bitblast
                                         :execution-lane :defir))))
  (call-defir-function program 'bitblast-smt-term term))

(defun compile-smt-to-cnf-defir
    (term &key (program (make-smt-core-defir-program
                         :metadata (list :lane :smt
                                         :fragment :smt-cnf-lowering
                                         :execution-lane :defir))))
  (call-defir-function program 'compile-smt-to-cnf term))

(defun compile-smt-to-cnf-with-assumptions-defir
    (assumptions term
     &key (program (make-smt-core-defir-program
                    :metadata (list :lane :smt
                                    :fragment :smt-cnf-lowering-assumptions
                                    :execution-lane :defir))))
  (call-defir-function program 'compile-smt-to-cnf-with-assumptions assumptions term))

(defun solve-cnf-dpll-defir
    (cnf &key (program (make-smt-core-defir-program
                        :metadata (list :lane :smt
                                        :fragment :sat-core
                                        :execution-lane :defir))))
  (call-defir-function program 'solve-cnf-dpll cnf))

(defun solve-cnf-under-assumptions-dpll-defir
    (cnf assumptions
     &key (program (make-smt-core-defir-program
                    :metadata (list :lane :smt
                                    :fragment :sat-core-assumptions
                                    :execution-lane :defir))))
  (call-defir-function program 'solve-cnf-under-assumptions-dpll cnf assumptions))

(defun make-smt-family-ingested-algorithm
    (&key
       (defir-program (make-smt-core-defir-program
                       :metadata (list :lane :smt
                                       :fragment :normalize-and-lower
                                       :execution-lane :defir)))
       (config (list :fragment :qf-bv-bool-core
                     :config-digest *current-config-digest*))
       (status :accepted))
  (validate-ingested-algorithm
   (make-ingested-algorithm
    :name :smt-core-runtime
    :lane :smt
    :input-schema '(:formula :assumptions)
    :output-schema '(:checker-status :normalized-term :cnf :model :unsat-core)
    :semantic-contract
    '(:closure-target :runtime-semantics
      :note "SMT normalization, Boolean-core lowering, Boolean/BV CNF lowering, bit-blast, and the bounded CNF SAT entrypoints are lowered into DefIR on the frozen Bool/BV core fragment.")
    :reference-judgment '(:j-smt :smt-bridge-boolean-unsat :smt-bridge-bitvector-unsat
                          :smt-bridge-int-unsat :smt-bridge-affine-int-contradiction)
    :defir-program defir-program
    :config config
    :agreement-theorem-kind :bridge
    :status status
    :metadata (list :normalizer 'normalize-smt-term
                    :defir-normalizer 'normalize-smt-term-defir
                    :boolean-lowerer 'lower-smt-to-boolean-core
                    :defir-lowerer 'lower-smt-to-boolean-core-defir
                    :cnf-compiler 'compile-boolean-core-to-cnf
                    :defir-cnf-compiler 'compile-boolean-core-to-cnf-defir
                    :defir-cnf-compiler-assumptions
                    'compile-boolean-core-to-cnf-with-assumptions-defir
                    :defir-bitblast 'bitblast-smt-term-defir
                    :defir-smt-cnf 'compile-smt-to-cnf-defir
                    :defir-smt-cnf-assumptions
                    'compile-smt-to-cnf-with-assumptions-defir
                    :defir-sat-core 'solve-cnf-dpll-defir
                    :defir-sat-core-assumptions 'solve-cnf-under-assumptions-dpll-defir
                    :operations '(normalize-smt-term
                                  lower-smt-to-boolean-core
                                  compile-boolean-core-to-cnf
                                  compile-boolean-core-to-cnf-with-assumptions
                                  bitblast-smt-term
                                  compile-smt-to-cnf
                                  compile-smt-to-cnf-with-assumptions
                                  solve-cnf-dpll
                                  solve-cnf-under-assumptions-dpll)
                    :cnf-lowerer 'compile-smt-to-cnf
                    :sat-core 'solve-cnf-dpll
                    :sat-core-assumptions 'solve-cnf-under-assumptions-dpll
                    :bitblast 'bitblast-smt-term
                    :query-entry 'run-smt-check
                    :ingestion-status :partial-defir
                    :ingested-fragments '(:normalize-core :boolean-core-lowering
                                          :cnf-lowering
                                          :cnf-lowering-assumptions
                                          :bitblast
                                          :smt-cnf-lowering
                                          :smt-cnf-lowering-assumptions
                                          :sat-core
                                          :sat-core-assumptions)))))

(defun run-smt-check (store query)
  (let ((backend (find-backend 'smt-check)))
    (unless backend
      (kernel-error "smt-check backend is not registered"))
    (unless (eq (backend-trust-class backend) :advisory)
      (kernel-error "smt-check backend lost advisory status"))
    (multiple-value-bind (assumptions formula)
        (%query-assumptions query)
      (cond
      ((and (consp formula)
            (member (first formula)
                    '(:bool :var :not :and :or :xor :=> :ite := :bv-lit :int-lit
                      :int-add :int-sub :int-mod :int-lt :int-le :int-gt :int-ge
                      :bvnot :bvand :bvor :bvxor :bvadd :bvsub :concat
                      :extract :ult)
                    :test #'eq))
       (let* ((normalized0 (if (%int-fragment-term-p formula)
                               (normalize-smt-term formula)
                               (normalize-smt-term-defir formula)))
              (normalized (if (%int-fragment-term-p normalized0)
                              (%normalize-int-conjunction normalized0)
                              normalized0)))
         (cond
           ((and (null assumptions) (smt-bool-true-p normalized))
            (multiple-value-bind (bundle artifact)
                (%emit-smt-normalization-bundle store query normalized :accepted)
              (make-backend-result
               :backend-id 'smt-check
               :status :accepted
               :evidence '(:normalized-form)
               :artifacts (list bundle artifact))))
           ((and (null assumptions) (smt-bool-false-p normalized))
            (multiple-value-bind (bundle artifact)
                (%emit-smt-normalization-bundle store query normalized :rejected)
              (make-backend-result
               :backend-id 'smt-check
               :status :rejected
               :evidence '(:normalized-form)
               :artifacts (list bundle artifact))))
           ((%boolean-fragment-term-p normalized)
            (let* ((boolean-core (lower-smt-to-boolean-core-defir normalized))
                   (core-assumptions
                     (mapcar (lambda (entry)
                               (destructuring-bind (assumption-id assumption-term) entry
                                 (list assumption-id
                                       (lower-smt-to-boolean-core-defir assumption-term))))
                             assumptions))
                   (cnf (if assumptions
                            (compile-boolean-core-to-cnf-with-assumptions-defir
                             core-assumptions boolean-core)
                            (compile-boolean-core-to-cnf-defir boolean-core)))
                   (assignment (if assumptions
                                   (solve-cnf-under-assumptions-dpll-defir
                                    cnf
                                    (mapcar #'second (smt-cnf-assumptions cnf)))
                                   (solve-cnf-dpll-defir cnf))))
              (if assignment
                  (multiple-value-bind (bundle cnf-bundle artifact-kind)
                      (%emit-smt-cnf-bundle store query boolean-core cnf :accepted)
                    (make-backend-result
                     :backend-id 'smt-check
                     :status :accepted
                     :evidence '(:cnf-form)
                     :artifacts
                     (remove nil
                             (list bundle
                                   cnf-bundle
                                   (emit-advisory-artifact
                                    store
                                    'smt-check
                                    artifact-kind
                                    cnf-bundle
                                    '(:solver dpll-core))
                                   (emit-advisory-artifact
                                    store
                                    'smt-check
                                    :model
                                    (%cnf-model-payload cnf assignment)
                                    '(:solver dpll-core :source :cnf-sat))))))
                  (multiple-value-bind (bundle cnf-bundle artifact-kind)
                      (%emit-smt-cnf-bundle store query boolean-core cnf :rejected)
                    (make-backend-result
                     :backend-id 'smt-check
                     :status :rejected
                     :evidence '(:cnf-form)
                     :artifacts
                     (list bundle
                           cnf-bundle
                           (emit-advisory-artifact
                            store
                            'smt-check
                            artifact-kind
                            cnf-bundle
                            '(:solver dpll-core))))))))
           ((or (smt-bool-true-p normalized) (smt-bool-false-p normalized))
            (multiple-value-bind (bundle artifact)
                (%emit-smt-normalization-bundle
                 store query normalized (if (smt-bool-true-p normalized) :accepted :rejected))
              (make-backend-result
               :backend-id 'smt-check
               :status (if (smt-bool-true-p normalized) :accepted :rejected)
               :evidence (if (smt-bool-true-p normalized)
                             '(:normalized-form :int-fragment :normalized-true)
                             '(:normalized-form :int-fragment :normalized-false))
               :artifacts (list bundle artifact))))
           ((%int-fragment-term-p normalized)
            (case (%solve-int-conjunction normalized)
              (:accepted
               (multiple-value-bind (bundle artifact)
                   (%emit-smt-normalization-bundle store query normalized :accepted)
                 (make-backend-result
                  :backend-id 'smt-check
                  :status :accepted
                  :evidence '(:normalized-form :int-fragment :normalized-true)
                  :artifacts (list bundle artifact))))
              (:rejected
               (multiple-value-bind (bundle artifact)
                   (%emit-smt-normalization-bundle store query normalized :rejected)
                 (make-backend-result
                  :backend-id 'smt-check
                  :status :rejected
                  :evidence '(:normalized-form :int-fragment :normalized-false)
                  :artifacts (list bundle artifact))))
              (otherwise
               (multiple-value-bind (bundle artifact)
                   (%emit-smt-normalization-bundle store query normalized :unknown)
                 (make-backend-result
                  :backend-id 'smt-check
                  :status :unknown
                  :evidence '(:normalized-form :int-fragment :unknown)
                  :artifacts (list bundle artifact))))))
           (t
           (let* ((bitblasted (bitblast-smt-term-defir normalized))
                   (cnf (if assumptions
                            (compile-smt-to-cnf-with-assumptions-defir assumptions bitblasted)
                            (compile-smt-to-cnf-defir bitblasted)))
                   (assignment (if assumptions
                                   (solve-cnf-under-assumptions-dpll-defir
                                    cnf
                                    (mapcar #'second (smt-cnf-assumptions cnf)))
                                   (solve-cnf-dpll-defir cnf))))
              (if assignment
                  (multiple-value-bind (bundle cnf-bundle artifact-kind)
                      (%emit-smt-cnf-bundle store query bitblasted cnf :accepted)
                    (make-backend-result
                     :backend-id 'smt-check
                     :status :accepted
                     :evidence '(:cnf-form :bitblast)
                     :artifacts
                     (remove nil
                             (list bundle
                                   cnf-bundle
                                   (emit-advisory-artifact
                                    store
                                    'smt-check
                                    artifact-kind
                                    cnf-bundle
                                    '(:solver dpll-core))
                                   (emit-advisory-artifact
                                    store
                                    'smt-check
                                    :model
                                    (%cnf-model-payload cnf assignment)
                                    '(:solver dpll-core :source :cnf-sat))))))
                  (multiple-value-bind (bundle cnf-bundle artifact-kind)
                      (%emit-smt-cnf-bundle store query bitblasted cnf :rejected)
                    (make-backend-result
                     :backend-id 'smt-check
                     :status :rejected
                     :evidence '(:cnf-form :bitblast)
                     :artifacts
                     (list bundle
                           cnf-bundle
                           (emit-advisory-artifact
                            store
                            'smt-check
                            artifact-kind
                            cnf-bundle
                            '(:solver dpll-core)))))))))))
      ((and (consp formula) (eq (first formula) :sat))
       (let ((artifact (emit-advisory-artifact
                        store
                        'smt-check
                        :model
                        (second formula)
                        '(:solver stub))))
         (make-backend-result
          :backend-id 'smt-check
          :status :accepted
          :evidence '(:model)
          :artifacts (list artifact))))
      ((and (consp formula) (eq (first formula) :unsat-core))
       (let ((artifact (emit-advisory-artifact
                        store
                        'smt-check
                        :unsat-core
                        (second formula)
                        '(:solver stub))))
         (make-backend-result
          :backend-id 'smt-check
          :status :rejected
          :evidence '(:unsat-core)
          :artifacts (list artifact))))
      ((eq formula :unknown)
       (make-backend-result
        :backend-id 'smt-check
        :status :unknown
        :evidence '(:unknown)
        :artifacts '()))
      (t
       (kernel-error "unsupported SMT stub query: ~S" query))))))
