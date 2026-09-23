(in-package :mini-kernel)

(define-condition frontend-error (error)
  ((message :initarg :message :reader frontend-error-message))
  (:report (lambda (condition stream)
             (princ (frontend-error-message condition) stream))))

(declaim (ftype function make-bootstrap-env
                          make-typing-certificate
                          check-certificate))

(defun frontend-error (format-string &rest args)
  (error 'frontend-error :message (apply #'format nil format-string args)))

(defun local-index (name locals)
  (position name locals :test #'eq))

(defun lower-term (surface &optional (locals '()))
  (handler-case
      (cond
        ((symbolp surface)
         (let ((index (local-index surface locals)))
           (if index
               (mk-var index)
               (mk-const surface))))

        ((atom surface)
         (frontend-error "unsupported surface atom: ~S" surface))

        ((eq (first surface) :sort)
         (destructuring-bind (_ u) surface
           (declare (ignore _))
           (mk-sort u)))

        ((eq (first surface) :const)
         (destructuring-bind (_ name &optional (levels '())) surface
           (declare (ignore _))
           (mk-const name levels)))

        ((eq (first surface) :app)
         (destructuring-bind (_ function argument) surface
           (declare (ignore _))
           (mk-app (lower-term function locals)
                   (lower-term argument locals))))

        ((eq (first surface) :lam)
         (destructuring-bind (_ binder-name binder-type body) surface
           (declare (ignore _))
           (mk-lam (lower-term binder-type locals)
                   (lower-term body (cons binder-name locals)))))

        ((eq (first surface) :pi)
         (destructuring-bind (_ binder-name binder-type body) surface
           (declare (ignore _))
           (mk-pi (lower-term binder-type locals)
                  (lower-term body (cons binder-name locals)))))

    ((eq (first surface) :let)
     (destructuring-bind (_ binder-name value value-type body) surface
       (declare (ignore _))
       (mk-let (lower-term value locals)
               (lower-term value-type locals)
               (lower-term body (cons binder-name locals)))))

    ((eq (first surface) :nat-rec)
     (destructuring-bind (_ scrutinee motive base step) surface
       (declare (ignore _))
       (destructuring-bind (k-name ih-name step-body) step
         (let* ((motive-core (lower-term motive locals))
                (base-core (lower-term base locals))
                (k-core (mk-var 0))
                (ih-type (mk-app (shift 1 0 motive-core) k-core))
                (step-core
                  (mk-lam (mk-const 'nat)
                          (mk-lam ih-type
                                  (lower-term step-body
                                              (cons ih-name
                                                    (cons k-name locals)))))))
           (app* (mk-const 'nat-rec)
                 (list motive-core
                       base-core
                       step-core
                       (lower-term scrutinee locals)))))))

    (t
     (frontend-error "unsupported surface form: ~S" surface)))
    (error (condition)
      (if (typep condition 'frontend-error)
          (error condition)
          (frontend-error "malformed surface term: ~S" surface)))))

(defun compile-stage-surface-certificates (surface-specs &key
                                                         (env (make-bootstrap-env))
                                                         (env-digest :bootstrap-v1)
                                                         (checker-id 'frontend-lower))
  (mapcar
   (lambda (spec)
     (destructuring-bind (&key id context term type metadata) spec
       (unless id
         (frontend-error "stage surface spec is missing :id: ~S" spec))
       (unless term
         (frontend-error "stage surface spec is missing :term: ~S" spec))
       (unless type
         (frontend-error "stage surface spec is missing :type: ~S" spec))
       (let* ((lowered-context (mapcar #'lower-term (or context '())))
              (lowered-term (lower-term term))
              (lowered-type (lower-term type))
              (certificate
                (make-typing-certificate
                 lowered-context
                 lowered-term
                 lowered-type
                 env-digest
                 :checker-ids (list checker-id)
                 :metadata (append (list :certificate-id id
                                         :surface-spec spec)
                                   metadata))))
         (check-certificate env certificate :expected-env-digest env-digest)
         certificate)))
   surface-specs))
