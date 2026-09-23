(defpackage :mini-kernel-lean-def-ingest-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-lean-def-ingest-tests)

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

(defun %succ (term)
  `(:app (:const mini-kernel::succ ()) ,term))

(defun %sample-terms ()
  (let ((nat (%nat))
        (zero (%zero)))
    (list
     '(:sort 0)
     '(:var 0)
     '(:var 1)
     nat
     zero
     (%succ zero)
     `(:app (:var 1) (:var 0))
     `(:lam ,nat (:var 0))
     `(:lam ,nat (:var 1))
     `(:pi ,nat (:var 0))
     `(:let ,zero ,nat (:var 0))
     `(:let (:var 0) ,nat (:var 1)))))

(defun %sample-contexts ()
  (let ((nat (%nat)))
    (list
     '()
     (list nat)
     (list '(:var 0) '(:sort 0))
     (list nat nat))))

(defun test-ingest-declarativecore-def-program ()
  (let ((program (mini-kernel:ingest-declarativecore-def-program)))
    (is-equal 5 (length (mini-kernel:list-ingested-lean-def-functions program)))
    (is-true (mini-kernel:find-ingested-lean-def-function program "shiftIndex"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "shift"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "subst"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "instantiate"))
    (is-true (mini-kernel:find-ingested-lean-def-function program "lookup"))))

(defun test-ingested-def-source-blocks ()
  (let* ((program (mini-kernel:ingest-declarativecore-def-program))
         (shift (mini-kernel:find-ingested-lean-def-function program "shift"))
         (instantiate (mini-kernel:find-ingested-lean-def-function program "instantiate")))
    (is-true (search "def shift (delta : Int) (cutoff : Nat) : CoreTerm"
                     (mini-kernel:lean-def-function-source-block shift)))
    (is-true (search "| CoreTerm.var k => CoreTerm.var (shiftIndex delta k cutoff)"
                     (mini-kernel:lean-def-function-source-block shift)))
    (is-true (search "shift (-1) 0"
                     (mini-kernel:lean-def-function-source-block instantiate)))))

(defun test-shiftIndex-ingested-semantics ()
  (let ((program (mini-kernel:ingest-declarativecore-def-program)))
    (is-true (mini-kernel:check-ingested-lean-def-parity program "shiftIndex" 1 0 0))
    (is-true (mini-kernel:check-ingested-lean-def-parity program "shiftIndex" 2 3 1))
    (is-equal 0 (mini-kernel:call-ingested-lean-def program "shiftIndex" -1 0 0))
    (is-equal 1 (mini-kernel:call-ingested-lean-def program "shiftIndex" -3 4 0))
    (is-equal 0 (mini-kernel:call-ingested-lean-def program "shiftIndex" -3 1 0))))

(defun test-shift-ingested-parity ()
  (let ((program (mini-kernel:ingest-declarativecore-def-program)))
    (dolist (delta '(0 1 2))
      (dolist (cutoff '(0 1 2))
        (dolist (term (%sample-terms))
          (is-true
           (mini-kernel:check-ingested-lean-def-parity
            program
            "shift"
            delta
            cutoff
            term)))))))

(defun test-subst-ingested-parity ()
  (let ((program (mini-kernel:ingest-declarativecore-def-program))
        (replacements (list (%zero) '(:var 0))))
    (dolist (j '(0 1))
      (dolist (replacement replacements)
        (dolist (term (%sample-terms))
          (is-true
           (mini-kernel:check-ingested-lean-def-parity
            program
            "subst"
            j
            replacement
            term)))))))

(defun test-instantiate-ingested-parity ()
  (let ((program (mini-kernel:ingest-declarativecore-def-program))
        (bodies (list '(:var 0)
                      '(:app (:var 1) (:var 0))
                      `(:lam ,(%nat) (:var 1))
                      `(:let ,(%zero) ,(%nat) (:var 1))))
        (arguments (list (%zero) '(:var 0))))
    (dolist (body bodies)
      (dolist (argument arguments)
        (is-true
         (mini-kernel:check-ingested-lean-def-parity
          program
          "instantiate"
          body
          argument))))))

(defun test-lookup-ingested-parity ()
  (let ((program (mini-kernel:ingest-declarativecore-def-program)))
    (dolist (ctx (%sample-contexts))
      (dolist (k '(0 1 2 3))
        (is-true
         (mini-kernel:check-ingested-lean-def-parity
          program
          "lookup"
          ctx
          k))))))

(defun run-tests ()
  (let* ((tests
           (list
            (cons "ingest-declarativecore-def-program"
                  #'test-ingest-declarativecore-def-program)
            (cons "ingested-def-source-blocks"
                  #'test-ingested-def-source-blocks)
            (cons "shiftIndex-ingested-semantics"
                  #'test-shiftIndex-ingested-semantics)
            (cons "shift-ingested-parity"
                  #'test-shift-ingested-parity)
            (cons "subst-ingested-parity"
                  #'test-subst-ingested-parity)
            (cons "instantiate-ingested-parity"
                  #'test-instantiate-ingested-parity)
            (cons "lookup-ingested-parity"
                  #'test-lookup-ingested-parity)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "test suite failed"))
    t))
