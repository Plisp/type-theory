(*
 * actual pancake programs
 *)

open panItreeSemTheory;
open panSemTheory; (* eval_def *)

(*/ equational
   not sure whether this should be kept around but lemmas use it atm
 *)

(* iiter (Ret INL) → Tau (itree_unfold (iiter_cb (mrec_cb h_prog))
                           (mrec_cb h_prog (bind (rh state_res) k))) to continue *)
(* mrec: Vis (INL (prog × newstate)) k → Ret (INL (h_prog prog bind k)) *)
(* mrec: Vis (INR (svis_ev × result->itree)) k → Ret (INL (h_prog prog bind k)) *)
Definition mrec_cb_def[simp]:
    mrec_cb rh (Ret r) = Ret (INR r)
  ∧ mrec_cb rh (Tau t) = Ret (INL t)
  ∧ mrec_cb rh (Vis (INL state_res) k) = Ret (INL (bind (rh state_res) k))
  ∧ mrec_cb rh (Vis (INR   ffi_res) k) = Vis ffi_res (λx. Ret (INL (k x)))
End

Theorem itree_mrec_alt:
  itree_mrec rh seed = iter (mrec_cb rh) (rh seed)
Proof
  rw[itree_mrec_def] >>
  AP_THM_TAC >>
  AP_TERM_TAC >>
  rw[FUN_EQ_THM] >>
  rw[DefnBase.one_line_ify NONE mrec_cb_def]
QED

(*/ Seq thm
   this is how we split up a program
 *)

