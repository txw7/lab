(in-package :mini-kernel)

(defstruct decl
  kind
  type
  value
  reduciblep)

(defun mk-sort (u)
  `(:sort ,u))

(defun mk-var (k)
  `(:var ,k))

(defun mk-const (name &optional (levels '()))
  `(:const ,name ,levels))

(defun mk-app (f a)
  `(:app ,f ,a))

(defun mk-lam (type body)
  `(:lam ,type ,body))

(defun mk-pi (type body)
  `(:pi ,type ,body))

(defun mk-let (value type body)
  `(:let ,value ,type ,body))

(defun app* (head args)
  (reduce (lambda (f a) (mk-app f a)) args :initial-value head))

(defun make-env ()
  (make-hash-table :test #'eq))

(defun env-add (env name decl)
  (setf (gethash name env) decl)
  env)

(defun env-lookup (env name)
  (gethash name env))

(defun instantiate-levels (term levels)
  (declare (ignore levels))
  term)

(defun term-tag (term)
  (and (consp term) (first term)))

(defun app-head+args (term)
  (labels ((collect-apps (current args)
             (if (and (consp current) (eq (first current) :app))
                 (collect-apps (second current) (cons (third current) args))
                 (values current args))))
    (collect-apps term '())))

(defun rebuild-apps (head args)
  (app* head args))
