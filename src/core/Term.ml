
(** {1 Modular Term Structure} *)

open Solver_types

module Fields = Term_fields

type view = term_view = ..
type t = term
type tc = tc_term

let[@inline] id t = t.t_id
let[@inline] view t = t.t_view
let[@inline] equal t u = t.t_id = u.t_id
let[@inline] compare t u = CCInt.compare t.t_id u.t_id
let[@inline] hash t = CCHash.int t.t_id
let[@inline] pp out (t:t): unit = t.t_tc.tct_pp out t.t_view
let[@inline] field_get f t = Fields.get f t.t_fields
let[@inline] field_set f t = t.t_fields <- Fields.set f true t.t_fields
let[@inline] field_clear f t = t.t_fields <- Fields.set f false t.t_fields

(* store plugin id at 4 lowest bits *)
let plugin_id_width = 4

(* bitmask *)
let p_mask = (1 lsl plugin_id_width) - 1

let[@inline] plugin_id t : int = id t land p_mask
let[@inline] plugin_specific_id t : int = id t lsr plugin_id_width
let[@inline] weight t = t.t_weight
let[@inline] set_weight t f = t.t_weight <- f
let[@inline] level t = t.t_level
let[@inline] is_deleted t = field_get field_t_is_deleted t
let[@inline] is_added t = field_get field_t_is_added t
let[@inline] var t = t.t_var
let[@inline] ty t = t.t_ty
let[@inline] iter_subterms (t:term): term Sequence.t = t.t_tc.tct_subterms t.t_view
let[@inline] is_bool t = Type.is_bool t.t_ty

let[@inline] gc_marked (t:t) : bool = field_get field_t_gc_marked t
let[@inline] gc_unmark (t:t) : unit = field_clear field_t_gc_marked t
let[@inline] gc_mark (t:t) : unit = field_set field_t_gc_marked t

let[@inline] dirty (t:t): bool = field_get field_t_dirty t
let[@inline] dirty_unmark (t:t) : unit = field_clear field_t_dirty t
let[@inline] dirty_mark (t:t) : unit = field_set field_t_dirty t

let[@inline] value (t:t): term_assignment = t.t_value
let[@inline] value_exn (t:t): value = match t.t_value with
  | TA_none -> assert false
  | TA_assign {value;_} -> value
let[@inline] has_value (t:t): bool = match t.t_value with
  | TA_none -> false
  | TA_assign _ -> true

let[@inline] mk_eq (t:t) (u:t) : t = Type.mk_eq (ty t) t u

let rec gc_mark_rec (t:t) : unit =
  if not (gc_marked t) then (
    gc_mark t;
    iter_subterms t gc_mark_rec
  )

let[@inline] reason t = match value t with
  | TA_none -> None
  | TA_assign{reason;_} -> Some reason

let[@inline] recompute_state (lvl:level) (t:t) : unit =
  t.t_tc.tct_refresh_state lvl t

(** {2 Assignment view} *)

let[@inline] assigned (t:term): bool = match t.t_value with
  | TA_none -> false
  | TA_assign _ -> true

let[@inline] assignment (t:term) = match value t with
  | TA_assign {value=V_true;_} -> Some (A_bool (t,true))
  | TA_assign {value=V_false;_} -> Some (A_bool (t,false))
  | TA_assign {value;_} -> Some (A_semantic (t,value))
  | TA_none -> None

(** {2 Low Level constructors. Use at your own risks.} *)
module Unsafe = struct
  let max_plugin_id = (1 lsl plugin_id_width) - 1

  let[@inline] mk_plugin_id (id:int): plugin_id =
    if id > max_plugin_id then (
      failwith "add_plugin: too many plugins";
    );
    id

  (* build a fresh term *)
  let[@inline never] make_term t_id t_view t_ty t_tc : t =
    let t_fields = Fields.empty in
    let t_level = -1 in
    let t_weight = 0. in
    let t_idx = ~-1 in
    let t_watches = lazy (Vec.make_empty dummy_term) in
    { t_id; t_view; t_ty; t_fields; t_level; t_weight; t_idx;
      t_var=Var_none; t_value=TA_none; t_watches; t_tc; }
end

(* make a fresh variable for this term *)
let mk_var_ (t:t): var =
  if Type.is_bool t.t_ty then (
    let t_id_double = t.t_id lsl 1 in
    let pa = {
      a_term=t;
      a_watched = Vec.make 10 dummy_clause;
      a_id = t_id_double; (* aid = vid*2 *)
    } and na = {
        a_term=t;
        a_watched = Vec.make 10 dummy_clause;
        a_id = t_id_double + 1; (* aid = vid*2+1 *)
      } in
    Var_bool {pa; na}
  ) else (
    Var_semantic {
      v_decide_state=Type.mk_decide_state t.t_ty;
    }
  )

let[@inline] has_var t = match t.t_var with
  | Var_none -> false
  | Var_bool _
  | Var_semantic _ -> true

let[@inline] setup_var t =
  if not (has_var t) then (
    let v = mk_var_ t in
    t.t_var <- v;
    assert (has_var t);
  )

let[@inline] iter_watches (t:t) f : unit =
  let lazy vec = t.t_watches in
  Vec.iter f vec

let[@inline] add_watch (t:t) (u:t) : unit =
  let lazy vec = t.t_watches in
  Vec.push vec u

