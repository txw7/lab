(in-package :mini-kernel)

(defun %int-var (name)
  (smt-var name (smt-int-sort)))

(defun %bool-var (name)
  (smt-var name (smt-bool-sort)))

(defun %bv-var (name width)
  (smt-var name (smt-bv-sort width)))

(defun make-stage1-heap-commit-smt-spec ()
  (make-smt-spec
   :id :stage1-heap-commit
   :logic :qf_lia
   :source-path "/home/user0/MIR/formal/smt/Stage1HeapCommit.smt2"
   :semantic-tags '(:stage1 :heap :commit :authority)
   :obligations
   (list
    (make-smt-obligation
     :id :overlap-unsat
     :label "overlap_unsat"
     :logic :qf_lia
     :semantic-tags '(:heap :allocation :non-overlap)
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list (smt-int-le (smt-int-lit 56) (%int-var 'alloc0))
           (smt-int-le (smt-int-lit 1) (%int-var 'n0))
           (smt-int-le (smt-int-lit 1) (%int-var 'n1))
           (smt-int-le
            (smt-int-add (%int-var 'alloc0) (%int-var 'n0) (%int-var 'n1))
            (smt-int-lit 160)))
     :goal
     (smt-int-lt
      (smt-int-add (%int-var 'alloc0) (%int-var 'n0))
      (smt-int-add (%int-var 'alloc0) (%int-var 'n0))))
    (make-smt-obligation
     :id :commit-monotone-unsat
     :label "commit_monotone_unsat"
     :logic :qf_lia
     :semantic-tags '(:heap :commit :monotone)
     :polarity :prove-unsat
     :expected-status :unknown
     :unknown-policy :tolerated
     :assumptions
     (list (smt-int-le (smt-int-lit 56) (%int-var 'commit0))
           (smt-int-le (%int-var 'commit0) (smt-int-lit 160))
           (smt-int-le (smt-int-lit 56) (%int-var 'fragStart))
           (smt-int-le (smt-int-lit 1) (%int-var 'fragSize))
           (smt-int-le
            (smt-int-add (%int-var 'fragStart) (%int-var 'fragSize))
            (smt-int-lit 160))
           (smt-eq (%int-var 'commit1)
                   (smt-ite (smt-int-lt (%int-var 'commit0)
                                         (smt-int-add (%int-var 'fragStart)
                                                      (%int-var 'fragSize)))
                            (smt-int-add (%int-var 'fragStart) (%int-var 'fragSize))
                            (%int-var 'commit0))))
     :goal
     (smt-int-lt (%int-var 'commit1) (%int-var 'commit0)))
    (make-smt-obligation
     :id :exec-requires-commit-unsat
     :label "exec_requires_commit_unsat"
     :logic :qf_lia
     :semantic-tags '(:stage1 :authority :commit-gate)
     :polarity :prove-unsat
     :expected-status :unknown
     :unknown-policy :tolerated
     :assumptions
     (list
      (smt-eq (%bool-var 'execAdmitted)
              (smt-and (smt-eq (%int-var 'fragState) (smt-int-lit 3))
                       (%bool-var 'authorityInstalled)))
      (smt-not (smt-eq (%int-var 'fragState) (smt-int-lit 3))))
     :goal
     (%bool-var 'execAdmitted))
    (make-smt-obligation
     :id :exec-requires-authority-unsat
     :label "exec_requires_authority_unsat"
     :logic :qf_lia
     :semantic-tags '(:stage1 :authority :install-gate)
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list
      (smt-eq (%bool-var 'execAdmitted2)
              (smt-and (smt-eq (%int-var 'fragState2) (smt-int-lit 3))
                       (%bool-var 'authorityInstalled2)))
      (smt-eq (%int-var 'fragState2) (smt-int-lit 3))
      (smt-not (%bool-var 'authorityInstalled2)))
     :goal
     (%bool-var 'execAdmitted2))
    (make-smt-obligation
     :id :fragment-within-heap-unsat
     :label "fragment_within_heap_unsat"
     :logic :qf_lia
     :semantic-tags '(:heap :fragment :bounds)
     :polarity :prove-unsat
     :expected-status :unknown
     :unknown-policy :tolerated
     :assumptions
     (list (smt-int-le (smt-int-lit 56) (%int-var 'fragStart3))
           (smt-int-le (smt-int-lit 1) (%int-var 'fragSize3))
           (smt-int-le
            (smt-int-add (%int-var 'fragStart3) (%int-var 'fragSize3))
            (smt-int-lit 160)))
     :goal
     (smt-int-gt
      (smt-int-add (%int-var 'fragStart3) (%int-var 'fragSize3))
      (smt-int-lit 160))))))

(defun make-stage1-control-refinement-smt-spec ()
  (make-smt-spec
   :id :stage1-control-refinement
   :logic :qf_lia
   :source-path "/home/user0/MIR/formal/smt/Stage1ControlRefinement.smt2"
   :semantic-tags '(:stage1 :control :dispatch)
   :obligations
   (list
    (make-smt-obligation
     :id :dispatch-quote-refines-unsat
     :label "dispatch_quote_refines_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions (list (smt-eq (%int-var 'quoteHandler) (smt-int-lit 1)))
     :goal (smt-not (smt-eq (%int-var 'quoteHandler) (smt-int-lit 1))))
    (make-smt-obligation
     :id :dispatch-gen-select-refines-unsat
     :label "dispatch_gen_select_refines_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions (list (smt-eq (%int-var 'genSelectHandler) (smt-int-lit 34)))
     :goal (smt-not (smt-eq (%int-var 'genSelectHandler) (smt-int-lit 34))))
    (make-smt-obligation
     :id :control-loopback-refines-unsat
     :label "control_loopback_refines_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list (smt-eq (%int-var 'realizeReadyTarget) (smt-int-lit 1))
           (smt-eq (%int-var 'execReadyTarget) (smt-int-lit 1))
           (smt-eq (%int-var 'genSelectReadyTarget) (smt-int-lit 1))
           (smt-eq (%int-var 'genSpliceDoneTarget) (smt-int-lit 1)))
     :goal
     (smt-or (smt-not (smt-eq (%int-var 'realizeReadyTarget) (smt-int-lit 1)))
             (smt-not (smt-eq (%int-var 'execReadyTarget) (smt-int-lit 1)))
             (smt-not (smt-eq (%int-var 'genSelectReadyTarget) (smt-int-lit 1)))
             (smt-not (smt-eq (%int-var 'genSpliceDoneTarget) (smt-int-lit 1)))))
    (make-smt-obligation
     :id :dispatch-unknown-tag-rejected-unsat
     :label "dispatch_unknown_tag_rejected_unsat"
     :polarity :prove-unsat
     :expected-status :unknown
     :unknown-policy :tolerated
     :assumptions
     (list
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 1)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 3)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 4)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 7)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 8)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 5)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 6)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 32)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 33)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 34)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 35)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 48)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 49)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 50)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 51)))
      (smt-not (smt-eq (%int-var 'unknownTag) (smt-int-lit 96))))
     :goal
     (smt-or (smt-eq (%int-var 'unknownTag) (smt-int-lit 1))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 3))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 4))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 7))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 8))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 5))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 6))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 32))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 33))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 34))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 35))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 48))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 49))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 50))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 51))
             (smt-eq (%int-var 'unknownTag) (smt-int-lit 96)))))))

(defun make-stage1-env-walk-smt-spec ()
  (make-smt-spec
   :id :stage1-env-walk
   :logic :qf_lia
   :source-path "/home/user0/MIR/formal/smt/Stage1EnvWalk.smt2"
   :semantic-tags '(:stage1 :env :lookup)
   :obligations
   (list
    (make-smt-obligation
     :id :bind-prepends-empty-env-unsat
     :label "bind_prepends_empty_env_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list (smt-eq (%int-var 'oldHead) (smt-int-lit 8))
           (smt-eq (%int-var 'slot0) (smt-int-lit 0))
           (smt-eq (%int-var 'newHead) (%int-var 'slot0)))
     :goal
     (smt-not (smt-eq (%int-var 'newHead) (%int-var 'slot0))))
    (make-smt-obligation
     :id :bind-shadow-chain-unsat
     :label "bind_shadow_chain_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list (smt-eq (%int-var 'head0) (smt-int-lit 0))
           (smt-eq (%int-var 'slot1) (smt-int-lit 1))
           (smt-eq (%int-var 'newHead1) (%int-var 'slot1))
           (smt-eq (%int-var 'next1) (%int-var 'head0)))
     :goal
     (smt-or (smt-not (smt-eq (%int-var 'newHead1) (%int-var 'slot1)))
             (smt-not (smt-eq (%int-var 'next1) (%int-var 'head0)))))
    (make-smt-obligation
     :id :lookup-returns-newest-unsat
     :label "lookup_returns_newest_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list (smt-not (smt-eq (%int-var 'newestValue) (%int-var 'olderValue)))
           (smt-eq (%int-var 'lookupResult) (%int-var 'newestValue))
           (smt-eq (%int-var 'lookupResult) (%int-var 'olderValue)))
     :goal
     (smt-bool-const t))
    (make-smt-obligation
     :id :env-next-free-monotone-unsat
     :label "env_next_free_monotone_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list (smt-eq (%int-var 'nextFree1)
                   (smt-int-add (%int-var 'nextFree0) (smt-int-lit 1))))
     :goal
     (smt-int-lt (%int-var 'nextFree1) (%int-var 'nextFree0)))
    (make-smt-obligation
     :id :lookup-head-match-terminates-unsat
     :label "lookup_head_match_terminates_unsat"
     :polarity :prove-unsat
     :expected-status :rejected
     :assumptions
     (list (smt-eq (%int-var 'head) (smt-int-lit 1))
           (smt-eq (%int-var 'headSym) (%int-var 'target)))
     :goal
     (smt-not (smt-eq (%int-var 'headSym) (%int-var 'target)))))))

(defun make-payload-traversal-search-smt-spec ()
  (labels ((bv (width value)
             (smt-bv-lit width value))
           (v (name width)
             (%bv-var name width))
           (eqv (name width value)
             (smt-eq (v name width) (bv width value)))
           (sel-ok (term)
             (smt-or (smt-eq term (bv 3 0))
                     (smt-eq term (bv 3 1))
                     (smt-eq term (bv 3 2))
                     (smt-eq term (bv 3 3))
                     (smt-eq term (bv 3 4))
                     (smt-eq term (bv 3 5))
                     (smt-eq term (bv 3 7))))
           (phase-ok (term)
             (smt-or (smt-eq term (bv 3 0))
                     (smt-eq term (bv 3 1))
                     (smt-eq term (bv 3 2))
                     (smt-eq term (bv 3 3))
                     (smt-eq term (bv 3 4))
                     (smt-eq term (bv 3 5))
                     (smt-eq term (bv 3 6))))
           (b2i1 (bool-term)
             (smt-ite bool-term (bv 4 1) (bv 4 0)))
           (moved (lhs rhs)
             (smt-not (smt-eq lhs rhs)))
           (move-count ()
             (smt-bvadd
              (b2i1 (moved (v 's0 8) (v 's1 8)))
              (smt-bvadd
               (b2i1 (smt-or (moved (v 'br0 3) (v 'br1 3))
                             (moved (v 'tr0 3) (v 'tr1 3))))
               (smt-bvadd
                (b2i1 (smt-or (moved (v 'q0 1) (v 'q1 1))
                              (moved (v 'w0 1) (v 'w1 1))
                              (moved (v 'c0 1) (v 'c1 1))))
                (b2i1 (moved (v 'p0 3) (v 'p1 3))))))))
    (make-smt-spec
     :id :payload-traversal-search
     :logic :qf_bv
     :source-path "/home/user0/MIR/formal/smt/payload_traversal_search.smt2"
     :semantic-tags '(:mir :payload :traversal :search :bitvector)
     :obligations
     (list
      (make-smt-obligation
       :id :payload-traversal-search-sat
       :label nil
       :logic :qf_bv
       :semantic-tags '(:payload :single-step :search)
       :polarity :find-sat
       :expected-status :accepted
       :assumptions
       (list
        (eqv 's0 8 #x01)
        (eqv 'bo0 8 #x81)
        (eqv 'br0 3 #b100)
        (eqv 'to0 8 #xD1)
        (eqv 'tr0 3 #b100)
        (eqv 'q0 1 #b0)
        (eqv 'w0 1 #b0)
        (eqv 'c0 1 #b0)
        (eqv 'p0 3 #b000)
        (eqv 'a0 16 #xD104)
        (smt-or (eqv 's1 8 #x01)
                (eqv 's1 8 #x03)
                (eqv 's1 8 #x11)
                (eqv 's1 8 #x13)
                (eqv 's1 8 #x19)
                (eqv 's1 8 #x1B)
                (eqv 's1 8 #x39)
                (eqv 's1 8 #x3B))
        (eqv 'bo1 8 #x81)
        (eqv 'to1 8 #xD1)
        (sel-ok (v 'br1 3))
        (sel-ok (v 'tr1 3))
        (phase-ok (v 'p1 3))
        (smt-eq (v 'br1 3) (v 'tr1 3))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 0))
                     (smt-eq (v 'a1 16) (bv 16 #xD100)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 1))
                     (smt-eq (v 'a1 16) (bv 16 #xD101)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 2))
                     (smt-eq (v 'a1 16) (bv 16 #xD102)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 3))
                     (smt-eq (v 'a1 16) (bv 16 #xD103)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 4))
                     (smt-eq (v 'a1 16) (bv 16 #xD104)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 5))
                     (smt-eq (v 'a1 16) (bv 16 #xD105)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 7))
                     (smt-eq (v 'a1 16) (bv 16 #xD107)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 0))
                     (eqv 'w1 1 #b1))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 1))
                     (eqv 'w1 1 #b1))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 2))
                     (eqv 'c1 1 #b1))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 3))
                     (eqv 'c1 1 #b1))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 4))
                     (smt-and (eqv 'q1 1 #b0)
                              (eqv 'w1 1 #b0)
                              (eqv 'c1 1 #b0)))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 5))
                     (eqv 'q1 1 #b1))
        (smt-implies (smt-eq (v 'tr1 3) (bv 3 7))
                     (eqv 'q1 1 #b1))
        (smt-or (moved (v 's0 8) (v 's1 8))
                (moved (v 'br0 3) (v 'br1 3))
                (moved (v 'tr0 3) (v 'tr1 3))
                (moved (v 'q0 1) (v 'q1 1))
                (moved (v 'w0 1) (v 'w1 1))
                (moved (v 'c0 1) (v 'c1 1))
                (moved (v 'p0 3) (v 'p1 3))
                (moved (v 'a0 16) (v 'a1 16)))
        (smt-or (smt-eq (move-count) (bv 4 2))
                (smt-ult (move-count) (bv 4 2)))))))))

(defun make-g2cl-interlock-closure-smt-spec ()
  (labels ((bv (width value)
             (smt-bv-lit width value))
           (v (name width)
             (%bv-var name width))
           (eqv (name width value)
             (smt-eq (v name width) (bv width value)))
           (src-ok (term values)
             (apply #'smt-or
                    (mapcar (lambda (value)
                              (smt-eq term (bv 8 value)))
                            values)))
           (zero-extend (term amount)
             (if (zerop amount)
                 term
                 (smt-concat (bv amount 0) term)))
           (exec-addr (op sel)
             (smt-bvor (smt-concat op (bv 8 0))
                       (zero-extend sel 13)))
           (make-case (index prefix src-values g1sel g2sel addr)
             (let ((src (intern (format nil "SRC_~D" index) :mini-kernel))
                   (g1op (intern (format nil "G1OP_~D" index) :mini-kernel))
                   (g1sel-name (intern (format nil "G1SEL_~D" index) :mini-kernel))
                   (g2op (intern (format nil "G2OP_~D" index) :mini-kernel))
                   (g2sel-name (intern (format nil "G2SEL_~D" index) :mini-kernel))
                   (addr-name (intern (format nil "ADDR_~D" index) :mini-kernel)))
               (flet ((base-assumptions ()
                        (list (src-ok (v src 8) src-values)
                              (eqv g1op 8 #x81)
                              (eqv g1sel-name 3 g1sel)
                              (eqv g2op 8 #xD3)
                              (eqv g2sel-name 3 g2sel)
                              (smt-eq (v addr-name 16)
                                      (exec-addr (v g2op 8) (v g2sel-name 3)))
                              (eqv addr-name 16 addr))))
                 (list
                  (make-smt-obligation
                   :id (intern (format nil "~A-SAT" prefix) :keyword)
                   :label (format nil "~A_sat" prefix)
                   :logic :qf_bv
                   :polarity :find-sat
                   :expected-status :accepted
                   :semantic-tags '(:mir :g2cl :closure :runtime)
                   :assumptions (base-assumptions))
                  (make-smt-obligation
                   :id (intern (format nil "~A-RESOLUTION-ESCAPE-UNSAT" prefix) :keyword)
                   :label (format nil "~A_resolution_escape_unsat" prefix)
                   :logic :qf_bv
                   :polarity :prove-unsat
                   :expected-status :rejected
                   :semantic-tags '(:mir :g2cl :closure :resolution)
                   :assumptions (base-assumptions)
                   :goal (smt-not (eqv addr-name 16 addr)))
                  (make-smt-obligation
                   :id (intern (format nil "~A-PROJECTION-INCOHERENCE-UNSAT" prefix) :keyword)
                   :label (format nil "~A_projection_incoherence_unsat" prefix)
                   :logic :qf_bv
                   :polarity :prove-unsat
                   :expected-status :rejected
                   :semantic-tags '(:mir :g2cl :closure :projection)
                   :assumptions (base-assumptions)
                   :goal (smt-or (smt-not (eqv g2op 8 #xD3))
                                 (smt-not (eqv g2sel-name 3 g2sel)))))))))
    (make-smt-spec
     :id :g2cl-interlock-closure
     :logic :qf_bv
     :source-path "/home/user0/MIR/formal/smt/G2ClInterlockClosure.smt2"
     :semantic-tags '(:mir :g2cl :closure :interlock :bitvector)
     :obligations
     (append
      (make-case 0 "k18_rol_cl_runtime" '(#x01 #x03) #b000 #b000 #xD300)
      (make-case 1 "k18_ror_cl_runtime" '(#x01 #x03) #b001 #b001 #xD301)
      (make-case 2 "k18_rcl_cl_runtime" '(#x11 #x13 #x19 #x1B) #b010 #b010 #xD302)
      (make-case 3 "k18_rcr_cl_runtime" '(#x11 #x13 #x19 #x1B) #b011 #b011 #xD303)
      (make-case 4 "k18_shl_cl_runtime" '(#x01 #x03) #b100 #b100 #xD304)
      (make-case 5 "k18_shr_cl_runtime" '(#x01 #x03) #b101 #b101 #xD305)
      (make-case 6 "k18_sar_cl_runtime" '(#x01 #x03 #x39 #x3B) #b111 #b111 #xD307)))))

(defun make-g2imm8-interlock-closure-smt-spec ()
  (labels ((bv (width value)
             (smt-bv-lit width value))
           (v (name width)
             (%bv-var name width))
           (eqv (name width value)
             (smt-eq (v name width) (bv width value)))
           (src-ok (term values)
             (apply #'smt-or
                    (mapcar (lambda (value)
                              (smt-eq term (bv 8 value)))
                            values)))
           (zero-extend (term amount)
             (if (zerop amount)
                 term
                 (smt-concat (bv amount 0) term)))
           (exec-addr (op sel)
             (smt-bvor (smt-concat op (bv 8 0))
                       (zero-extend sel 13)))
           (make-case (index prefix src-values g1sel g2sel addr)
             (let ((src (intern (format nil "SRC_~D" index) :mini-kernel))
                   (g1op (intern (format nil "G1OP_~D" index) :mini-kernel))
                   (g1sel-name (intern (format nil "G1SEL_~D" index) :mini-kernel))
                   (g2op (intern (format nil "G2OP_~D" index) :mini-kernel))
                   (g2sel-name (intern (format nil "G2SEL_~D" index) :mini-kernel))
                   (addr-name (intern (format nil "ADDR_~D" index) :mini-kernel)))
               (flet ((base-assumptions ()
                        (list (src-ok (v src 8) src-values)
                              (eqv g1op 8 #x81)
                              (eqv g1sel-name 3 g1sel)
                              (eqv g2op 8 #xC1)
                              (eqv g2sel-name 3 g2sel)
                              (smt-eq (v addr-name 16)
                                      (exec-addr (v g2op 8) (v g2sel-name 3)))
                              (eqv addr-name 16 addr))))
                 (list
                  (make-smt-obligation
                   :id (intern (format nil "~A-SAT" prefix) :keyword)
                   :label (format nil "~A_sat" prefix)
                   :logic :qf_bv
                   :polarity :find-sat
                   :expected-status :accepted
                   :semantic-tags '(:mir :g2imm8 :closure :runtime)
                   :assumptions (base-assumptions))
                  (make-smt-obligation
                   :id (intern (format nil "~A-RESOLUTION-ESCAPE-UNSAT" prefix) :keyword)
                   :label (format nil "~A_resolution_escape_unsat" prefix)
                   :logic :qf_bv
                   :polarity :prove-unsat
                   :expected-status :rejected
                   :semantic-tags '(:mir :g2imm8 :closure :resolution)
                   :assumptions (base-assumptions)
                   :goal (smt-not (eqv addr-name 16 addr)))
                  (make-smt-obligation
                   :id (intern (format nil "~A-PROJECTION-INCOHERENCE-UNSAT" prefix) :keyword)
                   :label (format nil "~A_projection_incoherence_unsat" prefix)
                   :logic :qf_bv
                   :polarity :prove-unsat
                   :expected-status :rejected
                   :semantic-tags '(:mir :g2imm8 :closure :projection)
                   :assumptions (base-assumptions)
                   :goal (smt-or (smt-not (eqv g2op 8 #xC1))
                                 (smt-not (eqv g2sel-name 3 g2sel)))))))))
    (make-smt-spec
     :id :g2imm8-interlock-closure
     :logic :qf_bv
     :source-path "/home/user0/MIR/formal/smt/G2Imm8InterlockClosure.smt2"
     :semantic-tags '(:mir :g2imm8 :closure :interlock :bitvector)
     :obligations
     (append
      (make-case 0 "k18_rol_imm8_runtime" '(#x01 #x03) #b000 #b000 #xC100)
      (make-case 1 "k18_ror_imm8_runtime" '(#x01 #x03) #b001 #b001 #xC101)
      (make-case 2 "k18_rcl_imm8_runtime" '(#x11 #x13 #x19 #x1B) #b010 #b010 #xC102)
      (make-case 3 "k18_rcr_imm8_runtime" '(#x11 #x13 #x19 #x1B) #b011 #b011 #xC103)
      (make-case 4 "k18_shl_imm8_runtime" '(#x01 #x03) #b100 #b100 #xC104)
      (make-case 5 "k18_shr_imm8_runtime" '(#x01 #x03) #b101 #b101 #xC105)
      (make-case 6 "k18_sar_imm8_runtime" '(#x01 #x03 #x39 #x3B) #b111 #b111 #xC107)))))

(defun make-default-mir-smt-spec-suite ()
  (list (make-stage1-heap-commit-smt-spec)
        (make-stage1-control-refinement-smt-spec)
        (make-stage1-env-walk-smt-spec)
        (make-payload-traversal-search-smt-spec)
        (make-g2cl-interlock-closure-smt-spec)
        (make-g2imm8-interlock-closure-smt-spec)))
