(defpackage :mini-kernel-smt-spec-tests
  (:use :cl)
  (:export #:run-tests))

(in-package :mini-kernel-smt-spec-tests)

(define-condition test-failure (error)
  ((message :initarg :message :reader test-failure-message))
  (:report (lambda (condition stream)
             (princ (test-failure-message condition) stream))))

(defun fail-test (format-string &rest args)
  (error 'test-failure :message (apply #'format nil format-string args)))

(defmacro is-equal (expected form)
  `(let ((expected-value ,expected)
         (actual-value ,form))
     (unless (equal expected-value actual-value)
       (fail-test "expected ~S, got ~S from ~S"
                  expected-value actual-value ',form))))

(defmacro is-true (form)
  `(unless ,form
     (fail-test "expected truthy form: ~S" ',form)))

(defun run-test (name thunk)
  (handler-case
      (progn
        (funcall thunk)
        (format t "ok   ~A~%" name)
        t)
    (error (condition)
      (format t "FAIL ~A~%  ~A~%" name condition)
      nil)))

(defun test-compile-smt-obligation ()
  (let* ((obligation
           (mini-kernel:make-smt-obligation
            :id :simple-bound
            :label "simple_bound"
            :assumptions
            (list (mini-kernel:smt-int-le (mini-kernel:smt-int-lit 0)
                                          (mini-kernel:smt-var 'x (mini-kernel:smt-int-sort))))
            :goal
            (mini-kernel:smt-int-le (mini-kernel:smt-var 'x (mini-kernel:smt-int-sort))
                                    (mini-kernel:smt-int-lit 3))
            :polarity :find-sat))
         (query (mini-kernel:compile-smt-obligation obligation)))
    (is-equal '(:and (:int-le (:int-lit 0) (:var x (:Int)))
                     (:int-le (:var x (:Int)) (:int-lit 3)))
              query)))

(defun test-emitted-smt-spec-parity ()
  (let* ((op (mini-kernel:smt-var 'op (mini-kernel:smt-bv-sort 8)))
         (sel (mini-kernel:smt-var 'sel (mini-kernel:smt-bv-sort 3)))
         (addr (mini-kernel:smt-var 'addr (mini-kernel:smt-bv-sort 16)))
         (exec-addr (mini-kernel:smt-bvor (mini-kernel:smt-concat op (mini-kernel:smt-bv-lit 8 #x00))
                                          (mini-kernel:smt-concat (mini-kernel:smt-bv-lit 13 0) sel)))
         (base (list (mini-kernel:smt-eq op (mini-kernel:smt-bv-lit 8 #xC1))
                     (mini-kernel:smt-eq sel (mini-kernel:smt-bv-lit 3 #b110))
                     (mini-kernel:smt-eq addr exec-addr)))
         (spec
           (mini-kernel:make-smt-spec
            :id :novel-exec-addr-c1-slot6
            :logic :qf_bv
            :semantic-tags '(:novel :exec-addr :bitvector)
            :obligations
            (list
             (mini-kernel:make-smt-obligation
              :id :novel-exec-addr-c1-slot6-sat
              :label "novel_exec_addr_c1_slot6_sat"
              :logic :qf_bv
              :polarity :find-sat
              :expected-status :accepted
              :assumptions base
              :goal (mini-kernel:smt-eq addr (mini-kernel:smt-bv-lit 16 #xC106)))
             (mini-kernel:make-smt-obligation
              :id :novel-exec-addr-c1-slot6-unsat
              :label "novel_exec_addr_c1_slot6_unsat"
              :logic :qf_bv
              :polarity :prove-unsat
              :expected-status :rejected
              :assumptions base
              :goal (mini-kernel:smt-not
                     (mini-kernel:smt-eq addr (mini-kernel:smt-bv-lit 16 #xC106)))))))
         (path (mini-kernel:emitted-smtlib-path-for-smt-spec spec))
         (report (mini-kernel:check-emitted-smt-spec-parity spec path)))
    (is-true (probe-file path))
    (is-true (getf report :matchedp))
    (is-equal '(("novel_exec_addr_c1_slot6_sat" . :accepted)
                ("novel_exec_addr_c1_slot6_unsat" . :rejected))
              (getf report :native))
    (is-equal '(("novel_exec_addr_c1_slot6_sat" . :accepted)
                ("novel_exec_addr_c1_slot6_unsat" . :rejected))
              (getf report :imported))))

(defun test-check-stage1-heap-commit-spec ()
  (let* ((results (mini-kernel:check-smt-spec
                   (mini-kernel:make-stage1-heap-commit-smt-spec)))
         (summary (mini-kernel:summarize-smt-spec-results results)))
    (is-equal 5 (getf summary :total))
    (is-equal 5 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal 2 (getf summary :rejected))
    (is-equal 3 (getf summary :unknown))))

(defun test-check-stage1-control-refinement-spec ()
  (let* ((results (mini-kernel:check-smt-spec
                   (mini-kernel:make-stage1-control-refinement-smt-spec)))
         (summary (mini-kernel:summarize-smt-spec-results results)))
    (is-equal 4 (getf summary :total))
    (is-equal 4 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal 3 (getf summary :rejected))
    (is-equal 1 (getf summary :unknown))))

(defun test-check-stage1-env-walk-spec ()
  (let* ((results (mini-kernel:check-smt-spec
                   (mini-kernel:make-stage1-env-walk-smt-spec)))
         (summary (mini-kernel:summarize-smt-spec-results results)))
    (is-equal 5 (getf summary :total))
    (is-equal 5 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal 5 (getf summary :rejected))))

(defun test-check-payload-traversal-search-spec ()
  (let* ((results (mini-kernel:check-smt-spec
                   (mini-kernel:make-payload-traversal-search-smt-spec)))
         (summary (mini-kernel:summarize-smt-spec-results results)))
    (is-equal 1 (getf summary :total))
    (is-equal 1 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal 1 (getf summary :accepted))
    (is-equal 0 (getf summary :rejected))
    (is-equal 0 (getf summary :unknown))))

(defun test-check-g2cl-interlock-closure-spec ()
  (let* ((results (mini-kernel:check-smt-spec
                   (mini-kernel:make-g2cl-interlock-closure-smt-spec)))
         (summary (mini-kernel:summarize-smt-spec-results results)))
    (is-equal 21 (getf summary :total))
    (is-equal 21 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal 7 (getf summary :accepted))
    (is-equal 14 (getf summary :rejected))
    (is-equal 0 (getf summary :unknown))))

(defun test-check-g2imm8-interlock-closure-spec ()
  (let* ((results (mini-kernel:check-smt-spec
                   (mini-kernel:make-g2imm8-interlock-closure-smt-spec)))
         (summary (mini-kernel:summarize-smt-spec-results results)))
    (is-equal 21 (getf summary :total))
    (is-equal 21 (getf summary :matched))
    (is-equal 0 (getf summary :mismatched))
    (is-equal 7 (getf summary :accepted))
    (is-equal 14 (getf summary :rejected))
    (is-equal 0 (getf summary :unknown))))

(defun test-stage1-heap-commit-imported-parity ()
  (let ((report (mini-kernel:compare-smt-spec-with-smtlib-file
                 (mini-kernel:make-stage1-heap-commit-smt-spec))))
    (is-true (getf report :matchedp))))

(defun test-stage1-control-refinement-imported-parity ()
  (let ((report (mini-kernel:compare-smt-spec-with-smtlib-file
                 (mini-kernel:make-stage1-control-refinement-smt-spec))))
    (is-true (getf report :matchedp))))

(defun test-stage1-env-walk-imported-parity ()
  (let ((report (mini-kernel:compare-smt-spec-with-smtlib-file
                 (mini-kernel:make-stage1-env-walk-smt-spec))))
    (is-true (getf report :matchedp))))

(defun test-payload-traversal-search-imported-parity ()
  (let ((report (mini-kernel:compare-smt-spec-with-smtlib-file
                 (mini-kernel:make-payload-traversal-search-smt-spec))))
    (is-true (getf report :matchedp))))

(defun test-g2cl-interlock-closure-imported-parity ()
  (let ((report (mini-kernel:compare-smt-spec-with-smtlib-file
                 (mini-kernel:make-g2cl-interlock-closure-smt-spec))))
    (is-true (getf report :matchedp))))

(defun test-g2imm8-interlock-closure-imported-parity ()
  (let ((report (mini-kernel:compare-smt-spec-with-smtlib-file
                 (mini-kernel:make-g2imm8-interlock-closure-smt-spec))))
    (is-true (getf report :matchedp))))

(defun test-sweep-default-mir-smt-spec-suite ()
  (let ((entries (mini-kernel:sweep-smt-spec-suite
                  (mini-kernel:make-default-mir-smt-spec-suite))))
    (is-equal 6 (length entries))
    (is-true (every (lambda (entry)
                      (zerop (getf (getf entry :summary) :mismatched)))
                    entries))))

(defun test-stage1-heap-commit-core-smt-ir-parity ()
  (let* ((lhs (mini-kernel:smt-spec->core-smt-module
               (mini-kernel:make-stage1-heap-commit-smt-spec)))
         (rhs (mini-kernel:smtlib-file->core-smt-module
               "/home/user0/MIR/formal/smt/Stage1HeapCommit.smt2"))
         (report (mini-kernel:compare-core-smt-modules lhs rhs)))
    (is-true (getf report :same-length-p))
    (is-true (every (lambda (entry)
                      (and (getf entry :label-match-p)
                           (getf entry :query-match-p)))
                    (getf report :entries)))))

(defun test-stage1-control-refinement-core-smt-ir-parity ()
  (let* ((lhs (mini-kernel:smt-spec->core-smt-module
               (mini-kernel:make-stage1-control-refinement-smt-spec)))
         (rhs (mini-kernel:smtlib-file->core-smt-module
               "/home/user0/MIR/formal/smt/Stage1ControlRefinement.smt2"))
         (report (mini-kernel:compare-core-smt-modules lhs rhs)))
    (is-true (getf report :same-length-p))
    (is-true (every (lambda (entry)
                      (and (getf entry :label-match-p)
                           (getf entry :query-match-p)))
                    (getf report :entries)))))

(defun test-stage1-env-walk-core-smt-ir-parity ()
  (let* ((lhs (mini-kernel:smt-spec->core-smt-module
               (mini-kernel:make-stage1-env-walk-smt-spec)))
         (rhs (mini-kernel:smtlib-file->core-smt-module
               "/home/user0/MIR/formal/smt/Stage1EnvWalk.smt2"))
         (report (mini-kernel:compare-core-smt-modules lhs rhs)))
    (is-true (getf report :same-length-p))
    (is-true (every (lambda (entry)
                      (and (getf entry :label-match-p)
                           (getf entry :query-match-p)))
                    (getf report :entries)))))

(defun test-payload-traversal-search-core-smt-ir-parity ()
  (let* ((lhs (mini-kernel:smt-spec->core-smt-module
               (mini-kernel:make-payload-traversal-search-smt-spec)))
         (rhs (mini-kernel:smtlib-file->core-smt-module
               "/home/user0/MIR/formal/smt/payload_traversal_search.smt2"))
         (report (mini-kernel:compare-core-smt-modules lhs rhs))
         (lhs-results (mini-kernel:check-core-smt-module lhs))
         (rhs-results (mini-kernel:check-core-smt-module rhs)))
    (is-true (getf report :same-length-p))
    (is-true (every (lambda (entry)
                      (getf entry :label-match-p))
                    (getf report :entries)))
    (is-equal (mapcar (lambda (entry) (getf entry :actual-status)) lhs-results)
              (mapcar (lambda (entry) (getf entry :actual-status)) rhs-results))))

(defun test-g2cl-interlock-closure-core-smt-ir-parity ()
  (let* ((lhs (mini-kernel:smt-spec->core-smt-module
               (mini-kernel:make-g2cl-interlock-closure-smt-spec)))
         (rhs (mini-kernel:smtlib-file->core-smt-module
               "/home/user0/MIR/formal/smt/G2ClInterlockClosure.smt2"))
         (report (mini-kernel:compare-core-smt-modules lhs rhs))
         (lhs-results (mini-kernel:check-core-smt-module lhs))
         (rhs-results (mini-kernel:check-core-smt-module rhs)))
    (is-true (getf report :same-length-p))
    (is-true (every (lambda (entry)
                      (getf entry :label-match-p))
                    (getf report :entries)))
    (is-equal (mapcar (lambda (entry) (getf entry :actual-status)) lhs-results)
              (mapcar (lambda (entry) (getf entry :actual-status)) rhs-results))))

(defun test-g2imm8-interlock-closure-core-smt-ir-parity ()
  (let* ((lhs (mini-kernel:smt-spec->core-smt-module
               (mini-kernel:make-g2imm8-interlock-closure-smt-spec)))
         (rhs (mini-kernel:smtlib-file->core-smt-module
               "/home/user0/MIR/formal/smt/G2Imm8InterlockClosure.smt2"))
         (report (mini-kernel:compare-core-smt-modules lhs rhs))
         (lhs-results (mini-kernel:check-core-smt-module lhs))
         (rhs-results (mini-kernel:check-core-smt-module rhs)))
    (is-true (getf report :same-length-p))
    (is-true (every (lambda (entry)
                      (getf entry :label-match-p))
                    (getf report :entries)))
    (is-equal (mapcar (lambda (entry) (getf entry :actual-status)) lhs-results)
              (mapcar (lambda (entry) (getf entry :actual-status)) rhs-results))))

(defun test-check-core-smt-module ()
  (let* ((module (mini-kernel:smt-spec->core-smt-module
                  (mini-kernel:make-stage1-env-walk-smt-spec)))
         (results (mini-kernel:check-core-smt-module module)))
    (is-equal 5 (length results))
    (is-true (every (lambda (entry)
                      (eq :rejected (getf entry :actual-status)))
                    results))))

(defun run-tests ()
  (let* ((tests
           (list (cons "compile-smt-obligation" #'test-compile-smt-obligation)
                 (cons "emitted-smt-spec-parity" #'test-emitted-smt-spec-parity)
                 (cons "check-stage1-heap-commit-spec" #'test-check-stage1-heap-commit-spec)
                 (cons "check-stage1-control-refinement-spec" #'test-check-stage1-control-refinement-spec)
                 (cons "check-stage1-env-walk-spec" #'test-check-stage1-env-walk-spec)
                 (cons "check-payload-traversal-search-spec" #'test-check-payload-traversal-search-spec)
                 (cons "check-g2cl-interlock-closure-spec" #'test-check-g2cl-interlock-closure-spec)
                 (cons "check-g2imm8-interlock-closure-spec" #'test-check-g2imm8-interlock-closure-spec)
                 (cons "stage1-heap-commit-imported-parity" #'test-stage1-heap-commit-imported-parity)
                 (cons "stage1-control-refinement-imported-parity" #'test-stage1-control-refinement-imported-parity)
                 (cons "stage1-env-walk-imported-parity" #'test-stage1-env-walk-imported-parity)
                 (cons "payload-traversal-search-imported-parity" #'test-payload-traversal-search-imported-parity)
                 (cons "g2cl-interlock-closure-imported-parity" #'test-g2cl-interlock-closure-imported-parity)
                 (cons "g2imm8-interlock-closure-imported-parity" #'test-g2imm8-interlock-closure-imported-parity)
                 (cons "sweep-default-mir-smt-spec-suite" #'test-sweep-default-mir-smt-spec-suite)
                 (cons "stage1-heap-commit-core-smt-ir-parity" #'test-stage1-heap-commit-core-smt-ir-parity)
                 (cons "stage1-control-refinement-core-smt-ir-parity" #'test-stage1-control-refinement-core-smt-ir-parity)
                 (cons "stage1-env-walk-core-smt-ir-parity" #'test-stage1-env-walk-core-smt-ir-parity)
                 (cons "payload-traversal-search-core-smt-ir-parity" #'test-payload-traversal-search-core-smt-ir-parity)
                 (cons "g2cl-interlock-closure-core-smt-ir-parity" #'test-g2cl-interlock-closure-core-smt-ir-parity)
                 (cons "g2imm8-interlock-closure-core-smt-ir-parity" #'test-g2imm8-interlock-closure-core-smt-ir-parity)
                 (cons "check-core-smt-module" #'test-check-core-smt-module)))
         (passed 0)
         (failed 0))
    (dolist (test tests)
      (if (run-test (car test) (cdr test))
          (incf passed)
          (incf failed)))
    (format t "~%passed: ~D failed: ~D~%" passed failed)
    (when (plusp failed)
      (fail-test "smt spec test suite failed"))
    t))
