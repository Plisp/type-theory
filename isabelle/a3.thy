(*
 * COMP4161 Assignment 3.
 *)

theory a3
  imports
    AutoCorres.AutoCorres
    "HOL-Library.Prefix_Order"
begin

section "Huffman Code"

(* The template for this question contains hints in the form of lemmas
   that are not one of the direct questions a)-j). They are marked with
   "oops". You can, but do not have to prove these lemma. There is more
   than one way to arrive at a correct proof.

   The lemmas marked with sorry and TODO are the ones you should prove
   unchanged for Q1. In Q2 you are allowed to tune the lemma statements.
*)

type_synonym 'a freq_list = "('a \<times> int) list"

(* Q1 a): *)
primrec add_one :: "'a \<Rightarrow> 'a freq_list \<Rightarrow> 'a freq_list" where
  "add_one c [] = [(c,1)]" |
  "add_one c (a#as) 
     = (if fst(a)=c then (c,snd(a)+1)#as else a#(add_one c as)) "
print_theorems

primrec freq_of :: "'a list \<Rightarrow> 'a freq_list" where
  "freq_of [] = []" |
  "freq_of (a#as) = add_one a (freq_of as)"

value "freq_of ''abcdaa''"

find_theorems "_ ` _"
lemma fst_set_add_one:
  "fst ` set (add_one x xs) = {x} \<union> fst ` set xs"
  apply(induct xs)
  by simp_all

lemma add_one_distinct:
  "distinct (map fst l) \<Longrightarrow> distinct (map fst (add_one c l))"
  apply(induct l)
  by (auto simp add: fst_set_add_one)
  

(* Q1 b): *)
lemma distinct_freq[simp]:
  "distinct (map fst (freq_of cs))"
  apply(induct cs)
  by (auto simp add: add_one_distinct)


datatype 'a htree = Leaf 'a int | Branch "'a htree" "'a htree"

primrec weight :: "'a htree \<Rightarrow> int" where
  "weight (Leaf _ w) = w" |
  "weight (Branch l r) = weight l + weight r"

fun build_tree :: "'a htree list \<Rightarrow> 'a htree" where
  "build_tree [] = Leaf undefined 0" |
  "build_tree [t] = t" |
  "build_tree (t1 # t2 # cs) = build_tree (insort_key weight (Branch t1 t2) cs)"

definition huffman_tree :: "'a freq_list \<Rightarrow> 'a htree" where
  "huffman_tree = build_tree o map (\<lambda>(c,w). Leaf c w) o sort_key snd"


definition
  "some_tree = huffman_tree (freq_of ''abcdaa'')"

value some_tree


type_synonym code = "bool list"

fun add_bit :: "bool \<Rightarrow> 'a \<times> code \<Rightarrow> 'a \<times> code" where
  "add_bit b (c, code) = (c, b # code)"

primrec code_list :: "'a htree \<Rightarrow> ('a \<times> code) list" where
  "code_list (Leaf c _) = [(c,[])]" |
  "code_list (Branch l r) = map (add_bit False) (code_list l) @ map (add_bit True) (code_list r)"

definition code_map :: "'a htree \<Rightarrow> (code \<times> 'a) list" where
  "code_map tree = map (\<lambda>(a,b). (b,a)) (code_list tree)"

value "code_list some_tree"
value "code_map some_tree"

(* Q1 c): *)
find_theorems List.concat
definition encoder :: "('a \<Rightarrow> code option) \<Rightarrow> 'a list \<Rightarrow> code" where
  "encoder mp xs = concat (map (\<lambda>x. the (mp x)) xs)"

value "encoder (map_of (code_list some_tree)) ''cb''"

fun decoder :: "(code \<Rightarrow> 'a option) \<Rightarrow> code \<Rightarrow> code \<Rightarrow> 'a list" where
  "decoder mp acs [] = []" |
  "decoder mp acs (c#cs) = (if mp (acs@[c]) \<noteq> None
                            then the (mp (acs@[c])) # decoder mp [] cs
                            else decoder mp (acs @ [c]) cs)"
(* acs collects partially decoded string *)
definition unique_prefix :: "(code \<Rightarrow> 'a option) \<Rightarrow> bool" where
  "unique_prefix cm = (\<forall>xs\<in>dom cm. \<forall>ys\<in>dom cm. \<not> ys < xs)"

