(in-package :mini-kernel)

(defparameter *scripted-alignment-source-root*
  #.(make-pathname :name nil :type nil
                   :defaults (or *compile-file-truename*
                                 *load-truename*
                                 *default-pathname-defaults*)))

(defun %scripted-alignment-artifact-path ()
  (merge-pathnames "generated/scripted-alignment-schemas.lean"
                   *scripted-alignment-source-root*))

(defun %scripted-whnf-artifact-path ()
  (merge-pathnames "generated/mini-kernel-whnf.lean"
                   *scripted-alignment-source-root*))

(defun %scripted-step-result (name status &key summary error)
  (list :name name
        :status status
        :summary summary
        :error error))

(defun %run-scripted-step (name thunk)
  (handler-case
      (multiple-value-bind (value summary)
          (funcall thunk)
        (values value
                (%scripted-step-result name :accepted :summary summary)))
    (error (condition)
      (values nil
              (%scripted-step-result name
                                     :rejected
                                     :error (princ-to-string condition))))))

(defun %scripted-nat ()
  (mk-const 'nat))

(defun %scripted-zero ()
  (mk-const 'zero))

(defun %scripted-succ (term)
  (mk-app (mk-const 'succ) term))

(defun %scripted-sample-terms ()
  (let ((nat (%scripted-nat))
        (zero (%scripted-zero)))
    (list
     (mk-sort 0)
     (mk-var 0)
     (mk-var 1)
     nat
     zero
     (%scripted-succ zero)
     (mk-app (mk-var 1) (mk-var 0))
     (mk-lam nat (mk-var 0))
     (mk-lam nat (mk-var 1))
     (mk-pi nat (mk-var 0))
     (mk-let zero nat (mk-var 0))
     (mk-let (mk-var 0) nat (mk-var 1)))))

(defun %scripted-sample-contexts ()
  (let ((nat (%scripted-nat)))
    (list
     '()
     (list nat)
     (list (mk-var 0) (mk-sort 0))
     (list nat nat))))

(defun %scripted-theorem-parity-summary (artifact)
  (let* ((zero (%scripted-zero))
         (nat (%scripted-nat))
         (beta-term (mk-app (mk-lam nat (mk-var 0)) zero))
         (cases
           (list
            (list :schema-id :declarativecore-weakening
                  :params (list :gamma '()
                                :a nat
                                :term zero
                                :type nat))
            (list :schema-id :declarativecore-substitution
                  :params (list :gamma '()
                                :a nat
                                :term (mk-var 0)
                                :type nat
                                :replacement zero))
            (list :schema-id :declarativecore-subject-reduction
                  :params (list :gamma '()
                                :term beta-term
                                :type nat
                                :reduct zero))
            (list :schema-id :declarativecore-krcheck-sound
                  :params (list :gamma '()
                                :term zero
                                :type nat))))
         (checked 0)
         (failures '()))
    (dolist (case cases)
      (incf checked)
      (unless (apply #'check-ingested-lean-statement-parity
                     artifact
                     (getf case :schema-id)
                     (getf case :params))
        (push case failures)))
    (list :checked checked
          :failed (length failures)
          :failures (nreverse failures))))

(defun %scripted-def-parity-summary (program)
  (let ((checked 0)
        (failures '()))
    (dolist (delta '(0 1 2))
      (dolist (cutoff '(0 1 2))
        (dolist (term (%scripted-sample-terms))
          (incf checked)
          (unless (check-ingested-lean-def-parity program "shift" delta cutoff term)
            (push (list :def "shift"
                        :args (list delta cutoff term))
                  failures)))))
    (dolist (j '(0 1))
      (dolist (replacement (list (%scripted-zero) (mk-var 0)))
        (dolist (term (%scripted-sample-terms))
          (incf checked)
          (unless (check-ingested-lean-def-parity program "subst" j replacement term)
            (push (list :def "subst"
                        :args (list j replacement term))
                  failures)))))
    (dolist (body (list (mk-var 0)
                        (mk-app (mk-var 1) (mk-var 0))
                        (mk-lam (%scripted-nat) (mk-var 1))
                        (mk-let (%scripted-zero) (%scripted-nat) (mk-var 1))))
      (dolist (argument (list (%scripted-zero) (mk-var 0)))
        (incf checked)
        (unless (check-ingested-lean-def-parity program "instantiate" body argument)
          (push (list :def "instantiate"
                      :args (list body argument))
                failures))))
    (dolist (ctx (%scripted-sample-contexts))
      (dolist (k '(0 1 2 3))
        (incf checked)
        (unless (check-ingested-lean-def-parity program "lookup" ctx k)
          (push (list :def "lookup"
                      :args (list ctx k))
                failures))))
    (dolist (args '((1 0 0)
                    (2 3 1)
                    (-1 0 0)
                    (-3 4 0)
                    (-3 1 0)))
      (incf checked)
      (unless (apply #'check-ingested-lean-def-parity program "shiftIndex" args)
        (push (list :def "shiftIndex" :args args)
              failures)))
    (list :checked checked
          :failed (length failures)
          :failures (nreverse failures))))

(defun %scripted-theorem-claim-specs ()
  (list
   (list :obligation-id :jd-weakening
         :parameters '(:max-depth 0 :max-context-size 1))
   (list :obligation-id :jd-substitution
         :parameters '(:max-depth 0 :max-context-size 1))
   (list :obligation-id :jd-subject-reduction
         :parameters '(:max-depth 1 :max-context-size 0))
   (list :obligation-id :jkr-soundness
         :parameters '(:max-depth 0 :max-context-size 1 :carrier-mode :dense))))

(defun %scripted-certificate-status (env certificate &key implementation)
  (handler-case
      (progn
        (check-certificate env certificate
                           :expected-env-digest :bootstrap-v1
                           :checker-implementation implementation)
        :accepted)
    (kernel-error ()
      :rejected)))

(defun %scripted-checker-path-summary (implementation)
  (let ((env (make-bootstrap-env))
        (checked 0)
        (failures '()))
    (dolist (group (list (cons :accepted (mini-kernel-corpus:accepted-certificates))
                         (cons :rejected (mini-kernel-corpus:rejected-certificates))))
      (dolist (entry (cdr group))
        (let* ((certificate (mini-kernel-corpus:corpus-entry-certificate entry))
               (native (%scripted-certificate-status env certificate))
               (ingested (%scripted-certificate-status env certificate
                                                       :implementation implementation)))
          (incf checked)
          (unless (eq native ingested)
            (push (list :group (car group)
                        :id (mini-kernel-corpus:corpus-entry-id entry)
                        :native native
                        :ingested ingested)
                  failures)))))
    (list :checked checked
          :failed (length failures)
          :failures (nreverse failures))))

(defun %scripted-theorem-claims-summary ()
  (let ((summaries '())
        (failures '()))
    (dolist (spec (%scripted-theorem-claim-specs))
      (let* ((claim (make-theorem-claim
                     (getf spec :obligation-id)
                     :parameters (getf spec :parameters)))
             (result (check-theorem-claim claim))
             (artifacts (backend-result-artifacts result))
             (summary (list :obligation-id (getf spec :obligation-id)
                            :status (backend-result-status result)
                            :checked (getf artifacts :checked)
                            :failure-count (length (getf artifacts :failures)))))
        (push summary summaries)
        (unless (eq (backend-result-status result) :accepted)
          (push summary failures))))
    (list :checked (length summaries)
          :failed (length failures)
          :results (nreverse summaries)
          :failures (nreverse failures))))

(defun %scripted-whnf-parity-summary (program)
  (let* ((terms (list
                 '(:let (:const mini-kernel::zero ())
                   (:const mini-kernel::nat ())
                   (:var 0))
                 '(:app
                   (:lam (:const mini-kernel::nat ()) (:var 0))
                   (:const mini-kernel::zero ()))
                 '(:const mini-kernel::add ())
                 '(:app
                   (:app
                    (:app
                     (:app (:const mini-kernel::nat-rec ())
                      (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                     (:const mini-kernel::zero ()))
                    (:lam (:const mini-kernel::nat ())
                     (:lam (:const mini-kernel::nat ())
                      (:app (:const mini-kernel::succ ()) (:var 0)))))
                   (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                 '(:app
                   (:app
                    (:app
                     (:app
                      (:app
                       (:app (:const mini-kernel::eq-rec ())
                        (:const mini-kernel::nat ()))
                       (:const mini-kernel::zero ()))
                      (:lam (:const mini-kernel::nat ())
                       (:lam
                        (:app
                         (:app
                          (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                          (:const mini-kernel::zero ()))
                         (:var 0))
                        (:const mini-kernel::nat ()))))
                     (:const mini-kernel::zero ()))
                    (:const mini-kernel::zero ()))
                   (:app
                    (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
                    (:const mini-kernel::zero ())))))
         (checked 0)
         (failures '()))
    (dolist (term terms)
      (incf checked)
      (unless (check-ingested-lean-def-parity program "whnf" term)
        (push (list :def "whnf" :args (list term)) failures)))
    (dolist (args (list
                   (list '(:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ()))
                         '(:const mini-kernel::zero ())
                         '(:lam (:const mini-kernel::nat ())
                           (:lam (:const mini-kernel::nat ())
                            (:app (:const mini-kernel::succ ()) (:var 0))))
                         '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))
      (incf checked)
      (unless (check-ingested-lean-def-parity program "reduceNatRec" args)
        (push (list :def "reduceNatRec" :args (list args)) failures)))
    (dolist (args (list
                   (list '(:const mini-kernel::nat ())
                         '(:const mini-kernel::zero ())
                         '(:lam (:const mini-kernel::nat ())
                           (:lam
                            (:app
                             (:app
                              (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                              (:const mini-kernel::zero ()))
                             (:var 0))
                            (:const mini-kernel::nat ())))
                         '(:const mini-kernel::zero ())
                         '(:const mini-kernel::zero ())
                         '(:app
                           (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
                           (:const mini-kernel::zero ())))))
      (incf checked)
      (unless (check-ingested-lean-def-parity program "reduceEqRec" args)
        (push (list :def "reduceEqRec" :args (list args)) failures)))
    (list :checked checked
          :failed (length failures)
          :failures (nreverse failures))))

(defun %scripted-conv-parity-summary (program)
  (let ((checked 0)
        (failures '()))
    (dolist (entry (list
                    (list '()
                          '(:app
                            (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
                            (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                          '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                    (list '()
                          '(:app
                            (:app
                             (:app
                              (:app (:const mini-kernel::nat-rec ())
                               (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                              (:const mini-kernel::zero ()))
                             (:lam (:const mini-kernel::nat ())
                              (:lam (:const mini-kernel::nat ())
                               (:app (:const mini-kernel::succ ()) (:var 0)))))
                            (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                          '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))))
      (incf checked)
      (unless (apply #'check-ingested-lean-def-parity program "conv" entry)
        (push (list :def "conv" :args entry) failures)))
    (list :checked checked
          :failed (length failures)
          :failures (nreverse failures))))

(defun run-scripted-alignment-pass
    (&key
       (artifact-path (%scripted-alignment-artifact-path))
       (whnf-artifact-path (%scripted-whnf-artifact-path)))
  (let ((steps '())
        (theorem-artifact nil)
        (def-program nil)
        (whnf-program nil))
    (labels ((record-step (step)
               (push step steps)
               step)
             (finish (status)
               (make-backend-result
                :backend-id 'scripted-alignment
                :status status
                :evidence '(:scripted-alignment-pass)
                :artifacts (list :artifact-path artifact-path
                                 :whnf-artifact-path whnf-artifact-path
                                 :steps (nreverse steps)))))
      (multiple-value-bind (path step)
          (%run-scripted-step
           :generate-lean-theorem-artifact
           (lambda ()
             (let ((generated (generate-lean-theorem-artifact artifact-path)))
               (values generated
                       (list :path generated)))))
        (declare (ignore path))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (artifact step)
          (%run-scripted-step
           :ingest-lean-theorem-artifact
           (lambda ()
             (let ((ingested (ingest-lean-theorem-artifact artifact-path)))
               (values ingested
                       (list :schema-count (length (list-ingested-lean-theorem-schemas ingested))
                             :source-digest (lean-ingest-artifact-source-digest ingested))))))
        (setf theorem-artifact artifact)
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (path step)
          (%run-scripted-step
           :generate-lean-whnf-program
           (lambda ()
             (let ((generated (generate-lean-whnf-program whnf-artifact-path)))
               (values generated
                       (list :path generated)))))
        (declare (ignore path))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (program step)
          (%run-scripted-step
           :ingest-declarativecore-def-program
           (lambda ()
             (let ((ingested (ingest-declarativecore-def-program)))
               (values ingested
                       (list :function-count (length (list-ingested-lean-def-functions ingested))
                             :source-digest (lean-def-program-source-digest ingested))))))
        (setf def-program program)
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (program step)
          (%run-scripted-step
           :ingest-mini-kernel-whnf-program
           (lambda ()
             (let ((ingested (ingest-mini-kernel-whnf-program whnf-artifact-path)))
               (values ingested
                       (list :function-count (length (list-ingested-lean-def-functions ingested))
                             :source-digest (lean-def-program-source-digest ingested))))))
        (setf whnf-program program)
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (summary step)
          (%run-scripted-step
           :theorem-statement-parity
           (lambda ()
             (let ((summary (%scripted-theorem-parity-summary theorem-artifact)))
               (unless (zerop (getf summary :failed))
                 (kernel-error "theorem statement parity failures: ~S"
                               (getf summary :failures)))
               (values summary summary))))
        (declare (ignore summary))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (summary step)
          (%run-scripted-step
           :def-parity
           (lambda ()
             (let ((summary (%scripted-def-parity-summary def-program)))
               (unless (zerop (getf summary :failed))
                 (kernel-error "def parity failures: ~S" (getf summary :failures)))
               (values summary summary))))
        (declare (ignore summary))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (summary step)
          (%run-scripted-step
           :whnf-def-parity
           (lambda ()
             (let ((summary (%scripted-whnf-parity-summary whnf-program)))
               (unless (zerop (getf summary :failed))
                 (kernel-error "whnf def parity failures: ~S"
                               (getf summary :failures)))
               (values summary summary))))
        (declare (ignore summary))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (summary step)
          (%run-scripted-step
           :conv-def-parity
           (lambda ()
             (let ((summary (%scripted-conv-parity-summary whnf-program)))
               (unless (zerop (getf summary :failed))
                 (kernel-error "conv def parity failures: ~S"
                               (getf summary :failures)))
               (values summary summary))))
        (declare (ignore summary))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (summary step)
          (%run-scripted-step
           :checker-path-parity
           (lambda ()
             (let* ((implementation
                      (make-ingested-lean-whnf-kernel-implementation
                       :primitive-program def-program
                       :whnf-program whnf-program))
                    (summary (%scripted-checker-path-summary implementation)))
               (unless (zerop (getf summary :failed))
                 (kernel-error "checker path parity failures: ~S"
                               (getf summary :failures)))
               (values summary summary))))
        (declare (ignore summary))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (summary step)
          (%run-scripted-step
           :reference-checker-path-parity
           (lambda ()
             (let* ((implementation (make-reference-kernel-implementation))
                    (summary (%scripted-checker-path-summary implementation)))
               (unless (zerop (getf summary :failed))
                 (kernel-error "reference checker path parity failures: ~S"
                               (getf summary :failures)))
               (values summary summary))))
        (declare (ignore summary))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (multiple-value-bind (summary step)
          (%run-scripted-step
           :theorem-claim-checks
           (lambda ()
             (let ((summary (%scripted-theorem-claims-summary)))
               (unless (zerop (getf summary :failed))
                 (kernel-error "theorem claim failures: ~S"
                               (getf summary :failures)))
               (values summary summary))))
        (declare (ignore summary))
        (record-step step)
        (unless (eq (getf step :status) :accepted)
          (return-from run-scripted-alignment-pass (finish :rejected))))
      (finish :accepted))))

(defun print-scripted-alignment-summary (&key (artifact-path (%scripted-alignment-artifact-path)))
  (let* ((result (run-scripted-alignment-pass :artifact-path artifact-path))
         (artifacts (backend-result-artifacts result)))
    (format t "~S~%"
            (list :status (backend-result-status result)
                  :artifact-path (getf artifacts :artifact-path)
                  :steps (getf artifacts :steps)))
    result))
