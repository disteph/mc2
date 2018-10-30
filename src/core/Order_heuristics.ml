type dec_heur =
  | BoolArith
  | ArithBool
  | AsItComes

let dec_heur = ref ArithBool
let[@inline] init = function
  | "BoolArith" ->
    print_endline("Setting decision heuristic to BoolArith");
    dec_heur := BoolArith
  | "ArithBool" ->
    print_endline("Setting decision heuristic to ArithBool");
    dec_heur := ArithBool
  | _ ->
    print_endline("Setting decision heuristic to AsItComes");
    dec_heur := AsItComes

let[@inline] cmp_sort   i j = Type.compare (Term.ty i) (Term.ty j)
let[@inline] cmp_id     i j = CCInt.compare (Term.id i) (Term.id j)  
let[@inline] cmp_weight i j = CCOrd.opp CCFloat.compare (Term.weight i) (Term.weight j)
let[@inline] cmp_string i j =
  CCString.compare
    (CCFormat.to_string Term.pp i)
    (CCFormat.to_string Term.pp j)

let[@inline] ( <+> ) cmp1 cmp2 i j =
  let tmp = cmp1 i j in if tmp=0 then cmp2 i j else tmp

let[@inline] cmp i j =
  match !dec_heur with
  | BoolArith -> (cmp_sort <+> (cmp_id <+> cmp_weight)) i j
  | ArithBool -> ((CCOrd.opp cmp_sort) <+> cmp_id) i j 
  | AsItComes -> (cmp_weight <+> cmp_id) i j (* comparison by weight *)