let tc_mk
    ?(init_watches=fun _ _ -> ())
    ?(update_watches=fun _ _ -> ())
    ?(subterms=fun _ _ -> ())
    ?(refresh_state=fun _ _ -> ())
    ?(eval_bool=fun _ -> Eval_unknown)
    ~pp
    () : tc =
  { tct_init_watches=init_watches;
    tct_update_watches=update_watches;
    tct_refresh_state=refresh_state;
    tct_subterms=subterms;
    tct_pp=pp;
    tct_eval_bool=eval_bool;
  }

let marked t = Term_fields.get field_t_seen t.t_fields
let mark t = t.t_fields <- Term_fields.set field_t_seen true t.t_fields
let unmark t = t.t_fields <- Term_fields.set field_t_seen false t.t_fields

module Bool = struct
  type t = bool_term

  let both_atoms_marked (t:t): bool =
    let seen_pos = Term_fields.get field_t_mark_pos t.t_fields in
    let seen_neg = Term_fields.get field_t_mark_neg t.t_fields in
    seen_pos && seen_neg

  let[@inline] assigned_atom t : atom option = match value t, var t with
    | TA_assign {value=V_true;_}, Var_bool{pa;_} -> Some pa
    | TA_assign {value=V_false;_}, Var_bool{na;_} -> Some na
    | _ -> None

  let[@inline] assigned_atom_exn t : atom = match value t, var t with
    | TA_assign {value=V_true;_}, Var_bool{pa;_} -> pa
    | TA_assign {value=V_false;_}, Var_bool{na;_} -> na
    | _ -> assert false

  let[@inline] is_true t = match value t with
    | TA_assign {value=V_true;_} -> true
    | _ -> false

  let[@inline] is_false t = match value t with
    | TA_assign {value=V_false;_} -> true
    | _ -> false

  let[@inline] pa_unsafe (t:t) : atom = match t.t_var with
    | Var_bool {pa; _} -> pa
    | _ -> assert false

  let[@inline] na_unsafe (t:t) : atom = match t.t_var with
    | Var_bool {na; _} -> na
    | _ -> assert false

  let[@inline] pa (t:t) : atom = setup_var t; pa_unsafe t
  let[@inline] na (t:t) : atom = setup_var t; na_unsafe t
end

let[@inline] eval_bool (t:term) : eval_bool_res =
  assert (Type.is_bool t.t_ty);
  t.t_tc.tct_eval_bool t

(* verbose debug printer *)
let debug out t : unit =
  let pp_val out = function
    | TA_none -> ()
    | TA_assign {value;_} ->
      Format.fprintf out "[@@%d@<1>→%a]" t.t_level Value.pp value
  in
  Format.fprintf out "%a[%d]%a" pp t (id t) pp_val (value t)

(** {2 Hashconsing of a Theory Terms} *)

module type TERM_ALLOC_OPS = sig
  val p_id : plugin_id (** ID of the theory *)
  val initial_size: int (** initial size of table *)
  val equal : view -> view -> bool (** Shallow equality of two views of the plugin *)
  val hash : view -> int (** Shallow hash of a view of the plugin *)
end

module[@inline] Term_allocator(Ops : TERM_ALLOC_OPS) = struct
  module H = CCHashtbl.Make(struct
      type t = view
      include Ops
    end)
  let () = assert (Ops.p_id <= Unsafe.max_plugin_id)

  (* view -> term *)
  let tbl = H.create Ops.initial_size

  (* after GC, recycle identifiers into this vec *)
  let recycle_ids : int Vec.t = Vec.make_empty 0

  (* delete a term: flag it for removal, then recycle its ID *)
  let delete (t:t) : unit =
    Log.debugf 5 (fun k->k "(@[<1>Term_alloc.delete@ %a@])" debug t);
    t.t_fields <- Term_fields.set field_t_is_deleted true t.t_fields;
    assert (plugin_id t = Ops.p_id);
    Vec.push recycle_ids (plugin_specific_id t);
    H.remove tbl (view t);
    ()

  (* obtain a fresh ID, unused by any other term *)
  let get_fresh_id : unit -> int =
    let id_alloc = ref 0 in
    fun () ->
      if Vec.size recycle_ids = 0 then (
        let n = !id_alloc in
        incr id_alloc;
        n
      ) else (
        let n = Vec.last recycle_ids in
        Vec.pop recycle_ids;
        n
      )

  (* build a fresh term *)
  let make_term_ t_view t_ty t_tc : t =
    let p_specific_id = get_fresh_id () in
    let t_id = Ops.p_id lor (p_specific_id lsl plugin_id_width) in
    Unsafe.make_term t_id t_view t_ty t_tc

  (* inline make function *)
  let[@inline] make (view:view) (ty:Type.t) (tc:tc_term) : t =
    try H.find tbl view
    with Not_found ->
      let t = make_term_ view ty tc in
      H.add tbl view t;
      t

  let[@inline] iter_terms k = H.values tbl k

  let gc_all () : unit =
    Log.debugf 3 (fun k->k "(gc-all@ :p_id %d)" Ops.p_id);
    let v = Vec.make_empty dummy_term in
    (* collect *)
    H.iter
      (fun _ t ->
         if gc_marked t
         then gc_unmark t
         else Vec.push v t)
      tbl;
    (* delete *)
    Vec.iter delete v
end
