(in-package :mini-kernel)

(defun %external-status (okp)
  (if okp :accepted :rejected))

(defun ingest-lsip-closure-report (path)
  (let* ((payload (read-json-file path))
         (status (json-object-get payload "status"))
         (gates (json-object-get payload "gates"))
         (passedp (and (string= status "passed")
                       (every (lambda (gate)
                                (string= (json-object-get gate "status") "passed"))
                              gates)))
         (summary (list :status status
                        :gate-count (length gates)
                        :all-gates-passed passedp)))
    (make-external-report-bundle
     :artifact-id :lsip-closure-report
     :source-path path
     :source-payload payload
     :report-kind :lsip-closure-report
     :summary summary
     :status (%external-status passedp)
     :trace-ref '(:external lsip :report closure-stack))))

(defun %mir-result-ok-p (result)
  (cond
    ((assoc "ok" result :test #'string=)
     (json-object-get result "ok"))
    ((assoc "matches_expected_trace" result :test #'string=)
     (and (json-object-get result "matches_expected_trace")
          (json-object-get result "inferior_exited_normally")))
    (t t)))

(defun ingest-mir-report (path &key artifact-id)
  (let* ((payload (read-json-file path))
         (status (json-object-get payload "status"))
         (errors (json-object-get payload "errors"))
         (results (or (json-object-get payload "results") '()))
         (okp (and (member status '("ok" "passed") :test #'string=)
                   (null errors)
                   (every #'%mir-result-ok-p results)))
         (summary (list :status status
                        :error-count (length errors)
                        :result-count (length results)
                        :all-results-ok okp)))
    (make-external-report-bundle
     :artifact-id (or artifact-id (pathname-name path))
     :source-path path
     :source-payload payload
     :report-kind :mir-report
     :summary summary
     :status (%external-status okp)
     :trace-ref '(:external mir :report witness))))
