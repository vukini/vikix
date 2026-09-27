(* calc.ml — variants and pattern matching: a tiny calculator.

   An expression is one of a few shapes, and the type says exactly which.
   Functions take an expression apart with `match`, one case per shape;
   the compiler warns if a case is missing, so adding a shape shows you
   every place that must handle it. *)

type expr =
  | Num of float
  | Add of expr * expr
  | Mul of expr * expr
  | Div of expr * expr
  | Neg of expr

(* Dividing by zero is an answer too: the result says which it was. *)
let rec eval = function
  | Num x -> Ok x
  | Neg e -> Result.map (fun x -> -.x) (eval e)
  | Add (a, b) -> both ( +. ) a b
  | Mul (a, b) -> both ( *. ) a b
  | Div (a, b) -> (
      match eval b with
      | Ok 0. -> Error "division by zero"
      | _ -> both ( /. ) a b)

and both op a b =
  match (eval a, eval b) with
  | Ok x, Ok y -> Ok (op x y)
  | (Error _ as e), _ | _, (Error _ as e) -> e

let rec show = function
  | Num x -> Printf.sprintf "%g" x
  | Neg e -> "-" ^ show e
  | Add (a, b) -> "(" ^ show a ^ " + " ^ show b ^ ")"
  | Mul (a, b) -> show a ^ " * " ^ show b
  | Div (a, b) -> show a ^ " / " ^ show b

let () =
  [ Add (Num 1., Mul (Num 2., Num 3.));
    Div (Num 1., Add (Num 2., Neg (Num 2.)));
    Mul (Add (Num 1.5, Num 2.5), Neg (Num 4.)) ]
  |> List.iter (fun e ->
         match eval e with
         | Ok v -> Printf.printf "%s = %g\n" (show e) v
         | Error msg -> Printf.printf "%s: %s\n" (show e) msg)
