(* ** Abstract Reduction Systems *)
(* from Semantics Lecture at Programming Systems Lab, https://www.ps.uni-saarland.de/courses/sem-ws13/ *)

Require Export Undecidability.Shared.Libs.PSL.Base Lia Arith.

Module ARSNotations.
  Notation "p '<=1' q" := (forall x, p x -> q x) (at level 70).
  Notation "p '=1' q" := (forall x, p x <-> q x) (at level 70).
  Notation "R '<=2' S" := (forall x y, R x y -> S x y) (at level 70).
  Notation "R '=2' S"  := (forall x y, R x y <-> S x y) (at level 70).
End ARSNotations.

Import ARSNotations.

(* Relational composition *)
Require Import Relations.

Definition rcomp X Y Z (R : X -> Y -> Prop) (S : Y -> Z -> Prop) 
: X -> Z -> Prop :=
  fun x z => exists y, R x y /\ S y z.

Lemma rcomp_eq X (R: X -> X -> Prop): rcomp eq R =2 R.
Proof.
  split.
  - intros [x0 [-> H]]. exact H.
  - intro H. now exists x.
Qed.

(* Power predicates *)

Require Import Arith.

(* TODO: can be removed if https://github.com/coq/coq/pull/17013 is merged *)
Lemma iter_add p q (A:Type) (f:A -> A) (x:A):
  Nat.iter (p+q) f x = Nat.iter p f (Nat.iter q f x).
Proof.
  induction p as [|p IHp].
  - reflexivity.
  - simpl. now rewrite IHp.
Qed.

Definition pow X n R : X -> X -> Prop := Nat.iter n (rcomp R) eq.

Lemma pow_add X p q (R: X -> X -> Prop): pow (p + q) R =2 rcomp (pow p R) (pow q R).
Proof.
induction p.
- symmetry. apply rcomp_eq.
Abort.

Definition functional {X Y} (R: X -> Y -> Prop) := forall x y1 y2, R x y1 -> R x y2 -> y1 = y2.
Definition terminal {X Y} (R: X -> Y -> Prop) x := forall y, ~ R x y.

Section FixX.
  Variable X : Type.
  Implicit Types R S : relation X.
  Implicit Types x y z : X.

  (* Reflexive transitive closure *)
  Notation star := clos_refl_trans.

  Arguments star {A}.
  Arguments reflexive {A}.
  Arguments symmetric {A}.
  Arguments transitive {A}.

  Definition evaluates R x y := star R x y /\ terminal R y.

  (* Making first argument a non-uniform parameter doesn't simplify the induction principle. *)

  (* Lemma star_simpl_ind R (p : X -> Prop) *)
  (* use clos_refl_trans_ind_right instead *)

  (* Lemma star_trans *)
  (* use rt_trans *)

  (* Lemma R_star *)
  (* use apply rt_step. *)

  Instance star_PO R: PreOrder (star R).
  Proof.
    constructor.
    - unfold Reflexive. apply rt_refl.
    - unfold Transitive. apply rt_trans.
  Qed.

  (* Power characterization *)
  Lemma star_pow R x y :
    star R x y <-> exists n, pow n R x y.
  Proof.
    split; intros A.
    - induction A as [| | x y z H1 [n1 R1] H2 [n2 R2]].
      + now exists 1, y.
      + now exists 0.
      + exists (n2 + n1).
  Abort.

  Lemma pow_star R x y n:
    pow R n x y -> star R x y.
  Proof.
    intros A. erewrite star_pow. eauto.
  Qed.

  (* Equivalence closure *)

  Inductive ecl R : X -> X -> Prop :=
  | eclR x : ecl R x x
  | eclC x y z : R x y -> ecl R y z -> ecl R x z
  | eclS x y z : R y x -> ecl R y z -> ecl R x z.

  Lemma ecl_trans R :
    transitive (ecl R).
  Proof.
    induction 1; eauto using ecl.
  Qed.

  Lemma ecl_sym R :
    symmetric (ecl R).
  Proof.
    induction 1; eauto using ecl, (@ecl_trans R).
  Qed.

  Lemma star_ecl R :
    star R <=2 ecl R.
  Proof.
    induction 1; eauto using ecl.
  Qed.

  (* Diamond, confluence, Church-Rosser *)

  Definition joinable R x y :=
    exists z, R x z /\ R y z.

  Definition diamond R :=
    forall x y z, R x y -> R x z -> joinable R y z.

  Definition confluent R := diamond (star R).

  Definition semi_confluent R :=
    forall x y z, R x y -> star R x z -> joinable (star R) y z.

  Definition church_rosser R :=
    ecl R <=2 joinable (star R).

  Goal forall R, diamond R -> semi_confluent R.
  Proof.
    intros R A x y z B C.
    revert x C y B.
    refine (star_simpl_ind _ _).
    - intros y C. exists y. eauto using star.
    - intros x x' C D IH y E.
      destruct (A _ _ _ C E) as [v [F G]].
      destruct (IH _ F) as [u [H I]].
      assert (J:= starC G H).
      exists u. eauto using star.
  Qed.

  Lemma diamond_to_semi_confluent R :
    diamond R -> semi_confluent R.
  Proof.
    intros A x y z B C. revert y B.
    induction C as [|x x' z D _ IH]; intros y B.
    - exists y. eauto using star.
             - destruct (A _ _ _ B D) as [v [E F]].
               destruct (IH _ F) as [u [G H]].
               exists u. eauto using star.
  Qed.

  Lemma semi_confluent_confluent R :
    semi_confluent R <-> confluent R.
  Proof.
    split; intros A x y z B C.
    - revert y B.
      induction C as [|x x' z D _ IH]; intros y B.
      + exists y. eauto using star.
               + destruct (A _ _ _ D B) as [v [E F]].
                 destruct (IH _ E) as [u [G H]].
                 exists u. eauto using (@star_trans R).
               - apply (A x y z); eauto using star.
  Qed.

  Lemma diamond_to_confluent R :
    diamond R -> confluent R.
  Proof.
    intros A. apply semi_confluent_confluent, diamond_to_semi_confluent, A.
  Qed.

  Lemma confluent_CR R :
    church_rosser R <-> confluent R.
  Proof.
    split; intros A.
    - intros x y z B C. apply A.
      eauto using (@ecl_trans R), star_ecl, (@ecl_sym R).
    - intros x y B. apply semi_confluent_confluent in A.
      induction B as [x|x x' y C B IH|x x' y C B IH].
      + exists x. eauto using star.
               + destruct IH as [z [D E]]. exists z. eauto using star.
               + destruct IH as [u [D E]].
                 destruct (A _ _ _ C D) as [z [F G]].
                 exists z. eauto using (@star_trans R).
  Qed.


  (* End Semantics Library *)


  (* Uniform confluence and parametrized confluence *)

  Definition uniform_confluent (R : X -> X -> Prop ) := forall s t1 t2, R s t1 -> R s t2 -> t1 = t2 \/ joinable R t1 t2.

  Lemma functional_uc R :
    functional R -> uniform_confluent R.
  Proof.
    intros F ? ? ? H1 H2. left. eapply F. all:eauto.
  Qed.

  Lemma pow_add R n m (s t : X) : pow R (n + m) s t <-> rcomp (pow R n) (pow R m) s t.
  Proof.
    revert m s t; induction n; intros m s t.
    - simpl. split; intros. econstructor. split. unfold pow. simpl. reflexivity. eassumption.
      destruct H as [u [H1 H2]]. unfold pow in H1. simpl in *. subst s. eassumption.
    - simpl in *; split; intros.
      + destruct H as [u [H1 H2]].
        change (it (rcomp R) (n + m) eq) with (pow R (n+m)) in H2.
        rewrite IHn in H2.
        destruct H2 as [u' [A B]]. unfold pow in A.
        econstructor. 
        split. econstructor. repeat split; repeat eassumption. eassumption.
      + destruct H as [u [H1 H2]].
        destruct H1 as [u' [A B]].
        econstructor.  split. eassumption. change (it (rcomp R) (n + m) eq) with (pow R (n + m)).
        rewrite IHn. econstructor. split; eassumption.
  Qed.

  Lemma rcomp_eq (R S R' S' : X -> X -> Prop) (s t : X) : (R =2 R') -> (S =2 S') -> (rcomp R S s t <-> rcomp R' S' s t).
  Proof.
    intros A B.
    split; intros H; destruct H as [u [H1 H2]];
    eapply A in H1; eapply B in H2;
    econstructor; split; eassumption.
  Qed.
  
  Lemma eq_ref : forall (R : X -> X -> Prop), R =2 R.
  Proof.
    split; tauto.
  Qed.
  
  Lemma rcomp_1 (R : X -> X -> Prop): R =2 pow R 1.
  Proof.
    intros s t; split;unfold pow in *; simpl in *; intros H.
    - econstructor. split; eauto.
    - destruct H as [u [H1 H2]]; subst u; eassumption.
  Qed.
   
  Lemma parametrized_semi_confluence (R : X -> X -> Prop) (m : nat) (s t1 t2 : X) :
    uniform_confluent R ->
    pow R m s t1 ->
    R s t2 ->
    exists k l u,
      k <= 1 /\ l <= m /\ pow R k t1 u /\ pow R l t2 u /\ m + k = S l.
  Proof.
    intros unifConfR; revert s t1 t2; induction m; intros s t1 t2 s_to_t1 s_to_t2.
    - unfold pow in s_to_t1. simpl in *. subst s.
      exists 1, 0, t2.
      repeat split; try lia.
      econstructor. split; try eassumption; econstructor.
    - destruct s_to_t1 as [v [s_to_v v_to_t1]].
      destruct (unifConfR _ _ _ s_to_v s_to_t2) as [H | [u [v_to_u t2_to_u]]].
      + subst v. eexists 0, m, t1; repeat split; try lia; eassumption.
      + destruct (IHm _ _ _ v_to_t1 v_to_u) as [k [l [u' H]]].
        eexists k, (S l), u'; repeat split; try lia; try tauto.
        econstructor. split. eassumption. tauto.
  Qed.
  
  Lemma rcomp_comm R m (s t : X) : rcomp R (it (rcomp R) m eq) s t <-> rcomp (it (rcomp R) m eq) R s t.
  Proof.
    split; intros H;
    [rewrite (rcomp_eq s t (rcomp_1 R) (eq_ref _)) in H;
      rewrite (rcomp_eq s t (eq_ref _) (rcomp_1 R)) |
     rewrite (rcomp_eq s t (eq_ref _) (rcomp_1 R)) in H;
       rewrite (rcomp_eq s t (rcomp_1 R) (eq_ref _))];
    change ((it (rcomp R) m eq)) with (pow R m) in *;
    try rewrite <- pow_add in *;
    rewrite Nat.add_comm; eassumption.
  Qed.
  
  Lemma parametrized_confluence (R : X -> X -> Prop) (m n : nat) (s t1 t2 : X) : 
    uniform_confluent R ->
    pow R m s t1 -> 
    pow R n s t2 -> 
    exists k l u,
      k <= n /\ l <= m /\ pow R k t1 u /\ pow R l t2 u /\ m + k = n + l.
  Proof.
    revert n s t1 t2; induction m; intros n s t1 t2 unifConR s_to_t1 s_to_t2.
    - unfold pow in s_to_t1. simpl in s_to_t1. subst s.
      exists n, 0, t2. repeat split; try now lia. eassumption.
    - unfold pow in s_to_t1. simpl in *.
      destruct s_to_t1 as [v [s_to_v v_to_t1]].
      destruct (parametrized_semi_confluence unifConR s_to_t2 s_to_v) as
          [k [l [u [k_lt_1 [l_lt_n [t2_to_u [v_to_u H]]]]]]].
      destruct (IHm _ _ _ _ unifConR v_to_t1 v_to_u) as
          [l'[k'[u'[l'_lt_l [k'_lt_m [t1_to_u' [u_to_u' H2]]]]]]].
      exists l', (k + k'), u'.
      repeat split; try lia. eassumption.
      rewrite pow_add.
      econstructor; split; eassumption.
  Qed.

  Lemma uniform_confluent_noloop R x y:
    uniform_confluent R ->
    star R x y -> (forall y', ~ R y y') ->
    ~exists z k, star R x z /\ pow R (S k) z z.
  Proof.
    intros UC (k0&R0)%star_pow Term (z&k1&R1&RL).
    induction R1 in k0,RL,R0|-*.
    -edestruct parametrized_confluence with (m:=k0) (n:=S k1 + k0) as (i0&i1&?&?&?&?&?&?).
     1,2:eassumption.
     now eapply pow_add;eexists;split;eassumption.
     destruct i0. destruct i1.
     +now lia.
     +destruct H2 as (?&?&_). edestruct Term. eauto.
     +destruct H1 as (?&?&_). edestruct Term. eauto.
    -edestruct parametrized_semi_confluence with (R:=R) (2:= R0) as (i0&?&?&?&?&?&?&?). 1,2:eassumption.
     destruct i0. 2:{ destruct H2 as (?&?&_). edestruct Term. eauto. }
     cbn in H2;inv H2.
     eapply IHR1. all:eauto.
  Qed.
  
 Lemma uc_terminal R x y z n:
    uniform_confluent R ->
    R x y ->
    pow R n x z ->
    terminal R z ->
    exists n' , n = S n' /\ pow R n' y z.
  Proof.
    intros ? ? ? ter. edestruct parametrized_semi_confluence as (k&?&?&?&?&R'&?&?). 1-3:now eauto.
    destruct k as [|].
    -inv R'. rewrite <- plus_n_O in *. eauto.
    -edestruct R' as (?&?&?). edestruct ter. eauto.
  Qed.  

End FixX.
