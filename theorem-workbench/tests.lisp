(in-package :lab.theorem-workbench)

(defun %test-assert (condition control &rest args)
  (unless condition
    (error (apply #'format nil control args))))

(defun run-theorem-workbench-tests ()
  (%test-assert (eq :bounded-witness
                    (topology-status->theorem-status "proved_by_bounded_witness"))
                "Bounded topology witness was promoted too far")
  (%test-assert (eq :bounded-obstruction
                    (topology-status->theorem-status "proved_by_precheck_obstruction"))
                "Bounded topology obstruction mapping failed")
  (let ((target
          (topology-target-row->theorem-target
           '(("id" . "perfect_meeting.uniform_3_1.cross_polygon.exists")
             ("status" . "proved_by_bounded_witness")
             ("witness_schedule_digest" . "witness")
             ("supporting_execution_trace_digest" . "trace")))))
    (register-target target)
    (let ((statement
            (make-theorem-statement
             :id "statement:test"
             :premises '("bounded-search-domain")
             :conclusion (theorem-target-statement target)
             :domain-id :topology))
          (status
            (make-theorem-status
             :target-ref (theorem-target-id target)
             :status (theorem-target-status target)
             :witness-refs '("witness")
             :execution-trace-ref "trace")))
      (%test-assert (typep statement 'theorem-statement)
                    "TheoremStatementV1 carrier missing")
      (%test-assert (eq :bounded-witness (theorem-status-status status))
                    "TheoremStatusV1 carrier lost bounded status"))
    (%test-assert (eq :bounded-witness (theorem-target-status target))
                  "Topology target status mismatch")
    (let ((problem (compile-target target)))
      (%test-assert (typep problem 'lab.math:math-proof-problem)
                    "Topology target did not compile to MathProofProblemV1")))
  t)
