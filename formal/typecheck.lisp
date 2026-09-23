(in-package :mini-kernel)

(defun check-sort (env ctx term)
  (let ((type (whnf env (infer env ctx term))))
    (case (term-tag type)
      (:sort
       (second type))
      (otherwise
       (kernel-error "expected a sort, got ~S" type)))))

(defun %native-conv? (env ctx lhs rhs)
  (let ((lhs* (whnf env lhs))
        (rhs* (whnf env rhs)))
    (case (term-tag lhs*)
      (:sort
       (and (eq (term-tag rhs*) :sort)
            (= (second lhs*) (second rhs*))))
      (:var
       (and (eq (term-tag rhs*) :var)
            (= (second lhs*) (second rhs*))))
      (:const
       (and (eq (term-tag rhs*) :const)
            (eq (second lhs*) (second rhs*))
            (equal (third lhs*) (third rhs*))))
      (:app
       (and (eq (term-tag rhs*) :app)
            (conv? env ctx (second lhs*) (second rhs*))
            (conv? env ctx (third lhs*) (third rhs*))))
      (:pi
       (and (eq (term-tag rhs*) :pi)
            (conv? env ctx (second lhs*) (second rhs*))
            (conv? env (cons (second lhs*) ctx)
                   (third lhs*)
                   (third rhs*))))
      (:lam
       (and (eq (term-tag rhs*) :lam)
            (conv? env ctx (second lhs*) (second rhs*))
            (conv? env (cons (second lhs*) ctx)
                   (third lhs*)
                   (third rhs*))))
      (otherwise
       nil))))

(defun %native-infer (env ctx term)
  (case (term-tag term)
    (:sort
     (mk-sort (1+ (second term))))
    (:var
     (ctx-lookup ctx (second term)))
    (:const
     (let ((decl (env-lookup env (second term))))
       (unless decl
         (kernel-error "unknown constant: ~A" (second term)))
       (instantiate-levels (decl-type decl) (third term))))
    (:pi
     (let ((u (check-sort env ctx (second term)))
           (v (check-sort env (cons (second term) ctx) (third term))))
       (mk-sort (max u v))))
    (:lam
     (check-sort env ctx (second term))
     (mk-pi (second term)
            (infer env (cons (second term) ctx) (third term))))
    (:app
     (let ((function-type (whnf env (infer env ctx (second term)))))
       (if (eq (term-tag function-type) :pi)
           (progn
             (check env ctx (third term) (second function-type))
             (subst-top (third term) (third function-type)))
           (kernel-error "application of non-function: ~S" function-type))))
    (:let
     (check-sort env ctx (third term))
     (check env ctx (second term) (third term))
     (subst-top (second term)
                (infer env (cons (third term) ctx) (fourth term))))
    (otherwise
     (kernel-error "unknown term in infer: ~S" term))))

(defun %native-check (env ctx term expected)
  (let ((actual (%native-infer env ctx term)))
    (unless (%native-conv? env ctx actual expected)
      (kernel-error "type mismatch~%expected: ~S~%actual:   ~S"
                    expected
                    actual))
    t))

(defun conv? (env ctx lhs rhs)
  (%kernel-implementation-slot-call #'kernel-implementation-conv
                                    #'%native-conv?
                                    env ctx lhs rhs))

(defun infer (env ctx term)
  (%kernel-implementation-slot-call #'kernel-implementation-infer
                                    #'%native-infer
                                    env ctx term))

(defun check (env ctx term expected)
  (%kernel-implementation-slot-call #'kernel-implementation-check
                                    #'%native-check
                                    env ctx term expected))

(install-native-kernel-implementation
 (%make-validated-kernel-implementation
  :id :native
  :shift #'%native-shift
  :subst #'%native-subst
  :subst-top #'%native-subst-top
  :ctx-lookup #'%native-ctx-lookup
  :whnf #'%native-whnf
  :conv #'%native-conv?
  :infer #'%native-infer
  :check #'%native-check
  :metadata '(:origin native)))
