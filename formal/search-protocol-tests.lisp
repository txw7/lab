(defpackage :mini-kernel-search-protocol-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-search-protocol-tests)

(define-condition test-failure (error)
  ((message :initarg :message :reader test-failure-message))
  (:report (lambda (condition stream)
             (princ (test-failure-message condition) stream))))

(defun fail-test (format-string &rest args)
  (error 'test-failure :message (apply #'format nil format-string args)))

(defmacro is-true (form)
  `(unless ,form
     (fail-test "expected truthy form: ~S" ',form)))

(defmacro is-equal (expected form)
  `(let ((expected-value ,expected)
         (actual-value ,form))
     (unless (equal expected-value actual-value)
       (fail-test "expected ~S, got ~S from ~S"
                  expected-value
                  actual-value
                  ',form))))

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun %nat ()
  '(:const mini-kernel::nat ()))

(defun %zero ()
  '(:const mini-kernel::zero ()))

(defun %beta-redex ()
  `(:app (:lam ,(%nat) (:var 0))
         ,(%zero)))

(defun test-one-step-successors-term-reduction ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (term (%beta-redex))
         (successors (mini-kernel:one-step-successors :term-reduction term :env env))
         (successor (first successors)))
    (is-equal 1 (length successors))
    (is-equal (%zero)
              (mini-kernel:successor-state-next successor))
    (is-equal '(:term-reduction-step 0)
              (mini-kernel:successor-state-label successor))
    (is-true (getf (mini-kernel:successor-state-metadata successor) :env-digest))))

(defun test-one-step-successors-stage1-runtime ()
  (let* ((program (mini-kernel:ingest-stage1-concept-file))
         (runtime (mini-kernel:stage1-boot-scenario program :c0-to-c1-to-c2-to-c3))
         (successors (mini-kernel:one-step-successors :stage1-runtime runtime :program program))
         (successor (first successors)))
    (is-equal 1 (length successors))
    (is-true (mini-kernel:successor-state-next successor))
    (is-true (equal :stage1-step (first (mini-kernel:successor-state-label successor))))
    (is-true (getf (mini-kernel:successor-state-metadata successor) :fragment))))

(defun test-expand-frontier-once ()
  (let* ((env (mini-kernel:make-bootstrap-env))
         (frontier
           (list
            (mini-kernel:make-search-branch
             :state (%beta-redex)
             :history '()))))
    (multiple-value-bind (next-frontier edges seen)
        (mini-kernel:expand-frontier-once
         :term-reduction
         frontier
         :env env
         :key-fn #'mini-kernel:state-key)
      (declare (ignore seen))
      (is-equal 1 (length next-frontier))
      (is-equal 1 (length edges))
      (is-equal (%zero)
                (mini-kernel:search-branch-state (first next-frontier)))
      (is-equal 1
                (length (mini-kernel:search-branch-history (first next-frontier))))
      (is-equal (%zero)
                (mini-kernel:successor-state-next
                 (getf (first edges) :successor))))))

(defun test-state-key-default ()
  (let ((term (%zero)))
    (is-equal (mini-kernel:artifact-digest term)
              (mini-kernel:state-key :term-reduction term))))

(defun test-branch-closes-p-default ()
  (is-equal t
            (mini-kernel:branch-closes-p
             :term-reduction
             '(:const mini-kernel::zero ())
             '(:const mini-kernel::zero ())))
  (is-equal nil
            (mini-kernel:branch-closes-p
             :term-reduction
             '(:const mini-kernel::zero ())
             '(:const mini-kernel::succ ()))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "one-step-successors-term-reduction"
                  #'test-one-step-successors-term-reduction)
            (cons "one-step-successors-stage1-runtime"
                  #'test-one-step-successors-stage1-runtime)
            (cons "expand-frontier-once"
                  #'test-expand-frontier-once)
            (cons "state-key-default"
                  #'test-state-key-default)
            (cons "branch-closes-p-default"
                  #'test-branch-closes-p-default)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "search protocol test suite failed"))
    t))