Theorem itree_bind_k_ret:
  bind t k = Ret r ⇒ ∃r'. t = Ret r' ∧ Ret r = (k r')
Proof
  rw[itree_bind_thm] >>
  Cases_on ‘t’ >> gvs[itree_bind_thm]
QED

Theorem mrec_cb_ret:
  mrec_cb rh t = Ret (INR r) ⇒ t = (Ret r)
Proof
  rw[DefnBase.one_line_ify NONE mrec_cb_def] >>
  Cases_on ‘t’ >-
   fs[] >-
   fs[] >-
   (Cases_on ‘a’ >> fs[])
QED

Theorem mrec_lemma:
  iter (mrec_cb h_prog)
     (⋆ t
        (λ(res,s'). if res = NONE then Vis (INL (p2,s')) Ret else Ret (res,s')))
  = ⋆ (iter (mrec_cb h_prog) t)
      (λ(res,s').
         if res = NONE then iter (mrec_cb h_prog) (h_prog (p2,s'))
         else Ret (res,s'))
Proof
  rw[Once itree_bisimulation] >>
  qmatch_goalsub_abbrev_tac ‘(iter (mrec_cb h_prog) (⋆ _ cb1))’ >>
  qabbrev_tac ‘cb2 = (λ(res,s').
                        if res = NONE then
                          iter (mrec_cb h_prog) (h_prog (p2,s'))
                        else Ret (res,s'))’ >>
  qexists_tac ‘λa b. ∃ps. a = iter (mrec_cb h_prog) (⋆ ps cb1) ∧
                          b = ⋆ (iter (mrec_cb h_prog) ps) cb2’ >>
  rw[] >-
   (metis_tac[]) >-
   (‘⋆ (mrec_cb h_prog (⋆ ps cb1))
       (λx. case x of INL a => Tau (iter (mrec_cb h_prog) a) | INR b => Ret b)
     = Ret x’
      by metis_tac[itree_bind_thm, itree_iter_thm] >>
    qpat_x_assum ‘Ret x = iter _ _’ kall_tac >>
    drule itree_bind_k_ret >> pop_assum kall_tac >> strip_tac >>
    Cases_on ‘r'’ >-
     (fs[]) >-
     (gvs[] >>
      drule mrec_cb_ret >> strip_tac
      drule itree_bind_k_ret >> strip_tac >>
      rw[Once itree_iter_thm] >>
      rw[Once itree_bind_thm] >>
      qunabbrev_tac ‘cb2’ >>
      Cases_on ‘r'’ >>
      rw[itree_bind_thm] >-
       (qunabbrev_tac ‘cb1’ >>
        fs[]) >-
       (qunabbrev_tac ‘cb1’ >>
        fs[])))
   ()
QED

Theorem seq_thm:
  itree_mrec h_prog (Seq p p2, s) =
  Tau (⋆ (itree_mrec h_prog (p, s))
         (λ(res,s').
            if res = NONE
            then itree_mrec h_prog (p2, s')
            else (Ret (res, s'))))
Proof
  rw[itree_mrec_alt] >>
  rw[h_prog_def, h_prog_rule_seq_def] >>
  rw[Once itree_iter_thm] >>
  rw[itree_bind_thm] >>
  (* h_prog returns a finite itree (except for while?) *)
  (* Vis (INL (p2, s')) Ret --> ret inl (⋆ (h_prog p,s) Ret) = tau iter h_prog...*)
  (* Ret r --mrec_cb-> Ret (INR (res, s')) --iter-> Ret (res, s') *)
  rw[]
QED

(* Dec cleanup *)

Definition revert_binding_def:
  revert_binding name old_s
  = (λ(res,s').
       Ret
       (res,
        s' with locals :=
        res_var s'.locals (name,FLOOKUP old_s.locals name)))
End

Theorem h_prog_rule_dec_alt:
  h_prog_rule_dec vname e p s =
  case eval s e of
    NONE => Ret (SOME Error,s)
  | SOME value =>
      Vis (INL (p,s with locals := s.locals |+ (vname,value)))
          (revert_binding vname s)
Proof
  rw[h_prog_rule_dec_def, revert_binding_def]
QED

(* (* f, f' type vars instantiated differently smh *) *)
(* Theorem mrec_bind_lemma: *)
(*   ∀f f'. *)
(*   (∀a. ∃r. (f a) = (Ret r) ∧ (f' a) = (Ret r)) ⇒ *)
(*   ∀t. iter (mrec_cb h_prog) (bind t f) = *)
(*       (bind (iter (mrec_cb h_prog) t) f') *)
(* Proof *)
(*   rpt strip_tac >> *)
(*   qspecl_then [‘(mrec_cb h_prog) ↻ (bind t f)’, *)
(*                ‘bind (mrec_cb h_prog ↻ t) f'’] *)
(*               strip_assume_tac itree_bisimulation >> *)
(*   fs[EQ_IMP_THM] >> *)
(*   qpat_x_assum ‘_ ⇒ ∃R. _’ kall_tac >> *)
(*   pop_assum irule >> *)
(*   qexists_tac ‘λa b. ∃t name s. *)
(*                 a = (mrec_cb h_prog ↻ (bind t f)) ∧ *)
(*                 b = (bind (mrec_cb h_prog ↻ t) f')’ >> *)
(*   rw[] >- *)
(*    metis_tac[] >- (* base case *) *)
(*    (* ret *) *)
(*    (Cases_on ‘t'’ >- *)
(*      (fs[Once itree_iter_thm, itree_bind_thm] >> *)
(*       last_assum $ qspec_then ‘x'’ strip_assume_tac >> *)
(*       fs[itree_bind_thm]) >- *)
(*      (fs[Once itree_iter_thm, itree_bind_thm]) >- *)
(*      (Cases_on ‘a’ >- *)
(*        fs[Once itree_iter_thm, itree_bind_thm] >- *)
(*        fs[Once itree_iter_thm, itree_bind_thm])) >- *)
(*    (* tau *) *)
(*    (Cases_on ‘t'’ >- *)
(*      (fs[Once itree_iter_thm, itree_bind_thm] >> *)
(*       last_assum $ qspec_then ‘x’ strip_assume_tac >> *)
(*       fs[itree_bind_thm]) >- *)
(*      (fs[Once itree_iter_thm, itree_bind_thm] >> *)
(*       metis_tac[]) >- *)
(*      (Cases_on ‘a’ >- *)
(*        (fs[Once itree_iter_thm, itree_bind_thm] >> *)
(*         metis_tac[itree_bind_assoc]) >- *)
(*        fs[Once itree_iter_thm, itree_bind_thm])) >- *)
(*    (* vis *) *)
(*    (Cases_on ‘t'’ >- *)
(*      (fs[Once itree_iter_thm, itree_bind_thm] >> *)
(*       last_assum $ qspec_then ‘x’ strip_assume_tac >> *)
(*       fs[itree_bind_thm]) >- *)
(*      fs[Once itree_iter_thm, itree_bind_thm] >- *)
(*      (Cases_on ‘a'’ >- *)
(*        fs[Once itree_iter_thm, itree_bind_thm] >- *)
(*        (fs[Once itree_iter_thm, itree_bind_thm] >> *)
(*         strip_tac >> *)
(*         (* stuck on extra Tau from iter on (Ret INL) from (Vis INR) *) *)
(*        ))) *)
(* QED *)

(* relies on mrec_cb h_prog rev -> only Ret INR, so can't prolong iteration *)
(* also applies to while and cond! *)
Theorem dec_lemma:
  ∀ t name s.
    (iter (mrec_cb h_prog) (bind t (revert_binding name s)))
  ≈ (bind (iter (mrec_cb h_prog) t) (revert_binding name s))
Proof
  qspecl_then
  [‘λa b. ∃t name s.
     a = (iter (mrec_cb h_prog) (bind t (revert_binding name s))) ∧
     b = (bind (iter (mrec_cb h_prog) t) (revert_binding name s))’]
  strip_assume_tac itree_wbisim_strong_coind >>
  rpt strip_tac >>
  pop_assum irule >>
  rw[] >-
   (Cases_on ‘t''’ >-
     (or3_tac >> (* Ret produces Ret, doesn't affect iter. easy! *)
      Cases_on ‘x’ >>
      rw[revert_binding_def] >>
      rw[Once itree_iter_thm, itree_bind_thm] >>
      rw[Once itree_iter_thm, itree_bind_thm]) >-
     (* Tau case is clear *)
     (or1_tac >>
      rw[Once itree_iter_thm, itree_bind_thm] >>
      rw[Once itree_iter_thm, itree_bind_thm] >>
      metis_tac[]) >-
     (* Vis case is a bit tricky, depends on whether the event is silent *)
     (Cases_on ‘a’ >-
       (or1_tac >>
        rw[Once itree_iter_thm, itree_bind_thm] >>
        rw[Once itree_iter_thm, itree_bind_thm] >>
        metis_tac[itree_bind_assoc]) >-
       (or2_tac >>
        rw[Once itree_iter_thm, itree_bind_thm] >>
        rw[Once itree_iter_thm, itree_bind_thm] >>
        or1_tac >>
        qexistsl_tac [‘Tau (g r)’, ‘name’, ‘s’] >>
        CONJ_TAC >-
         (CONV_TAC $ RHS_CONV $ ONCE_REWRITE_CONV[itree_bind_thm] >>
          CONV_TAC $ RHS_CONV $ ONCE_REWRITE_CONV[itree_iter_thm] >>
          rw[itree_bind_thm]) >-
         (CONV_TAC $ RHS_CONV $ ONCE_REWRITE_CONV[itree_iter_thm] >>
          rw[itree_bind_thm])))) >-
   metis_tac[]
QED

Theorem dec_thm:
  (eval s e = SOME k) ⇒
  (itree_mrec h_prog (Dec name e p,s))
  ≈ (bind
      (itree_mrec h_prog (p,s with locals := s.locals |+ (name,k)))
      (revert_binding name s))
Proof
  rw[itree_mrec_alt] >>
  rw[h_prog_def, h_prog_rule_dec_def] >>
  rw[Once itree_iter_thm, itree_bind_thm] >>
  rw[GSYM revert_binding_def] >>
  metis_tac[dec_lemma, itree_wbisim_tau_eq, itree_wbisim_trans]
QED

(*/ massaging into ffi itree
   TODO change when fixed, also prove it respects wbisim or have a bad time
 *)

Definition massage_cb_def[simp]:
    massage_cb (INL (Ret (res,s))) = Ret' res
  ∧ massage_cb (INR (Ret (res,s))) = Ret' res
  ∧ massage_cb (INL (Tau t)) = Tau' (INL t)
  ∧ massage_cb (INR (Tau t)) = Tau' (INR t)
  ∧ massage_cb (INL (Vis (e,k) g)) = Vis' e (λr. INR (k r))
  ∧ massage_cb (INR (Vis e g))     = Vis' e (INR ∘ g)
End

(* massage Ret type from (η x state) -> η *)
(* convert Vis (sem_vis_event x (FFI_result -> itree)) ((prog x state) -> %itree)
-> Vis sem_vis_event (FFI_result -> itree) *)
Definition massage_def:
  massage x = itree_unfold massage_cb (INL x)
End

Theorem massage_thm:
    massage (Ret (res, s)) = Ret res ∧ massage (Tau t) = Tau (massage t)
Proof
  rw[massage_def] >-
   rw[Once itree_unfold] >-
   (rw[Once itree_unfold] >> rw[GSYM massage_def])
QED

Theorem itree_evaluate_alt:
  itree_evaluate p s = massage (itree_mrec h_prog (p,s))
Proof
  rw[itree_evaluate_def, massage_def] >>
  AP_THM_TAC >> (* same fn => same on same arg, backwards *)
  AP_TERM_TAC >>
  rw[FUN_EQ_THM] >>
  rw[DefnBase.one_line_ify NONE massage_cb_def]
QED

open finite_mapTheory; (* FLOOKUP_UPDATE *)
open helperLib; (* remove_whitespace *)
(* open wordsTheory; (* n2w_def *) *)

open asmTheory; (* word_cmp_def *)
open miscTheory; (* read_bytearray *)
open panLangTheory; (* size_of_shape_def *)
open panPtreeConversionTheory; (* parse_funs_to_ast *)
open wordLangTheory; (* word_op_def *)

local
  val f =
    List.mapPartial
       (fn s => case remove_whitespace s of "" => NONE | x => SOME x) o
    String.tokens (fn c => c = #"\n")
in
  fun quote_to_strings q =
    f (Portable.quote_to_string (fn _ => raise General.Bind) q)
  end

fun parse_pancake q =
  let
    val code = quote_to_strings q |> String.concatWith "\n" |> fromMLstring
  in
    EVAL “parse_funs_to_ast ^code”
end

(*/ loops work!
   manual loop unrolling isn't too bad with equational rewrites
 *)

val loop_ast = rhs $ concl $ parse_pancake ‘
fun fn() {
  var x = 1;
  x = 0;
  while (x < 1) {
    x = x + 1;
  }
}’;

Definition loop_sem_def:
  loop_sem (s:('a,'ffi) panSem$state) =
  itree_evaluate (SND $ SND $ HD $ THE ^loop_ast) s
End

Definition h_prog_whilebody_cb_def[simp]:
    h_prog_whilebody_cb p (SOME Break) s' = Ret (INR (NONE,s'))
  ∧ h_prog_whilebody_cb p (SOME Continue) s' = Ret (INL (p,s'))
  ∧ h_prog_whilebody_cb p NONE s' = Ret (INL (p,s'))
  (* nice! this syntax is valid *)
  ∧ h_prog_whilebody_cb p res s' = Ret (INR (res,s'))
End

Definition h_prog_while_cb_def[simp]:
    h_prog_while_cb (p,s) NONE = Ret (INR (SOME Error,s))
  ∧ h_prog_while_cb (p,s) (SOME (ValWord w))
    = (if (w ≠ 0w)
       then Vis (INL (p,s))
                (λ(res,s'). h_prog_whilebody_cb p res s')
       else Ret (INR (NONE,s)))
  ∧ h_prog_while_cb (p,s) (SOME (ValLabel _)) = Ret (INR (SOME Error,s))
  ∧ h_prog_while_cb (p,s) (SOME (Struct _)) = Ret (INR (SOME Error,s))
End

(* PR submitted *)
Theorem h_prog_rule_while_alt:
  h_prog_rule_while g p s =
  iter (λ(p',s'). (h_prog_while_cb (p',s') (eval s' g))) (p,s)
Proof
  rw[h_prog_rule_while_def] >>
  AP_THM_TAC >>
  AP_TERM_TAC >>
  rw[FUN_EQ_THM] >>
  rw[DefnBase.one_line_ify NONE h_prog_while_cb_def] >>
  rw[DefnBase.one_line_ify NONE h_prog_whilebody_cb_def] >>
  rpt (PURE_TOP_CASE_TAC >> gvs[] >> rw[FUN_EQ_THM])
QED

Theorem cheat1:
  0w < 1w (* supposed to be :4 word but weever *)
Proof
  cheat
QED

Theorem mrec_thm:
  iter (mrec_cb h_prog) (⋆ t k)
  ≈ ⋆ (iter (mrec_cb h_prog) t) (λr. iter (mrec_cb h_prog) (k r))
Proof
  CONV_TAC $ RHS_CONV $ REWRITE_CONV[Once itree_iter_thm, mrec_cb_def] >>
  CONV_TAC $ RHS_CONV $ REWRITE_CONV[Once itree_bind_thm] >>
  rw[itree_bind_thm]
QED

Theorem loop_thm:
  loop_sem s =  Tau (Tau (Tau (Tau (Tau (Ret NONE)))))
Proof
  rw[loop_sem_def, itree_semantics_def, itree_evaluate_alt] >>
  rw[itree_mrec_alt, h_prog_def, h_prog_rule_dec_alt] >>
  rw[eval_def] >>
  rw[Once itree_iter_thm, itree_bind_thm] >>
  (* seq *)
  rw[h_prog_def, h_prog_rule_seq_def] >>
  rw[itree_bind_thm] >>
  rw[Once itree_iter_thm] >>
  rw[Once itree_bind_thm] >>
  (* assign *)
  rw[Once h_prog_def, h_prog_rule_assign_def] >>
  rw[FLOOKUP_UPDATE, word_op_def, is_valid_value_def, shape_of_def,
     Once eval_def, cheat1] >>
  rw[itree_bind_thm] >>
  rw[Once itree_iter_thm, Once itree_bind_thm] >>
  (* while *)
  rw[Once h_prog_def, h_prog_rule_while_alt] >>
  rw[Once itree_iter_thm] >> rw[Once itree_iter_thm] >>
  rw[Once eval_def] >> rw[Once eval_def] >>
  rw[FLOOKUP_UPDATE] >>
  rw[Once eval_def, word_cmp_def, cheat1] >>
  rw[itree_bind_thm] >>
  (* assignment *)
  rw[Once h_prog_def, h_prog_rule_assign_def] >>
  rw[Once eval_def] >> rw[Once eval_def] >>
  rw[FLOOKUP_UPDATE, word_op_def, is_valid_value_def, shape_of_def,
     Once eval_def, cheat1] >>
  rw[Once itree_iter_thm, itree_bind_thm] >>
  (* second while *)
  (* rw[GSYM h_prog_rule_while_alt, GSYM h_prog_def] *)
  rw[Once itree_iter_thm] >> rw[Once itree_iter_thm] >>
  rw[eval_def, FLOOKUP_UPDATE, word_cmp_def] >>
  rw[revert_binding_def] >>
  rw[Once itree_iter_thm, itree_bind_thm] >>
  (* massage *)
  rw[massage_thm]
QED

(* ffi test *)

val ffi_ast = rhs $ concl $ parse_pancake ‘
fun fn() {
  #num_clients(0, 0, 0, 0);
  #num_clients(0, 0, 0, 0);
}’;

Definition ffi_sem_def:
  ffi_sem (s:('a,'ffi) panSem$state) =
  itree_evaluate (SND $ SND $ HD $ THE ^ffi_ast) s
End

Theorem ffi_sem_thm:
  ffi_sem s = ARB
Proof
  rw[ffi_sem_def, itree_semantics_def, itree_evaluate_alt] >>
  (* Seq *)
  rw[itree_mrec_alt, h_prog_def, h_prog_rule_seq_def] >>
  rw[Once itree_iter_thm, Once itree_bind_thm] >>
  (* extcall *)
  rw[itree_mrec_alt, h_prog_def, h_prog_rule_ext_call_def] >>
  rw[eval_def, FLOOKUP_UPDATE] >>
  rw[read_bytearray_def] >>
  rw[Once itree_bind_thm] >>
  rw[Once itree_iter_thm] >>
  rw[Once itree_bind_thm] >>
  (* inner thing *)
  rw[Once itree_bind_thm] >>
  rw[Once itree_bind_thm] >>
  (* TODO massage bug! (not yet fixed, update when done) *)
  rw[massage_def] >>
  rw[Once itree_unfold, massage_thm] >>
  rw[Once itree_unfold]
QED
