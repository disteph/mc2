(* Copyright 2014 Guillaume Bury *)

module Fsat = struct
  exception Dummy of int

  (* Until the constant true_ and false_ are not needed anymore,
   * wa can't simply use sigend integers to represent literals *)
  type t = int

  let max_lit = max_int
  let max_fresh = ref (-1)
  let max_index = ref 0

  let _make i =
    if i <> 0 && (abs i) < max_lit then begin
      max_index := max !max_index (abs i);
      i
    end else
      (Format.printf "Warning : %d/%d@." i max_lit;
       raise (Dummy i))

  let dummy = 0

  let neg a = - a
  let norm a = abs a, a < 0

  let hash (a:int) = Hashtbl.hash a
  let equal (a:int) b = a=b
  let compare (a:int) b = Pervasives.compare a b

  let _str = Hstring.make ""
  let label a = _str
  let add_label _ _ = ()

  let make i = _make (2 * i)
  let fresh, iter =
    let create () =
      incr max_fresh;
      _make (2 * !max_fresh + 1)
    in
    let iter: (t -> unit) -> unit = fun f ->
      for j = 1 to !max_index do
        f j
      done
    in
    create, iter

  let print fmt a =
    Format.fprintf fmt "%s%s%d"
      (if a < 0 then "~" else "")
      (if a mod 2 = 0 then "v" else "f")
      ((abs a) / 2)

end

module Tseitin = Tseitin.Make(Fsat)

module Stypes = Solver_types.Make(Fsat)

module Exp = Explanation.Make(Stypes)

module Tsat = struct
  (* We don't have anything to do since the SAT Solver already
   * does propagation and conflict detection *)

  type t = unit
  type formula = Fsat.t
  type explanation = Exp.t
  type proof = unit

  exception Inconsistent of explanation

  let dummy = ()
  let empty () = ()
  let assume _ _ _ = ()
end

module Make(Dummy : sig end) = struct
  module SatSolver = Solver.Make(Fsat)(Stypes)(Exp)(Tsat)

  exception Bad_atom

  type atom = Fsat.t
  type clause = Stypes.clause
  type proof = SatSolver.Proof.proof

  type res =
    | Sat
    | Unsat

  let _i = ref 0

  let new_atom () =
    try
      Fsat.fresh ()
    with Fsat.Dummy _ ->
      raise Bad_atom

  let make i =
    try
      Fsat.make i
    with Fsat.Dummy _ ->
      raise Bad_atom

  let neg = Fsat.neg

  let hash = Fsat.hash
  let equal = Fsat.equal
  let compare = Fsat.compare

  let iter_atoms = Fsat.iter

  let solve () =
    try
      SatSolver.solve ();
      Sat
    with SatSolver.Unsat -> Unsat

  let assume l =
    incr _i;
    try
      SatSolver.assume l !_i
    with SatSolver.Unsat -> ()

  let eval = SatSolver.eval

  let get_proof () =
    SatSolver.Proof.learn (SatSolver.history ());
    match SatSolver.unsat_conflict () with
    | None -> assert false
    | Some c -> SatSolver.Proof.prove_unsat c

  let unsat_core = SatSolver.Proof.unsat_core

  let print_atom = Fsat.print
  let print_clause = Stypes.print_clause
  let print_proof = SatSolver.Proof.print_dot

end
