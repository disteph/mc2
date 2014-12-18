(**************************************************************************)
(*                                                                        *)
(*                                  Cubicle                               *)
(*             Combining model checking algorithms and SMT solvers        *)
(*                                                                        *)
(*                  Sylvain Conchon, Evelyne Contejean                    *)
(*                  Francois Bobot, Mohamed Iguernelala, Alain Mebsout    *)
(*                  CNRS, Universite Paris-Sud 11                         *)
(*                                                                        *)
(*  Copyright 2011. This file is distributed under the terms of the       *)
(*  Apache Software License version 2.0                                   *)
(*                                                                        *)
(**************************************************************************)

module type S = sig
  (** Singature for theories to be given to the Solver. *)

  type formula
  (** The type of formulas. Should be compatble with Formula_intf.S *)

  type proof
  (** A custom type for the proofs of lemmas produced by the theory. *)

  type slice = {
    start : int;
    length : int;
    get : int -> formula;
    push : formula list -> proof -> unit;
  }
  (** The type for a slice of litterals to assume/propagate in the theory.
      [get] operations should only be used for integers [ start <= i < start + length].
      [push clause proof] allows to add a tautological clause to the sat solver. *)

  type level
  (** The type for levels to allow backtracking. *)

  (** Type returned by the theory, either the current set of assumptions is satisfiable,
      or it is not, in which case a tautological clause (hopefully minimal) is returned.
      Formulas in the unsat clause must come from the current set of assumptions, i.e
      must have been encountered in a slice. *)
  type res =
    | Sat of level
    | Unsat of formula list * proof

  val dummy : level
  (** A dummy level. *)

  val current_level : unit -> level
  (** Return the current level of the theory (either the empty/beginning state, or the
      last level returned by the [assume] function). *)

  val assume : slice -> res
  (** Assume the formulas in the slice, possibly pushing new formulas to be propagated,
      and returns the result of the new assumptions. *)

  val backtrack : level -> unit
  (** Backtrack to the given level. After a call to [backtrack l], the theory should be in the
      same state as when it returned the value [l], *)

end