definition is_inv :: "('a \<Rightarrow> 'b option) \<Rightarrow> ('b \<Rightarrow> 'a option) \<Rightarrow> bool" where
  "is_inv mp mp' = (\<forall>x y. mp x = Some y \<longleftrightarrow> mp' y = Some x)"

lemma unique_prefixD:
  "\<lbrakk> unique_prefix m; m xs = Some y; m xs' = Some y'; xs = xs' @ xs'' \<rbrakk>
   \<Longrightarrow> xs'' = []"
  unfolding unique_prefix_def
  apply(clarsimp)
  apply(rule ccontr)
  apply(drule Map.domI, drule Map.domI)
  thm domIff Prefix_Order.prefixI
  by (metis Prefix_Order.prefixI append_self_conv domIff nless_le)

lemma decoder_step:
  "\<lbrakk>unique_prefix mp'; mp' ys' = None; mp' (ys' @ ys) = Some x\<rbrakk>
   \<Longrightarrow> decoder mp' ys' (ys @ zs) = x # decoder mp' [] zs"
  apply(induct ys arbitrary: ys')
   apply(simp)
  apply(simp only: append_Cons decoder.simps)
  apply(auto)
  using unique_prefixD
   apply(metis Cons_eq_appendI append_eq_append_conv2 option.inject self_append_conv2)
  using unique_prefixD
  apply(metis Cons_eq_appendI append_eq_append_conv2 self_append_conv2)
  done

(* Q1 d): *)
lemma decoder:
  "\<lbrakk> is_inv mp mp'; unique_prefix mp'; set xs \<subseteq> dom mp; [] \<notin> dom mp' \<rbrakk>
   \<Longrightarrow> decoder mp' [] (encoder mp xs) = xs"
  apply(induct xs)
   apply(simp add: encoder_def)
  apply(simp add: encoder_def)
  using decoder_step is_inv_def
  by (metis (lifting) domIff option.collapse self_append_conv2)

(* Q1 e): *)
lemma is_inv_map_of:
  "\<lbrakk> distinct (map snd xs); distinct (map fst xs) \<rbrakk> \<Longrightarrow>
  is_inv (map_of xs) (map_of (map (\<lambda>(a,b). (b,a)) xs))"
  apply(induct xs)
   apply(simp add: is_inv_def)
  apply(clarsimp simp add: is_inv_def)
  by (smt (verit, ccfv_SIG) Some_eq_map_of_iff case_prod_beta
      image_iff map_upd_Some_unfold old.prod.inject prod.collapse)

(* Q1 f): *)
primrec letters_of :: "'a htree \<Rightarrow> 'a set" where
  "letters_of (Leaf c _) = { c }" |
  "letters_of (Branch l r) = letters_of l \<union> letters_of r"

(* Q1 g): TODO *)
fun distinct_tree :: "'a htree \<Rightarrow> bool"  where
  "distinct_tree (Leaf _ _) = undefined"

fun distinct_forest :: "'a htree list \<Rightarrow> bool" where
  "distinct_forest [] = True" |
  "distinct_forest (t#ts) = (distinct_tree t \<and> distinct_forest ts \<and>
                             letters_of t \<inter> \<Union> (set (map letters_of ts)) = {})"

lemma add_bit_fst_idem:
  "fst (add_bit b (c,code)) = c"
  by simp

lemma fst_code_list:
  "fst ` set (code_list t) = letters_of t"
  apply(induct t)
   apply(simp)
  apply(simp)
  using add_bit_fst_idem
  by (metis (no_types) image_Un image_cong image_image prod.collapse)

(* Q1 h): *)
lemma distinct_fst_code_list[simp]:
  "distinct_tree t \<Longrightarrow> distinct (map fst (code_list t))"
  sorry (* TODO *)

lemma distinct_forest_insort:
  "distinct_forest (insort_key f t ts) =
   (distinct_tree t \<and> distinct_forest ts \<and> letters_of t \<inter> \<Union> (set (map letters_of ts)) = {})"
  oops


lemma distinct_build_tree:
  "distinct_forest ts \<Longrightarrow> distinct_tree (build_tree ts)"
  oops

lemma distinct_insort_map:
  "distinct (map g (insort_key f x xs)) = (g x \<notin> g ` set xs \<and> distinct (map g xs))"
  oops

(* Q1 i): *)
lemma distinct_huffman[simp]:
  "distinct (map fst fs) \<Longrightarrow> distinct_tree (huffman_tree fs)"
  sorry (* TODO *)


