
open Solver_types
module Fmt = CCFormat

let name = "builtins"
let k_true = Service.Key.make "builtins.true"

type term_view += True

type lemma_view += L_tautology

let[@inline] is_t_true (t:term) = match Term.view t with
  | True -> true
  | _ -> false

let tcl =
  let tcl_pp out = function
    | L_tautology -> Fmt.string out "true_is_true"
    | _ -> assert false
  in
  {tcl_pp}

let lemma_true_is_true : lemma = Lemma.make L_tautology tcl

let build p_id Plugin.S_nil : Plugin.t =
  let module P = struct
    let id = p_id
    let name = name

    let pp out = function
      | True -> Fmt.string out "true"
      | _ -> assert false

    (* self-watch *)
    let init_watches _ t = Term.add_watch t t

    (* check that [t_true] is only ever assigned to [true] *)
    let update_watches acts t =
      assert (is_t_true t);
      if Term.Bool.is_false t then (
        assert (Term.Bool.is_false t);
        (* conflict clause: [true] *)
        Actions.raise_conflict acts [Term.Bool.pa t] lemma_true_is_true
      );
      Watch_kept

    let eval_bool (t:term) : eval_bool_res =
      assert (is_t_true t);
      Eval_bool (true, [])

    let tc : tc_term = Term.tc_mk ~eval_bool ~init_watches ~update_watches ~pp ()

    (* the main "true" term *)
    let t_true : term = Term.Unsafe.make_term p_id True Type.bool tc

    let iter_terms yield = yield t_true
    let gc_all ()=()
    let check_if_sat _ = Sat

    let provided_services = [
      Service.Any (k_true, t_true)
    ]
  end in
  (module P)

let plugin =
  Plugin.Factory.make ~priority:0 ~name ~requires:Plugin.K_nil ~build ()

