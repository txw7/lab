(in-package :mini-kernel-reference)

(declaim (ftype function r-whnf r-infer r-check))

(define-condition reference-error (error)
  ((message :initarg :message :reader reference-error-message))
  (:report (lambda (condition stream)
             (princ (reference-error-message condition) stream))))

(defun reference-error (format-string &rest args)
  (error 'reference-error :message (apply #'format nil format-string args)))

(defstruct rdecl
  kind
  type
  value
  reduciblep)

(defun make-reference-env (env)
  (let (entries)
    (maphash
     (lambda (name decl)
       (push (cons name
                   (make-rdecl
                    :kind (mini-kernel::decl-kind decl)
                    :type (mini-kernel::decl-type decl)
                    :value (mini-kernel::decl-value decl)
                    :reduciblep (mini-kernel::decl-reduciblep decl)))
             entries))
     env)
    entries))

(defun r-term-tag (term)
  (and (consp term) (first term)))

(defun r-core-term-p (term)
  (member (r-term-tag term)
          '(:sort :var :const :app :lam :pi :let)
          :test #'eq))

(defun validate-certificate (certificate)
  (unless (= (mini-kernel:certificate-schema-version certificate)
             mini-kernel::*certificate-schema-version*)
    (reference-error "unsupported certificate schema version: ~S"
                     (mini-kernel:certificate-schema-version certificate)))
  (unless (member (mini-kernel:certificate-judgment-kind certificate)
                  mini-kernel::*supported-certificate-judgments*
                  :test #'eq)
    (reference-error "unsupported certificate judgment kind: ~S"
                     (mini-kernel:certificate-judgment-kind certificate)))
  (unless (listp (mini-kernel:certificate-context certificate))
    (reference-error "certificate context must be a list, got ~S"
                     (mini-kernel:certificate-context certificate)))
  (unless (every #'r-core-term-p (mini-kernel:certificate-context certificate))
    (reference-error "certificate context contains non-core terms: ~S"
                     (mini-kernel:certificate-context certificate)))
  (unless (r-core-term-p (mini-kernel:certificate-term certificate))
    (reference-error "certificate term is not a core term: ~S"
                     (mini-kernel:certificate-term certificate)))
  (unless (r-core-term-p (mini-kernel:certificate-type certificate))
    (reference-error "certificate type is not a core term: ~S"
                     (mini-kernel:certificate-type certificate)))
  (unless (mini-kernel:certificate-env-digest certificate)
    (reference-error "certificate env digest is missing"))
  (unless (equal (mini-kernel:certificate-config-digest certificate)
                 mini-kernel::*current-config-digest*)
    (reference-error "certificate config digest mismatch~%expected: ~S~%actual:   ~S"
                     mini-kernel::*current-config-digest*
                     (mini-kernel:certificate-config-digest certificate)))
  (unless (listp (mini-kernel:certificate-checker-ids certificate))
    (reference-error "certificate checker ids must be a list, got ~S"
                     (mini-kernel:certificate-checker-ids certificate)))
  certificate)

(defun r-mk-var (k)
  `(:var ,k))

(defun r-mk-app (f a)
  `(:app ,f ,a))

(defun r-mk-lam (type body)
  `(:lam ,type ,body))

(defun r-mk-pi (type body)
  `(:pi ,type ,body))

(defun r-mk-let (value type body)
  `(:let ,value ,type ,body))

(defun r-app* (head args)
  (reduce (lambda (f a) (r-mk-app f a)) args :initial-value head))

(defun r-env-lookup (env name)
  (cdr (assoc name env :test #'eq)))

(defun r-instantiate-levels (term levels)
  (declare (ignore levels))
  term)

(defun r-shift (delta cutoff term)
  (case (r-term-tag term)
    (:sort
     term)
    (:var
     (let* ((k (second term))
            (shifted (if (>= k cutoff) (+ k delta) k)))
       (when (minusp shifted)
         (reference-error "negative de Bruijn index after shift: ~A" shifted))
       (r-mk-var shifted)))
    (:const
     term)
    (:app
     (r-mk-app (r-shift delta cutoff (second term))
               (r-shift delta cutoff (third term))))
    (:lam
     (r-mk-lam (r-shift delta cutoff (second term))
               (r-shift delta (1+ cutoff) (third term))))
    (:pi
     (r-mk-pi (r-shift delta cutoff (second term))
              (r-shift delta (1+ cutoff) (third term))))
    (:let
     (r-mk-let (r-shift delta cutoff (second term))
               (r-shift delta cutoff (third term))
               (r-shift delta (1+ cutoff) (fourth term))))
    (otherwise
     (reference-error "unknown term in shift: ~S" term))))

(defun r-subst (j replacement term)
  (case (r-term-tag term)
    (:sort
     term)
    (:var
     (if (= (second term) j)
         replacement
         term))
    (:const
     term)
    (:app
     (r-mk-app (r-subst j replacement (second term))
               (r-subst j replacement (third term))))
    (:lam
     (r-mk-lam (r-subst j replacement (second term))
               (r-subst (1+ j)
                        (r-shift 1 0 replacement)
                        (third term))))
    (:pi
     (r-mk-pi (r-subst j replacement (second term))
              (r-subst (1+ j)
                       (r-shift 1 0 replacement)
                       (third term))))
    (:let
     (r-mk-let (r-subst j replacement (second term))
               (r-subst j replacement (third term))
               (r-subst (1+ j)
                        (r-shift 1 0 replacement)
                        (fourth term))))
    (otherwise
     (reference-error "unknown term in subst: ~S" term))))

(defun r-subst-top (replacement body)
  (r-shift -1 0
           (r-subst 0 (r-shift 1 0 replacement) body)))

(defun r-app-head+args (term)
  (labels ((collect-apps (current args)
             (if (and (consp current) (eq (first current) :app))
                 (collect-apps (second current) (cons (third current) args))
                 (values current args))))
    (collect-apps term '())))

(defun r-rebuild-apps (head args)
  (r-app* head args))

(defun r-ctx-lookup (ctx k)
  (let ((type (nth k ctx)))
    (unless type
      (reference-error "unbound de Bruijn index: ~A" k))
    (r-shift (1+ k) 0 type)))

(defun r-reduce-nat-rec (env levels args)
  (if (< (length args) 4)
      (r-rebuild-apps `(:const mini-kernel::nat-rec ,levels) args)
      (destructuring-bind (motive base step n &rest rest) args
        (let ((n* (r-whnf env n)))
          (cond
            ((equal n* '(:const mini-kernel::zero ()))
             (r-whnf env (r-rebuild-apps base rest)))
            ((and (eq (r-term-tag n*) :app)
                  (equal (second n*) '(:const mini-kernel::succ ())))
             (let* ((k (third n*))
                    (rec-call (r-rebuild-apps `(:const mini-kernel::nat-rec ,levels)
                                              (list motive base step k)))
                    (step-app (r-app* step (list k rec-call))))
               (r-whnf env (r-rebuild-apps step-app rest))))
            (t
             (r-rebuild-apps `(:const mini-kernel::nat-rec ,levels)
                             (append (list motive base step n*) rest))))))))

(defun r-reduce-eq-rec (env levels args)
  (if (< (length args) 6)
      (r-rebuild-apps `(:const mini-kernel::eq-rec ,levels) args)
      (destructuring-bind (type lhs motive proof rhs equality &rest rest) args
        (let ((equality* (r-whnf env equality)))
          (if (and (eq (r-term-tag equality*) :app)
                   (eq (r-term-tag (second equality*)) :app)
                   (equal (second (second equality*)) '(:const mini-kernel::refl ())))
              (r-whnf env (r-rebuild-apps proof rest))
              (r-rebuild-apps `(:const mini-kernel::eq-rec ,levels)
                              (append (list type lhs motive proof rhs equality*)
                                      rest)))))))

(defun r-whnf (env term)
  (labels ((reduce-term (current)
             (case (r-term-tag current)
               (:let
                (reduce-term (r-subst-top (second current) (fourth current))))
               (:app
                (multiple-value-bind (head args)
                    (r-app-head+args current)
                  (reduce-head (reduce-term head) args)))
               (:const
                (let* ((name (second current))
                       (levels (third current))
                       (decl (r-env-lookup env name)))
                  (if (and decl
                           (eq (rdecl-kind decl) :def)
                           (rdecl-reduciblep decl))
                      (reduce-term (r-instantiate-levels (rdecl-value decl) levels))
                      current)))
               (otherwise
                current)))
           (reduce-head (head args)
             (cond
               ((null args)
                head)
               ((eq (r-term-tag head) :let)
                (reduce-term
                 (r-rebuild-apps (r-subst-top (second head) (fourth head)) args)))
               ((eq (r-term-tag head) :lam)
               (reduce-term
                 (r-rebuild-apps (r-subst-top (first args) (third head))
                                 (rest args))))
               ((and (eq (r-term-tag head) :const)
                     (eq (second head) 'mini-kernel::nat-rec))
                (r-reduce-nat-rec env (third head) args))
               ((and (eq (r-term-tag head) :const)
                     (eq (second head) 'mini-kernel::eq-rec))
                (r-reduce-eq-rec env (third head) args))
               (t
                (r-rebuild-apps head args)))))
    (reduce-term term)))

(defun r-check-sort (env ctx term)
  (let ((type (r-whnf env (r-infer env ctx term))))
    (if (eq (r-term-tag type) :sort)
        (second type)
        (reference-error "expected a sort, got ~S" type))))

(defun r-conv (env ctx lhs rhs)
  (let ((lhs* (r-whnf env lhs))
        (rhs* (r-whnf env rhs)))
    (case (r-term-tag lhs*)
      (:sort
       (and (eq (r-term-tag rhs*) :sort)
            (= (second lhs*) (second rhs*))))
      (:var
       (and (eq (r-term-tag rhs*) :var)
            (= (second lhs*) (second rhs*))))
      (:const
       (and (eq (r-term-tag rhs*) :const)
            (eq (second lhs*) (second rhs*))
            (equal (third lhs*) (third rhs*))))
      (:app
       (and (eq (r-term-tag rhs*) :app)
            (r-conv env ctx (second lhs*) (second rhs*))
            (r-conv env ctx (third lhs*) (third rhs*))))
      (:pi
       (and (eq (r-term-tag rhs*) :pi)
            (r-conv env ctx (second lhs*) (second rhs*))
            (r-conv env (cons (second lhs*) ctx)
                    (third lhs*)
                    (third rhs*))))
      (:lam
       (and (eq (r-term-tag rhs*) :lam)
            (r-conv env ctx (second lhs*) (second rhs*))
            (r-conv env (cons (second lhs*) ctx)
                    (third lhs*)
                    (third rhs*))))
      (otherwise
       nil))))

(defun r-infer (env ctx term)
  (case (r-term-tag term)
    (:sort
     `(:sort ,(1+ (second term))))
    (:var
     (r-ctx-lookup ctx (second term)))
    (:const
     (let ((decl (r-env-lookup env (second term))))
       (unless decl
         (reference-error "unknown constant: ~A" (second term)))
       (r-instantiate-levels (rdecl-type decl) (third term))))
    (:pi
     `(:sort ,(max (r-check-sort env ctx (second term))
                    (r-check-sort env (cons (second term) ctx) (third term)))))
    (:lam
     (r-check-sort env ctx (second term))
     (r-mk-pi (second term)
              (r-infer env (cons (second term) ctx) (third term))))
    (:app
     (let ((function-type (r-whnf env (r-infer env ctx (second term)))))
       (if (eq (r-term-tag function-type) :pi)
           (progn
             (r-check env ctx (third term) (second function-type))
             (r-subst-top (third term) (third function-type)))
           (reference-error "application of non-function: ~S" function-type))))
    (:let
     (r-check-sort env ctx (third term))
     (r-check env ctx (second term) (third term))
     (r-subst-top (second term)
                  (r-infer env (cons (third term) ctx) (fourth term))))
    (otherwise
     (reference-error "unknown term in infer: ~S" term))))

(defun r-check (env ctx term expected)
  (let ((actual (r-infer env ctx term)))
    (unless (r-conv env ctx actual expected)
      (reference-error "type mismatch~%expected: ~S~%actual:   ~S"
                       expected
                       actual))
    t))

(defun check-certificate (env certificate &key (expected-env-digest nil))
  (validate-certificate certificate)
  (when (and expected-env-digest
             (not (equal (mini-kernel:certificate-env-digest certificate) expected-env-digest)))
    (reference-error "certificate environment digest mismatch~%expected: ~S~%actual:   ~S"
                     expected-env-digest
                     (mini-kernel:certificate-env-digest certificate)))
  (r-check env
           (mini-kernel:certificate-context certificate)
           (mini-kernel:certificate-term certificate)
           (mini-kernel:certificate-type certificate)))
