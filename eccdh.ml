type point = Infinity | Point of Z.t * Z.t

type elliptic_curve = {
  p : Z.t;
  a : Z.t;
  b : Z.t;
  g : point;
  n : Z.t;
  h : Z.t
}


(*Elliptic Curve Functions*)

let is_point (r : point) curve =
  match r with
    | Infinity -> true
    | Point (x, y) ->
        Z.((y ** 2) mod curve.p) = Z.(((x ** 3) + (curve.a * x) + curve.b) mod curve.p)

let double_point (ec_point : point) curve =
  match ec_point with
    | Infinity -> Infinity
    | Point (x, y) -> 
        (
          match Z.(zero = y) with
            | true -> Infinity
            | false -> 
                let s = Z.(((((~$ 3) * (x ** 2)) + curve.a) /| ((~$ 2) * y)) mod curve.p) in
                let x_r = Z.(((s ** 2) - ((~$ 2) * x)) mod curve.p) in
                let y_r = Z.((-y + (s * (x - x_r))) mod curve.p) in
                  Point (x_r, y_r)
        )

let add_point (q : point) (r : point) curve =
  match q,r with
    | Infinity, Infinity -> Infinity
    | _, Infinity -> q
    | Infinity, _ -> r
    | Point (x_q, y_q), Point (x_r, y_r) -> 
        let s = Z.(((y_r - y_q) /| (x_r - x_q)) mod curve.p) in
        let x_f = Z.(((s ** 2) - x_q - x_r) mod curve.p) in
        let y_f = Z.((s * (x_q - x_f) - y_q) mod curve.p) in
          match (y_f = Z.zero) with
            | true -> Infinity
            | false -> Point (x_f, y_f)

(*Point multiplication using double-and-add method*)
let multiply_point (q : point) (d : Z.t) (curve : elliptic_curve) =
  let rec multiply_aux d r =
    match d = Z.zero with
      | true -> r
      | false ->
          let t = double_point r curve in
           ( 
            match ((Z.logand d (Z.one)) = Z.one) with
              | true -> multiply_aux (Z.(d asr 1)) (add_point t q curve)
              | false -> multiply_aux (Z.(d asr 1)) t 
           )
  in
    multiply_aux d q

(* ECC data representation functions*)

let int_pow a b = truncate ((float_of_int a) ** (float_of_int b))  

let integer_of_octet oct =
  int_of_string (String.concat "" ["0x"; oct])

let octList_of_octStr str =
  let str_len = String.length str in
  let rec aux i acc =
    match i with
      | -2 -> acc
      | i -> aux (i - 2) ((String.sub str i 2) :: acc)
  in
    aux (str_len - 2) []

let integer_of_octStr str =
  let oct_list = octList_of_octStr str in
  let m_len = (String.length str) / 2 in
  let rec aux m i sum =
    match m with
      | [] -> sum
      | m_i :: t -> 
          let tmp = (int_pow 2 (8 * (m_len - 1 - i))) * (integer_of_octet m_i) in
            aux t (i + 1) (Z.((~$ tmp) + sum))
  in
    aux oct_list 0 Z.zero


(*Generating random ints with a maximum length of decimal numbers*)
let random_big_int maxSize =
  Random.self_init ();
  let size = 1 + Random.int (maxSize - 1) in
  let big_int = String.create size in
  let rand_str = String.map (fun c -> 
                               let i = 48 + (Random.int 9) in Char.chr i) big_int in
    Z.of_string rand_str

(* Recommended Elliptic Curve Domain Parameters*)

(* http://www.secg.org/collateral/sec2_final.pdf *)
let sec_256_r1 = {
  p = Z.of_string_base 16 "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF";
  a = Z.of_string_base 16 "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC";
  b = Z.of_string_base 16  "5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B";
  g = Point (integer_of_octStr "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798",
             integer_of_octStr "483ADA7726A3C4655DA47BFC0E1108A8FD17B448A68554199C47D08FFB10D4B8");
  n = Z.of_string_base 16 "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141";
  h = Z.one
}

(* http://www.ecc-brainpool.org/download/Domain-parameters.pdf *)
let brainpool_P256_r1 =
  {
   p = Z.of_string_base 16 "A9FB57DBA1EEA9BC3E660A909D838D726E3BF623D52620282013481D1F6E5377";
   a = Z.of_string_base 16 "7D5A0975FC2C3057EEF67530417AFFE7FB8055C126DC5C6CE94A4B44F330B5D9";
   b = Z.of_string_base 16 "26DC5C6CE94A4B44F330B5D9BBD77CBF958416295CF7E1CE6BCCDC18FF8C07B6";
   g = Point (Z.of_string_base 16 "8BD2AEB9CB7E57CB2C4B482FFC81B7AFB9DE27E1E3BD23C23A4453BD9ACE3262",
              Z.of_string_base 16 "547EF835C3DAC4FD97F8461A14611DC9C27745132DED8E545C1D54C72F046997");
   n = Z.of_string_base 16 "A9FB57DBA1EEA9BC3E660A909D838D718C397AA3B561A6F7901E0E82974856A7";
   h = Z.one
  }

let main =
  Printf.printf "Enter your name: ";
  flush stdout;
  let user = Scanf.scanf "%s\n" (fun s -> s) in
  let curve = sec_256_r1 in
  let d_size = String.length (Z.to_string (curve.n)) in
  let sk = random_big_int d_size in
  let pk = multiply_point (curve.g) sk curve in 
  let _ = match pk with
    | Infinity -> failwith "error"
    | Point (pk_x, pk_y) -> Printf.printf "<%s,(%s,%s)>\n" user (Z.to_string pk_x) (Z.to_string pk_y)
  in
    Printf.printf "Enter <user,pk> to share key with\n";
    flush stdout;
    let peer = Scanf.scanf "%s\n" (fun peer -> peer) in
    let pk_b = Scanf.scanf "<(%s,%s)>\n" (fun  pk_x pk_y ->
           (Point (Z.of_string pk_x, Z.of_string pk_y))) 
     in
    let _ = match pk with
      | Infinity -> failwith "error"
      | Point (pk_x, pk_y) -> Printf.printf "<%s,(%s,%s)>\n" peer (Z.to_string pk_x) (Z.to_string pk_y)
    in
      ()