(set-logic QF_BV)

(define-fun exec_addr ((op (_ BitVec 8)) (sel (_ BitVec 3))) (_ BitVec 16)
  (bvor (bvshl ((_ zero_extend 8) op) #x0008) ((_ zero_extend 13) sel)))

(declare-const op (_ BitVec 8))
(declare-const sel (_ BitVec 3))
(declare-const addr (_ BitVec 16))

(assert (= op #xC1))
(assert (= sel #b110))
(assert (= addr (exec_addr op sel)))

(push)
(assert (= addr #xC106))
(echo "novel_exec_addr_c1_slot6_sat")
(check-sat)
(pop)

(push)
(assert (not (= addr #xC106)))
(echo "novel_exec_addr_c1_slot6_unsat")
(check-sat)
(pop)
