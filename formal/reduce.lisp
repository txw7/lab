(in-package :mini-kernel)

(defun %native-reduce-nat-rec (env levels args)
  (if (< (length args) 4)
      (rebuild-apps (mk-const 'nat-rec levels) args)
      (destructuring-bind (motive base step n &rest rest) args
        (let ((n* (whnf env n)))
          (cond
            ((equal n* (mk-const 'zero))
             (whnf env (rebuild-apps base rest)))
            ((and (eq (term-tag n*) :app)
                  (equal (second n*) (mk-const 'succ)))
             (let* ((k (third n*))
                    (rec-call (rebuild-apps (mk-const 'nat-rec levels)
                                            (list motive base step k)))
                    (step-app (app* step (list k rec-call))))
               (whnf env (rebuild-apps step-app rest))))
            (t
             (rebuild-apps (mk-const 'nat-rec levels)
                           (append (list motive base step n*) rest))))))))

(defun %native-reduce-eq-rec (env levels args)
  (if (< (length args) 6)
      (rebuild-apps (mk-const 'eq-rec levels) args)
      (destructuring-bind (type lhs motive proof rhs equality &rest rest) args
        (let ((equality* (whnf env equality)))
          (if (and (eq (term-tag equality*) :app)
                   (eq (term-tag (second equality*)) :app)
                   (equal (second (second equality*)) (mk-const 'refl)))
              (whnf env (rebuild-apps proof rest))
              (rebuild-apps (mk-const 'eq-rec levels)
                            (append (list type lhs motive proof rhs equality*)
                                    rest)))))))

(defun %native-whnf (env term)
  (labels ((reduce-term (current)
             (case (term-tag current)
               (:let
                (reduce-term (subst-top (second current) (fourth current))))
               (:app
                (multiple-value-bind (head args)
                    (app-head+args current)
                  (reduce-head (reduce-term head) args)))
               (:const
                (let* ((name (second current))
                       (levels (third current))
                       (decl (env-lookup env name)))
                  (if (and decl
                           (eq (decl-kind decl) :def)
                           (decl-reduciblep decl))
                      (reduce-term (instantiate-levels (decl-value decl) levels))
                      current)))
               (otherwise
                current)))

           (reduce-head (head args)
             (cond
               ((null args)
                head)
               ((eq (term-tag head) :let)
                (reduce-term
                 (rebuild-apps (subst-top (second head) (fourth head)) args)))
               ((eq (term-tag head) :lam)
               (reduce-term
                 (rebuild-apps (subst-top (first args) (third head))
                               (rest args))))
               ((and (eq (term-tag head) :const)
                     (eq (second head) 'nat-rec))
                (%native-reduce-nat-rec env (third head) args))
               ((and (eq (term-tag head) :const)
                     (eq (second head) 'eq-rec))
                (%native-reduce-eq-rec env (third head) args))
               (t
                (rebuild-apps head args)))))
    (reduce-term term)))

(defun whnf (env term)
  (%kernel-implementation-slot-call #'kernel-implementation-whnf
                                    #'%native-whnf
                                    env term))

(defun reduce-nat-rec (env levels args)
  (%native-reduce-nat-rec env levels args))

(defun reduce-eq-rec (env levels args)
  (%native-reduce-eq-rec env levels args))

(install-native-kernel-implementation
 (%make-validated-kernel-implementation
  :id :native
  :shift #'%native-shift
  :subst #'%native-subst
  :subst-top #'%native-subst-top
  :ctx-lookup #'%native-ctx-lookup
  :whnf #'%native-whnf
  :metadata '(:origin native)))
