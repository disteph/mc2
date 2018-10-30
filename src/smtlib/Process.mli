
(** {1 Process Statements} *)

open Mc2_core
open Solver_types

type 'a or_error = ('a, string) CCResult.t

val conv_bool_term : Service.Registry.t -> Ast.term -> atom list list
(** Convert a boolean term into CNF *)

val process_stmt :
  ?dec_heur:string ->
  ?gc:bool ->
  ?restarts:bool ->
  ?pp_cnf:bool ->
  ?dot_proof:string ->
  ?pp_model:bool ->
  ?check:bool ->
  ?time:float ->
  ?memory:float ->
  ?progress:bool ->
  Solver.t ->
  Ast.statement ->
  unit or_error
(** Process the given statement.
    @raise Incorrect_model if model is not correct
*)
