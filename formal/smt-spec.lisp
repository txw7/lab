(in-package :mini-kernel)

(defstruct smt-obligation
  id
  label
  (logic :qf_lia)
  (vars '())
  (assumptions '())
  goal
  (polarity :expect-status)
  expected-status
  (unknown-policy :forbidden)
  (semantic-tags '())
  source-ref
  metadata)

(defstruct smt-spec
  id
  (logic :qf_lia)
  obligations
  source-path
  (semantic-tags '())
  metadata)

(defun %smt-sort->smtlib (sort)
  (ecase (smt-sort-kind sort)
    (:Bool "Bool")
    (:Int "Int")
    (:BV (format nil "(_ BitVec ~D)" (second sort)))))

(defun %smt-atom->smtlib (atom)
  (typecase atom
    (symbol (string-downcase (symbol-name atom)))
    (string atom)
    (integer (princ-to-string atom))
    (t (kernel-error "unsupported SMT atom for SMT-LIB emission: ~S" atom))))

(defun %smt-bv-lit->smtlib (width value)
  (let ((digits (ceiling width 4)))
    (format nil "#x~v,'0X" digits value)))

(defun %zero-extend-concat-amount (term)
  (when (and (eq (smt-tag term) :concat)
             (eq (smt-tag (second term)) :bv-lit)
             (zerop (smt-bv-value (second term))))
    (smt-bv-width (second term))))

(defun %low-zero-concat-amount (term)
  (when (and (eq (smt-tag term) :concat)
             (eq (smt-tag (third term)) :bv-lit)
             (zerop (smt-bv-value (third term))))
    (smt-bv-width (third term))))

(defun %smt-term->smtlib (term)
  (labels ((emit-nary (name args)
             (format nil "(~A~{ ~A~})" name (mapcar #'%smt-term->smtlib args))))
    (case (smt-tag term)
      (:bool (if (second term) "true" "false"))
      (:var (%smt-atom->smtlib (second term)))
      (:bv-lit (%smt-bv-lit->smtlib (second term) (third term)))
      (:int-lit (princ-to-string (second term)))
      (:not (format nil "(not ~A)" (%smt-term->smtlib (second term))))
      (:and (emit-nary "and" (rest term)))
      (:or (emit-nary "or" (rest term)))
      (:xor (emit-nary "xor" (rest term)))
      (:=> (format nil "(=> ~A ~A)"
                   (%smt-term->smtlib (second term))
                   (%smt-term->smtlib (third term))))
      (:ite (format nil "(ite ~A ~A ~A)"
                    (%smt-term->smtlib (second term))
                    (%smt-term->smtlib (third term))
                    (%smt-term->smtlib (fourth term))))
      (:= (format nil "(= ~A ~A)"
                  (%smt-term->smtlib (second term))
                  (%smt-term->smtlib (third term))))
      (:int-add (emit-nary "+" (rest term)))
      (:int-sub (format nil "(- ~A ~A)"
                        (%smt-term->smtlib (second term))
                        (%smt-term->smtlib (third term))))
      (:int-mod (format nil "(mod ~A ~A)"
                        (%smt-term->smtlib (second term))
                        (%smt-term->smtlib (third term))))
      (:int-lt (format nil "(< ~A ~A)"
                       (%smt-term->smtlib (second term))
                       (%smt-term->smtlib (third term))))
      (:int-le (format nil "(<= ~A ~A)"
                       (%smt-term->smtlib (second term))
                       (%smt-term->smtlib (third term))))
      (:int-gt (format nil "(> ~A ~A)"
                       (%smt-term->smtlib (second term))
                       (%smt-term->smtlib (third term))))
      (:int-ge (format nil "(>= ~A ~A)"
                       (%smt-term->smtlib (second term))
                       (%smt-term->smtlib (third term))))
      (:bvnot (format nil "(bvnot ~A)" (%smt-term->smtlib (second term))))
      (:bvand (format nil "(bvand ~A ~A)"
                      (%smt-term->smtlib (second term))
                      (%smt-term->smtlib (third term))))
      (:bvor (format nil "(bvor ~A ~A)"
                     (%smt-term->smtlib (second term))
                     (%smt-term->smtlib (third term))))
      (:bvxor (format nil "(bvxor ~A ~A)"
                      (%smt-term->smtlib (second term))
                      (%smt-term->smtlib (third term))))
      (:bvadd (format nil "(bvadd ~A ~A)"
                      (%smt-term->smtlib (second term))
                      (%smt-term->smtlib (third term))))
      (:bvsub (format nil "(bvsub ~A ~A)"
                      (%smt-term->smtlib (second term))
                      (%smt-term->smtlib (third term))))
      (:concat
       (let ((zero-extend-amount (%zero-extend-concat-amount term))
             (low-zero-amount (%low-zero-concat-amount term)))
         (cond
           (zero-extend-amount
            (format nil "((_ zero_extend ~D) ~A)"
                    zero-extend-amount
                    (%smt-term->smtlib (third term))))
           (low-zero-amount
            (format nil "(bvshl ((_ zero_extend ~D) ~A) ~D)"
                    low-zero-amount
                    (%smt-term->smtlib (second term))
                    low-zero-amount))
           (t
            (format nil "(concat ~A ~A)"
                    (%smt-term->smtlib (second term))
                    (%smt-term->smtlib (third term)))))))
      (:extract (format nil "((_ extract ~D ~D) ~A)"
                        (second term)
                        (third term)
                        (%smt-term->smtlib (fourth term))))
      (:ult (format nil "(bvule ~A ~A)"
                    (%smt-term->smtlib (second term))
                    (%smt-term->smtlib (third term))))
      (otherwise
       (kernel-error "unsupported SMT term for SMT-LIB emission: ~S" term)))))

(defun %collect-smt-vars (term &optional (seen (make-hash-table :test #'equal)))
  (labels ((walk (current)
             (when (consp current)
               (if (eq (first current) :var)
                   (setf (gethash (list (second current) (third current)) seen) t)
                   (dolist (item (rest current))
                     (walk item))))))
    (walk term)
    (loop for key being the hash-keys of seen
          collect key)))

(defun %obligation-vars (obligation)
  (let ((declared (copy-list (smt-obligation-vars obligation)))
        (seen (make-hash-table :test #'equal)))
    (dolist (entry declared)
      (setf (gethash entry seen) t))
    (dolist (entry (%collect-smt-vars (compile-smt-obligation obligation) seen))
      (declare (ignore entry)))
    (sort (loop for key being the hash-keys of seen collect key)
          #'string<
          :key (lambda (entry)
                 (string-downcase
                  (etypecase (first entry)
                    (symbol (symbol-name (first entry)))
                    (string (first entry))))))))

(defun %spec-vars (spec)
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (obligation (smt-spec-obligations spec))
      (dolist (entry (%obligation-vars obligation))
        (setf (gethash entry seen) t)))
    (sort (loop for key being the hash-keys of seen collect key)
          #'string<
          :key (lambda (entry)
                 (string-downcase
                  (etypecase (first entry)
                    (symbol (symbol-name (first entry)))
                    (string (first entry))))))))

(defun emit-smtlib-for-smt-spec (spec path)
  (let ((path* (pathname path)))
    (ensure-directories-exist path*)
    (with-open-file (stream path* :direction :output :if-exists :supersede
                               :if-does-not-exist :create)
      (format stream "(set-logic ~A)~%~%" (string-upcase (symbol-name (smt-spec-logic spec))))
      (dolist (entry (%spec-vars spec))
        (destructuring-bind (name sort) entry
          (format stream "(declare-const ~A ~A)~%"
                  (%smt-atom->smtlib name)
                  (%smt-sort->smtlib sort))))
      (when (smt-spec-obligations spec)
        (terpri stream))
      (dolist (obligation (smt-spec-obligations spec))
        (format stream "(push)~%")
        (dolist (assumption (smt-obligation-assumptions obligation))
          (format stream "(assert ~A)~%" (%smt-term->smtlib assumption)))
        (when (smt-obligation-goal obligation)
          (format stream "(assert ~A)~%" (%smt-term->smtlib (smt-obligation-goal obligation))))
        (when (smt-obligation-label obligation)
          (format stream "(echo ~S)~%" (smt-obligation-label obligation)))
        (format stream "(check-sat)~%")
        (format stream "(pop)~%~%"))
      path*)))

(defun emitted-smtlib-path-for-smt-spec (spec &optional (directory #P"/home/user0/FORMAL/generated/parity/"))
  (merge-pathnames (format nil "~(~A~).smt2" (smt-spec-id spec))
                   (pathname directory)))

(defun %collapse-smt-forms (forms)
  (cond
    ((null forms) (smt-bool-const t))
    ((null (rest forms)) (first forms))
    (t (apply #'smt-and forms))))

(defun %obligation-default-status (polarity)
  (ecase polarity
    (:prove-unsat :rejected)
    (:find-sat :accepted)
    (:expect-status nil)))

(defun compile-smt-obligation (obligation)
  (let* ((goal (smt-obligation-goal obligation))
         (forms (append (copy-list (smt-obligation-assumptions obligation))
                        (if goal (list goal) '()))))
    (%collapse-smt-forms forms)))

(defun check-smt-obligation (obligation &optional (store (make-advisory-store)))
  (let* ((query (compile-smt-obligation obligation))
         (result (run-smt-check store query))
         (expected (or (smt-obligation-expected-status obligation)
                       (%obligation-default-status (smt-obligation-polarity obligation))))
         (actual (backend-result-status result)))
    (list :id (smt-obligation-id obligation)
          :label (smt-obligation-label obligation)
          :query query
          :expected-status expected
          :actual-status actual
          :matchedp (or (null expected) (eq expected actual))
          :unknownp (eq actual :unknown)
          :result result
          :store store)))

(defun check-smt-spec (spec)
  (mapcar #'check-smt-obligation (smt-spec-obligations spec)))

(defun summarize-smt-spec-results (spec-results)
  (let ((accepted 0)
        (rejected 0)
        (unknown 0)
        (matched 0)
        (mismatched 0))
    (dolist (entry spec-results)
      (case (getf entry :actual-status)
        (:accepted (incf accepted))
        (:rejected (incf rejected))
        (:unknown (incf unknown)))
      (if (getf entry :matchedp)
          (incf matched)
          (incf mismatched)))
    (list :total (length spec-results)
          :accepted accepted
          :rejected rejected
          :unknown unknown
          :matched matched
          :mismatched mismatched)))

(defun sweep-smt-spec-suite (specs)
  (let ((entries '()))
    (dolist (spec specs)
      (let* ((results (check-smt-spec spec))
             (summary (summarize-smt-spec-results results)))
        (push (list :spec-id (smt-spec-id spec)
                    :source-path (smt-spec-source-path spec)
                    :summary summary
                    :results results)
              entries)))
    (nreverse entries)))

(defun compare-smt-spec-with-smtlib-file (spec &optional (path (smt-spec-source-path spec)))
  (unless path
    (kernel-error "SMT spec ~S has no source path for parity comparison" (smt-spec-id spec)))
  (let* ((native-results (check-smt-spec spec))
         (imported-results (run-smtlib-file (make-advisory-store) path))
         (native-labels
           (mapcar (lambda (entry)
                     (cons (getf entry :label) (getf entry :actual-status)))
                   native-results))
         (imported-labels
           (mapcar (lambda (entry)
                     (cons (getf entry :label) (getf entry :status)))
                   imported-results)))
    (list :spec-id (smt-spec-id spec)
          :path path
          :native native-labels
          :imported imported-labels
          :matchedp (equal native-labels imported-labels))))

(defun check-emitted-smt-spec-parity (spec &optional (path (emitted-smtlib-path-for-smt-spec spec)))
  (let ((path* (emit-smtlib-for-smt-spec spec path)))
    (compare-smt-spec-with-smtlib-file spec path*)))