(* If you're curious, this would be the overall correctness statement.
   You do not need to prove this one.
theorem huffman_decoder:
  "\<lbrakk>set xs \<subseteq> set ys; tree = huffman_tree (freq_of ys); 2 \<le> length (freq_of ys) \<rbrakk> \<Longrightarrow>
   decoder (map_of (code_map tree)) [] (encoder (map_of (code_list tree)) xs) = xs"
oops
 *)

(* ------------------------------------------------------------------------------------ *)

declare [[syntax_ambiguity_warning = false]]

definition "LEN = 1000"
declare LEN_def[simp]

external_file "stack.c"
install_C_file "stack.c"

autocorres "stack.c"

context stack
begin

thm is_empty'_def
thm has_capacity'_def
thm push'_def
thm pop'_def
thm sum'_def

primrec stack_from :: "machine_word list \<Rightarrow> machine_word \<Rightarrow> lifted_globals \<Rightarrow> bool" where
  "stack_from [] n s = (n = -1 )" |
  "stack_from (x # xs) n s = (n < LEN \<and> content_'' s.[unat n] = x \<and> stack_from xs (n - 1) s)"

definition is_stack where
  "is_stack xs s \<equiv> stack_from xs (top_'' s) s"
  
(* Q2 a) *)
lemma is_stack_Nil_top[simp]:
  "is_stack [] s = (top_'' s = -1)"
  sorry (* TODO *)

(* Q2 b) *)
lemma is_stack_Nil_is_empty:
  "is_stack [] s = (is_empty' s = 1)"
  sorry (* TODO *)

(* Q2 c) *)
lemma stack_from_neg[simp]:
  "stack_from xs (- 1) s = (xs = [])"
  sorry (* TODO *)

(* Q2 d) *)
lemma is_stack_single:
  "is_stack [x] s = (top_'' s = 0 \<and> content_'' s.[0] = x)"
  sorry (* TODO *)

(* Q2 e) *)
lemma is_stack_Cons[simp]:
  "is_stack (x # xs) s =
   (top_'' s < LEN \<and> content_'' s.[unat (top_'' s)] = x \<and> stack_from xs (top_'' s - 1) s)"
  sorry (* TODO *)


(* Q2 f) *)
lemma stack_from_top_upd[simp]:
  "stack_from xs n (s\<lparr>top_'' := t\<rparr>) = stack_from xs n s"
  sorry (* TODO *)

(* Helper lemma -- you can prove this one or state your own *)
lemma stack_from_top_and_array_upd':
  "\<lbrakk> \<forall>i \<le> unat n. a.[i] = content_'' s.[i] \<rbrakk> \<Longrightarrow>
   stack_from xs n (s\<lparr>top_'' := t, content_'' := a\<rparr>) = stack_from xs n s"
  oops

(* Q2 g) *)
lemma stack_from_top_and_array_upd[simp]:
  "unat (n + 1) < LEN \<Longrightarrow>
   stack_from xs n (s\<lparr>top_'' := n+1, content_'' := Arrays.update (content_'' s) (unat (n+1)) x\<rparr>) = 
   stack_from xs n s"
  sorry (* TODO *)


(* Q2 h) *)
lemma pop_correct_partial:
  "\<lbrace> \<lambda>s. is_stack (x#xs) s \<rbrace> pop' \<lbrace> \<lambda>rv s. rv = x \<and> TODO \<rbrace>"
  sorry (* TODO *)

(* Q2 i) *)
lemma pop_correct_total:
  "\<lbrace> \<lambda>s. TODO \<rbrace> pop' \<lbrace> \<lambda>rv s. TODO \<rbrace>!"
  sorry (* TODO *)

(* Q2 j) *)
lemma push_correct_total:
  "\<lbrace> \<lambda>s. TODO \<rbrace> push' x \<lbrace> \<lambda>_ s. TODO \<rbrace>!"
  supply word_less_nat_alt[simp]
  sorry (* TODO *)

(* Q2 k) *)
lemma sum_correct_partial:
  "\<lbrace> \<lambda>s. is_stack xs s \<rbrace> sum' \<lbrace> \<lambda>rv s. is_stack [] s \<and> rv = sum_list xs \<rbrace>"
  unfolding sum'_def
  apply (subst whileLoop_add_inv[where
                 I="TODO"])
  sorry (* TODO *)

end

end
