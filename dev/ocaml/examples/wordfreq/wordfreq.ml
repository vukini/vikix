(* wordfreq.ml — the ten most common words in a text file.

   A word is a run of letters, compared in lower case. A Hashtbl counts
   them; List.sort with a comparison puts the most common first.

     dune exec ./wordfreq.exe -- text.txt *)

let read_file path = In_channel.with_open_text path In_channel.input_all

(* Split into runs of letters a-z, counting each into [counts]. *)
let count_words counts text =
  let word = Buffer.create 16 in
  let flush () =
    if Buffer.length word > 0 then begin
      let w = Buffer.contents word in
      Hashtbl.replace counts w (1 + Option.value ~default:0 (Hashtbl.find_opt counts w));
      Buffer.clear word
    end
  in
  String.iter (fun c -> if c >= 'a' && c <= 'z' then Buffer.add_char word c else flush ())
    (String.lowercase_ascii text);
  flush ()

(* The higher count first; the same count in alphabetical order. *)
let by_count (w1, c1) (w2, c2) = if c1 <> c2 then compare c2 c1 else compare w1 w2

let () =
  match Sys.argv with
  | [| _; path |] ->
      let counts = Hashtbl.create 256 in
      count_words counts (read_file path);
      Hashtbl.to_seq counts |> List.of_seq |> List.sort by_count
      |> List.filteri (fun i _ -> i < 10)
      |> List.iter (fun (w, c) -> Printf.printf "%4d %s\n" c w)
  | _ -> prerr_endline "usage: wordfreq FILE"; exit 2
