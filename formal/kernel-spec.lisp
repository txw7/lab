(in-package :mini-kernel)

(defstruct kernel-obligation
  id
  judgment
  (expected-status :accepted)
  (semantic-tags '())
  source-ref
  metadata)

(defstruct kernel-spec
  id
  obligations
  (semantic-tags '())
  metadata)

(defun %kernel-boolean->status (value)
  (if value :accepted :rejected))

(defun check-kernel-obligation-kr (obligation &optional (reference-env (mini-kernel-reference:make-reference-env
                                                                        (make-bootstrap-env))))
  (let* ((judgment (kernel-obligation-judgment obligation))
         (acceptedp (j-kr reference-env judgment))
         (actual-status (%kernel-boolean->status acceptedp))
         (expected-status (kernel-obligation-expected-status obligation)))
    (list :id (kernel-obligation-id obligation)
          :lane :kr
          :judgment judgment
          :expected-status expected-status
          :actual-status actual-status
          :matchedp (eq expected-status actual-status))))

(defun check-kernel-obligation-kl (obligation &optional (env (make-bootstrap-env)))
  (let* ((judgment (kernel-obligation-judgment obligation))
         (acceptedp (j-kl env judgment))
         (actual-status (%kernel-boolean->status acceptedp))
         (expected-status (kernel-obligation-expected-status obligation)))
    (list :id (kernel-obligation-id obligation)
          :lane :kl
          :judgment judgment
          :expected-status expected-status
          :actual-status actual-status
          :matchedp (eq expected-status actual-status))))

(defun check-kernel-obligation-defir
    (obligation &key (env (make-bootstrap-env))
                     (implementation (make-defir-kernel-implementation)))
  (let* ((judgment (kernel-obligation-judgment obligation))
         (acceptedp (with-kernel-implementation (implementation)
                      (j-kl env judgment)))
         (actual-status (%kernel-boolean->status acceptedp))
         (expected-status (kernel-obligation-expected-status obligation)))
    (list :id (kernel-obligation-id obligation)
          :lane :defir
          :judgment judgment
          :expected-status expected-status
          :actual-status actual-status
          :matchedp (eq expected-status actual-status))))

(defun check-kernel-spec-kr (spec &optional (reference-env (mini-kernel-reference:make-reference-env
                                                            (make-bootstrap-env))))
  (mapcar (lambda (obligation)
            (check-kernel-obligation-kr obligation reference-env))
          (kernel-spec-obligations spec)))

(defun check-kernel-spec-kl (spec &optional (env (make-bootstrap-env)))
  (mapcar (lambda (obligation)
            (check-kernel-obligation-kl obligation env))
          (kernel-spec-obligations spec)))

(defun check-kernel-spec-defir
    (spec &key (env (make-bootstrap-env))
               (implementation (make-defir-kernel-implementation)))
  (mapcar (lambda (obligation)
            (check-kernel-obligation-defir obligation
                                          :env env
                                          :implementation implementation))
          (kernel-spec-obligations spec)))

(defun summarize-kernel-spec-results (results)
  (let ((accepted 0)
        (rejected 0)
        (matched 0)
        (mismatched 0))
    (dolist (entry results)
      (case (getf entry :actual-status)
        (:accepted (incf accepted))
        (:rejected (incf rejected)))
      (if (getf entry :matchedp)
          (incf matched)
          (incf mismatched)))
    (list :total (length results)
          :accepted accepted
          :rejected rejected
          :matched matched
          :mismatched mismatched)))

(defun compare-kernel-obligation-kr-kl
    (obligation &key (env (make-bootstrap-env))
                      (reference-env (mini-kernel-reference:make-reference-env env)))
  (let* ((kr (check-kernel-obligation-kr obligation reference-env))
         (kl (check-kernel-obligation-kl obligation env)))
    (list :id (kernel-obligation-id obligation)
          :expected-status (kernel-obligation-expected-status obligation)
          :kr-status (getf kr :actual-status)
          :kl-status (getf kl :actual-status)
          :matchedp (eq (getf kr :actual-status)
                        (getf kl :actual-status))
          :kr kr
          :kl kl)))

(defun compare-kernel-spec-kr-kl
    (spec &key (env (make-bootstrap-env))
               (reference-env (mini-kernel-reference:make-reference-env env)))
  (let ((entries
          (mapcar (lambda (obligation)
                    (compare-kernel-obligation-kr-kl obligation
                                                    :env env
                                                    :reference-env reference-env))
                  (kernel-spec-obligations spec))))
    (list :spec-id (kernel-spec-id spec)
          :entries entries
          :matchedp (every (lambda (entry) (getf entry :matchedp)) entries))))

(defun compare-kernel-obligation-kr-kl-defir
    (obligation &key (env (make-bootstrap-env))
                      (reference-env (mini-kernel-reference:make-reference-env env))
                      (implementation (make-defir-kernel-implementation)))
  (let* ((kr (check-kernel-obligation-kr obligation reference-env))
         (kl (check-kernel-obligation-kl obligation env))
         (defir (check-kernel-obligation-defir obligation
                                               :env env
                                               :implementation implementation))
         (kr-status (getf kr :actual-status))
         (kl-status (getf kl :actual-status))
         (defir-status (getf defir :actual-status)))
    (list :id (kernel-obligation-id obligation)
          :expected-status (kernel-obligation-expected-status obligation)
          :kr-status kr-status
          :kl-status kl-status
          :defir-status defir-status
          :matchedp (and (eq kr-status kl-status)
                         (eq kr-status defir-status))
          :kr kr
          :kl kl
          :defir defir)))

(defun compare-kernel-spec-kr-kl-defir
    (spec &key (env (make-bootstrap-env))
               (reference-env (mini-kernel-reference:make-reference-env env))
               (implementation (make-defir-kernel-implementation)))
  (let ((entries
          (mapcar (lambda (obligation)
                    (compare-kernel-obligation-kr-kl-defir obligation
                                                          :env env
                                                          :reference-env reference-env
                                                          :implementation implementation))
                  (kernel-spec-obligations spec))))
    (list :spec-id (kernel-spec-id spec)
          :entries entries
          :matchedp (every (lambda (entry) (getf entry :matchedp)) entries))))

(defun certificate->kernel-obligation (entry expected-status)
  (let ((certificate (mini-kernel-corpus:corpus-entry-certificate entry)))
    (make-kernel-obligation
     :id (mini-kernel-corpus:corpus-entry-id entry)
     :judgment (make-typing-judgment
                (certificate-context certificate)
                (certificate-term certificate)
                (certificate-type certificate)
                (certificate-config-digest certificate))
     :expected-status expected-status
     :semantic-tags '(:typing :certificate)
     :source-ref (mini-kernel-corpus:corpus-entry-id entry)
     :metadata (certificate-metadata certificate))))

(defun %take (items count)
  (loop for item in items
        for index below count
        collect item))

(defun make-certificate-kernel-spec (&key
                                       (accepted-limit 4)
                                       (rejected-limit 4))
  (make-kernel-spec
   :id :certificate-kernel-core
   :semantic-tags '(:kernel :certificate :typing)
   :obligations
   (append
    (mapcar (lambda (entry)
              (certificate->kernel-obligation entry :accepted))
            (%take (mini-kernel-corpus:accepted-certificates) accepted-limit))
    (mapcar (lambda (entry)
              (certificate->kernel-obligation entry :rejected))
            (%take (mini-kernel-corpus:rejected-certificates) rejected-limit)))))

(defun make-defeq-kernel-spec ()
  (make-kernel-spec
   :id :defeq-kernel-core
   :semantic-tags '(:kernel :defeq :conv)
   :obligations
   (list
    (make-kernel-obligation
     :id :defeq-add-zero-succ
     :judgment (make-defeq-judgment
                '()
                '(:app
                  (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
                  (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
                '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
     :expected-status :accepted
     :semantic-tags '(:defeq :positive))
    (make-kernel-obligation
     :id :defeq-zero-succ-zero
     :judgment (make-defeq-judgment
                '()
                '(:const mini-kernel::zero ())
                '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
     :expected-status :rejected
     :semantic-tags '(:defeq :negative))
    (make-kernel-obligation
     :id :defeq-var0-var0
     :judgment (make-defeq-judgment
                '((:const mini-kernel::nat ()))
                '(:var 0)
                '(:var 0))
     :expected-status :accepted
     :semantic-tags '(:defeq :binder))
    (make-kernel-obligation
     :id :defeq-beta-zero
     :judgment (make-defeq-judgment
                '()
                '(:app
                  (:lam (:const mini-kernel::nat ()) (:var 0))
                  (:const mini-kernel::zero ()))
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:defeq :beta))
    (make-kernel-obligation
     :id :defeq-let-zero
     :judgment (make-defeq-judgment
                '()
                '(:let (:const mini-kernel::zero ())
                  (:const mini-kernel::nat ())
                  (:var 0))
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:defeq :let)))))

(defun make-step-kernel-spec ()
  (make-kernel-spec
   :id :step-kernel-core
   :semantic-tags '(:kernel :step :reduction)
   :obligations
   (list
    (make-kernel-obligation
     :id :step-beta-zero
     :judgment (make-step-judgment
                '(:app
                  (:lam (:const mini-kernel::nat ()) (:var 0))
                  (:const mini-kernel::zero ()))
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:step :beta))
    (make-kernel-obligation
     :id :step-let-zero
     :judgment (make-step-judgment
                '(:let (:const mini-kernel::zero ())
                  (:const mini-kernel::nat ())
                  (:var 0))
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:step :let))
    (make-kernel-obligation
     :id :step-nat-rec-zero
     :judgment (make-step-judgment
                '(:app
                  (:app
                   (:app
                    (:app (:const mini-kernel::nat-rec ())
                     (:lam (:const mini-kernel::nat ()) (:const mini-kernel::nat ())))
                    (:const mini-kernel::zero ()))
                   (:lam (:const mini-kernel::nat ())
                    (:lam (:const mini-kernel::nat ())
                     (:app (:const mini-kernel::succ ()) (:var 0))))
                   )
                  (:const mini-kernel::zero ()))
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:step :iota-nat))
    (make-kernel-obligation
     :id :step-eq-rec-refl
     :judgment (make-step-judgment
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
                   (:const mini-kernel::zero ())))
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:step :iota-eq))
    (make-kernel-obligation
     :id :step-zero-no-succ
     :judgment (make-step-judgment
                '(:const mini-kernel::zero ())
                '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
     :expected-status :rejected
     :semantic-tags '(:step :negative)))))

(defun make-frozen-kernel-core-spec ()
  (make-kernel-spec
   :id :frozen-kernel-core
   :semantic-tags '(:kernel :kr :kl :frozen-fragment)
   :obligations
   (list
    (make-kernel-obligation
     :id :wf-empty-context
     :judgment (make-wf-context-judgment '())
     :expected-status :accepted
     :semantic-tags '(:wf-ctx))
    (make-kernel-obligation
     :id :typing-zero-nat
     :judgment (make-typing-judgment
                '()
                '(:const mini-kernel::zero ())
                '(:const mini-kernel::nat ()))
     :expected-status :accepted
     :semantic-tags '(:typing :bootstrap))
    (make-kernel-obligation
     :id :typing-zero-sort-rejected
     :judgment (make-typing-judgment
                '()
                '(:const mini-kernel::zero ())
                '(:sort 0))
     :expected-status :rejected
     :semantic-tags '(:typing :negative))
    (make-kernel-obligation
     :id :defeq-zero-zero
     :judgment (make-defeq-judgment
                '()
                '(:const mini-kernel::zero ())
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:defeq))
    (make-kernel-obligation
     :id :defeq-zero-succ-zero-rejected
     :judgment (make-defeq-judgment
                '()
                '(:const mini-kernel::zero ())
                '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
     :expected-status :rejected
     :semantic-tags '(:defeq :negative))
    (make-kernel-obligation
     :id :let-step-zero
     :judgment (make-step-judgment
                '(:let (:const mini-kernel::zero ())
                  (:const mini-kernel::nat ())
                  (:var 0))
                '(:const mini-kernel::zero ()))
     :expected-status :accepted
     :semantic-tags '(:step)))))

(defun make-default-kernel-spec-suite ()
  (list (make-frozen-kernel-core-spec)
        (make-certificate-kernel-spec)
        (make-defeq-kernel-spec)
        (make-step-kernel-spec)))
