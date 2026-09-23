(in-package :mini-kernel-corpus)

(defstruct corpus-entry
  id
  certificate)

(defun make-generated-entry (id context term type &key
                               (env-digest :bootstrap-v1)
                               (checker-ids '(generator))
                               (metadata '(:corpus generated)))
  (make-corpus-entry
   :id id
   :certificate
   (mini-kernel:make-typing-certificate
    context
    term
    type
    env-digest
    :checker-ids checker-ids
    :metadata metadata)))

(defun accepted-certificates ()
  (list
   (make-corpus-entry
    :id :proof-demo
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:lam (:const mini-kernel::nat ())
       (:app
        (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
        (:var 0)))
     '(:pi (:const mini-kernel::nat ())
       (:app
        (:app
         (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
         (:var 0))
        (:var 0)))
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))
   (make-corpus-entry
    :id :zero-has-nat
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:const mini-kernel::zero ())
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))
   (make-corpus-entry
    :id :ctx-var0-has-nat
    :certificate
    (mini-kernel:make-typing-certificate
     '((:const mini-kernel::nat ()))
     '(:var 0)
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))
   (make-corpus-entry
    :id :let-zero-has-nat
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:let (:const mini-kernel::zero ())
       (:const mini-kernel::nat ())
       (:var 0))
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))
   (make-corpus-entry
    :id :succ-zero-has-nat
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))
   (make-corpus-entry
    :id :beta-zero-has-nat
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app
       (:lam (:const mini-kernel::nat ()) (:var 0))
       (:const mini-kernel::zero ()))
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))
   (make-corpus-entry
    :id :nested-let-under-binder-has-nat
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app
       (:lam (:const mini-kernel::nat ())
        (:let (:var 0)
         (:const mini-kernel::nat ())
         (:var 0)))
       (:const mini-kernel::zero ()))
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))
   (make-corpus-entry
    :id :add-zero-succ-has-nat
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app
       (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
       (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus accepted)))))

