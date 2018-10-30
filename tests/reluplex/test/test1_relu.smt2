(set-logic QF_LRA)

;; Declare the neuron variables
(declare-fun n_0_0 () Real)
(declare-fun n_1_0 () Real)
(declare-fun n_1_1 () Real)
(declare-fun n_1_2 () Real)
(declare-fun n_1_3 () Real)
(declare-fun n_2_0 () Real)
(declare-fun n_2_1 () Real)
(declare-fun n_2_2 () Real)
(declare-fun n_2_3 () Real)
(declare-fun n_3_0 () Real)

;; Bound input ranges

(assert (>= n_0_0 0))
(assert (<= n_0_0 1))

;; Declare the transition rules between neurons

;; Layer 1
(assert (let ((ws (+ (* n_0_0 0.814629) (- 0.928665)))) (relu ws n_1_0)))
(assert (let ((ws (+ (* n_0_0 (- 0.644192)) (- 0.790396)))) (relu ws n_1_1)))
(assert (let ((ws (+ (* n_0_0 (- 8.837580)) 5.513113))) (relu ws n_1_2)))
(assert (let ((ws (+ (* n_0_0 1.977343) 2.129500))) (relu ws n_1_3)))
;; Layer 2
(assert (let ((ws (+ (* n_1_0 (- 0.518243)) (* n_1_1 0.075994) (* n_1_2 1.650490) (* n_1_3 0.405225) 0.159764))) (relu ws n_2_0)))
(assert (let ((ws (+ (* n_1_0 (- 0.185456)) (* n_1_1 (- 0.551956)) (* n_1_2 (- 0.757700)) (* n_1_3 (- 0.243674)) (- 0.295062)))) (relu ws n_2_1)))
(assert (let ((ws (+ (* n_1_0 0.471567) (* n_1_1 (- 0.695298)) (* n_1_2 (- 0.258886)) (* n_1_3 0.161991) 3.254056))) (relu ws n_2_2)))
(assert (let ((ws (+ (* n_1_0 (- 0.033370)) (* n_1_1 (- 0.534986)) (* n_1_2 7.933851) (* n_1_3 1.254769) (- 2.058532)))) (relu ws n_2_3)))
;; Layer 3
(assert (let ((ws (+ (* n_2_0 4.034788) (* n_2_1 (- 0.438811)) (* n_2_2 (- 1.041344)) (* n_2_3 2.172554) (- 5.027282)))) (= n_3_0 ws)))

;; Goal

(assert (> n_3_0 0))
(assert (< n_3_0 1))

(check-sat)