(defun rejected-certificates ()
  (list
   (make-corpus-entry
    :id :zero-is-not-proof
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:const mini-kernel::zero ())
     '(:app
       (:app
        (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
        (:const mini-kernel::zero ()))
       (:const mini-kernel::zero ()))
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :wrong-equality-claim
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:lam (:const mini-kernel::nat ())
       (:app
        (:app (:const mini-kernel::refl ()) (:const mini-kernel::nat ()))
        (:var 0)))
     '(:pi (:const mini-kernel::nat ())
       (:app
        (:app
         (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
         (:app (:const mini-kernel::succ ()) (:var 0)))
        (:var 0)))
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :ctx-var0-wrong-type
    :certificate
    (mini-kernel:make-typing-certificate
     '((:const mini-kernel::nat ()))
     '(:var 0)
     '(:app
       (:app
        (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
        (:const mini-kernel::zero ()))
       (:const mini-kernel::zero ()))
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :let-zero-not-proof
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:let (:const mini-kernel::zero ())
       (:const mini-kernel::nat ())
       (:var 0))
     '(:app
       (:app
        (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
        (:const mini-kernel::zero ()))
       (:const mini-kernel::zero ()))
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :pi-domain-not-sort
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:pi (:const mini-kernel::zero ()) (:const mini-kernel::nat ()))
     '(:sort 0)
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :zero-applied-as-function
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app (:const mini-kernel::zero ()) (:const mini-kernel::zero ()))
     '(:const mini-kernel::nat ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :beta-zero-wrong-proof-type
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app
       (:lam (:const mini-kernel::nat ()) (:var 0))
       (:const mini-kernel::zero ()))
     '(:app
       (:app
        (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
        (:const mini-kernel::zero ()))
       (:const mini-kernel::zero ()))
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :add-zero-succ-not-zero
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app
       (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
       (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
     '(:const mini-kernel::zero ())
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))
   (make-corpus-entry
    :id :add-zero-succ-converts-to-succ-zero
    :certificate
    (mini-kernel:make-typing-certificate
     '()
     '(:app
       (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
       (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ())))
     '(:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))
     :bootstrap-v1
     :checker-ids '(kl)
     :metadata '(:corpus rejected)))))

(defun malformed-certificates ()
  (let ((base (mini-kernel:make-typing-certificate
               '()
               '(:const mini-kernel::zero ())
               '(:const mini-kernel::nat ())
               :bootstrap-v1
               :checker-ids '(kl)
               :metadata '(:corpus malformed))))
    (list
     (let ((certificate (copy-structure base)))
       (setf (mini-kernel:certificate-schema-version certificate) 2)
       (make-corpus-entry :id :bad-schema-version :certificate certificate))
     (let ((certificate (copy-structure base)))
       (setf (mini-kernel:certificate-config-digest certificate) :wrong)
       (make-corpus-entry :id :bad-config-digest :certificate certificate))
     (let ((certificate (copy-structure base)))
       (setf (mini-kernel:certificate-context certificate) '(not-a-core-term))
       (make-corpus-entry :id :malformed-context :certificate certificate))
     (let ((certificate (copy-structure base)))
       (setf (mini-kernel:certificate-env-digest certificate) nil)
       (make-corpus-entry :id :missing-env-digest :certificate certificate))
     (let ((certificate (copy-structure base)))
       (setf (mini-kernel:certificate-term certificate) 42)
       (make-corpus-entry :id :malformed-term :certificate certificate))
     (let ((certificate (copy-structure base)))
       (setf (mini-kernel:certificate-checker-ids certificate) :not-a-list)
       (make-corpus-entry :id :malformed-checker-ids :certificate certificate)))))

(defun generated-certificates ()
  (let* ((beta-term '(:app
                      (:lam (:const mini-kernel::nat ()) (:var 0))
                      (:const mini-kernel::zero ())))
         (let-term '(:app
                     (:lam (:const mini-kernel::nat ())
                      (:let (:var 0)
                       (:const mini-kernel::nat ())
                       (:var 0)))
                     (:const mini-kernel::zero ())))
         (add-term '(:app
                     (:app (:const mini-kernel::add ()) (:const mini-kernel::zero ()))
                     (:app (:const mini-kernel::succ ()) (:const mini-kernel::zero ()))))
         (base (mini-kernel:make-typing-certificate
                '()
                '(:const mini-kernel::zero ())
                '(:const mini-kernel::nat ())
                :bootstrap-v1
                :checker-ids '(generator)
                :metadata '(:corpus generated))))
    (labels ((kw (format-string &rest args)
               (intern (string-upcase (apply #'format nil format-string args)) :keyword))
             (nat ()
               '(:const mini-kernel::nat ()))
             (zero ()
               '(:const mini-kernel::zero ()))
             (bad-type ()
               '(:const mini-kernel::zero ()))
             (nat-ctx (depth)
               (loop repeat depth collect (nat)))
             (gen-var-family ()
               (loop for depth in '(1 2)
                     append
                     (loop for index below depth
                           collect
                           (make-generated-entry
                            (kw "generated-var-~D-~D-ok" depth index)
                            (nat-ctx depth)
                            `(:var ,index)
                            (nat))
                           collect
                           (make-generated-entry
                            (kw "generated-var-~D-~D-bad-type" depth index)
                            (nat-ctx depth)
                            `(:var ,index)
                            (bad-type)))))
             (gen-lam-family ()
               (list
                (make-generated-entry
                 :generated-lam-id-ok
                 '()
                 `(:lam ,(nat) (:var 0))
                 `(:pi ,(nat) ,(nat)))
                (make-generated-entry
                 :generated-lam-id-bad-type
                 '()
                 `(:lam ,(nat) (:var 0))
                 (nat))
                (make-generated-entry
                 :generated-lam-const-ok
                 '()
                 `(:lam ,(nat) (:lam ,(nat) (:var 1)))
                 `(:pi ,(nat) (:pi ,(nat) ,(nat))))
                (make-generated-entry
                 :generated-lam-const-bad-type
                 '()
                 `(:lam ,(nat) (:lam ,(nat) (:var 1)))
                 `(:pi ,(nat) ,(nat)))))
             (gen-pi-family ()
               (list
                (make-generated-entry
                 :generated-pi-ok
                 '()
                 `(:pi ,(nat) ,(nat))
                 '(:sort 0))
                (make-generated-entry
                 :generated-pi-bad-type
                 '()
                 `(:pi ,(nat) ,(nat))
                 (nat))
                (make-generated-entry
                 :generated-pi-bad-domain
                 '()
                 `(:pi ,(zero) ,(nat))
                 '(:sort 0))))
             (gen-let-family ()
               (list
                (make-generated-entry
                 :generated-let-ok
                 '()
                 let-term
                 (nat))
                (make-generated-entry
                 :generated-let-bad-type
                 '()
                 let-term
                 '(:app
                   (:app
                    (:app (:const mini-kernel::eq ()) (:const mini-kernel::nat ()))
                    (:const mini-kernel::zero ()))
                   (:const mini-kernel::zero ())))
                (make-generated-entry
                 :generated-let-nested-ok
                 '()
                 `(:let ,(zero) ,(nat)
                    (:let (:var 0) ,(nat) (:var 0)))
                 (nat))
                (make-generated-entry
                 :generated-let-nested-bad-type
                 '()
                 `(:let ,(zero) ,(nat)
                    (:let (:var 0) ,(nat) (:var 0)))
                 (bad-type))))
             (gen-conv-family ()
               (list
                (make-generated-entry
                 :generated-beta-ok
                 '()
                 beta-term
                 (nat))
                (make-generated-entry
                 :generated-beta-bad-type
                 '()
                 beta-term
                 (bad-type))
                (make-generated-entry
                 :generated-add-ok
                 '()
                 add-term
                 (nat))
                (make-generated-entry
                 :generated-add-bad-type
                 '()
                 add-term
                 (bad-type))))
             (gen-malformed-family ()
               (list
                (let ((certificate (copy-structure base)))
                  (setf (mini-kernel:certificate-term certificate) 17)
                  (make-corpus-entry :id :generated-malformed-term :certificate certificate))
                (let ((certificate (copy-structure base)))
                  (setf (mini-kernel:certificate-context certificate) '(17))
                  (make-corpus-entry :id :generated-malformed-context :certificate certificate))
                (let ((certificate (copy-structure base)))
                  (setf (mini-kernel:certificate-env-digest certificate) nil)
                  (make-corpus-entry :id :generated-missing-env-digest :certificate certificate))
                (let ((certificate (copy-structure base)))
                  (setf (mini-kernel:certificate-checker-ids certificate) :bad)
                  (make-corpus-entry :id :generated-malformed-checker-ids :certificate certificate)))))
      (append
       (gen-conv-family)
       (gen-var-family)
       (gen-lam-family)
       (gen-pi-family)
       (gen-let-family)
       (gen-malformed-family)))))

(defun generated-entry-family (entry)
  (let* ((id-string (string-downcase (symbol-name (corpus-entry-id entry))))
         (prefix "generated-"))
    (cond
      ((not (search prefix id-string :start1 0 :end1 (length prefix)))
       :unknown)
      (t
       (let* ((rest (subseq id-string (length prefix)))
              (dash (position #\- rest)))
         (intern (string-upcase (if dash (subseq rest 0 dash) rest)) :keyword))))))

(defun generated-entry-outcome (env entry &optional reference-env)
  (let ((certificate (corpus-entry-certificate entry)))
    (list
     :valid-kl
     (handler-case
         (progn (mini-kernel:validate-certificate certificate) t)
       (mini-kernel::kernel-error () nil))
     :accepted-kl
     (handler-case
         (progn
           (mini-kernel:check-certificate env certificate :expected-env-digest :bootstrap-v1)
           t)
       (mini-kernel::kernel-error () nil))
     :valid-kr
     (when reference-env
       (handler-case
           (progn (mini-kernel-reference:validate-certificate certificate) t)
         (mini-kernel-reference::reference-error () nil)))
     :accepted-kr
     (when reference-env
       (handler-case
           (progn
             (mini-kernel-reference:check-certificate reference-env certificate :expected-env-digest :bootstrap-v1)
             t)
         (mini-kernel-reference::reference-error () nil))))))

(defun generated-corpus-report (&key env (reference-env nil))
  (let ((env (or env
                 (funcall
                  (symbol-function
                   (find-symbol "MAKE-BOOTSTRAP-ENV" :mini-kernel))))))
    (let ((table (make-hash-table :test #'eq)))
      (dolist (entry (generated-certificates))
        (let* ((family (generated-entry-family entry))
               (bucket (or (gethash family table)
                           (setf (gethash family table)
                                 (list :family family
                                       :total 0
                                       :valid-kl 0
                                       :accepted-kl 0
                                       :valid-kr 0
                                       :accepted-kr 0))))
               (outcome (generated-entry-outcome env entry reference-env)))
          (incf (getf bucket :total))
          (when (getf outcome :valid-kl)
            (incf (getf bucket :valid-kl)))
          (when (getf outcome :accepted-kl)
            (incf (getf bucket :accepted-kl)))
          (when (getf outcome :valid-kr)
            (incf (getf bucket :valid-kr)))
          (when (getf outcome :accepted-kr)
            (incf (getf bucket :accepted-kr)))
          (setf (gethash family table) bucket)))
      (sort (loop for value being the hash-values of table collect value)
            #'string<
            :key (lambda (bucket) (symbol-name (getf bucket :family)))))))

(defun render-generated-corpus-report (&key env reference-env)
  (with-output-to-string (stream)
    (format stream "# Generated Corpus Report~%~%")
    (format stream "Configuration: `~S`~%~%" mini-kernel::*current-config-digest*)
    (format stream "| Family | Total | Valid KL | Accepted KL | Valid KR | Accepted KR |~%")
    (format stream "| --- | ---: | ---: | ---: | ---: | ---: |~%")
    (dolist (bucket (generated-corpus-report :env env :reference-env reference-env))
      (format stream "| `~(~A~)` | ~D | ~D | ~D | ~D | ~D |~%"
              (getf bucket :family)
              (getf bucket :total)
              (getf bucket :valid-kl)
              (getf bucket :accepted-kl)
              (getf bucket :valid-kr)
              (getf bucket :accepted-kr)))))

(defun write-generated-corpus-report (path &key env reference-env)
  (with-open-file (stream path
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (write-string
     (render-generated-corpus-report :env env :reference-env reference-env)
     stream))
  path)
