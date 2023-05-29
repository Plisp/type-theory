open import logic
open import types

{-
  random proofs
-}

-- double negation translation
lem : {P : Set} → ((P ＋ (P → ⊥)) → ⊥) → ⊥
lem f = f (inr (λ p → f (inl p)))

-- contradiction leads to bottom
data Bad : ℕ → Set where
  badt : ⊤ → Bad 0
  badf : ⊥ → Bad 1

destroy : Bad 1 → ⊥
destroy (badf void) = void

negation : (0 ≡ 1) → ⊥
negation eq = destroy ((J Bad eq) (badt ⋆))

-- proof boilerplate
begin_ : {A : Set} → {x y : A} → x ≡ y → x ≡ y
begin p = p
infix 1 begin_

_end : {A : Set} → (x : A) → x ≡ x
x end = refl x
infix 3 _end

_=⟨_⟩_ : {A : Set} → (x : A) → {y z : A}
       → x ≡ y → y ≡ z → x ≡ z
x =⟨ p ⟩ q = trans p q
infixr 2 _=⟨_⟩_

_=⟨⟩_ : {A : Set} → (x : A) → {y : A} → x ≡ y → x ≡ y
x =⟨⟩ q = x =⟨ refl x ⟩ q
infixr 2 _=⟨⟩_

-- commutativity of addition
_+_ : ℕ → ℕ → ℕ
zero    + b = b
(suc a) + b = suc (a + b)

_*_ : ℕ → ℕ → ℕ
zero    * b = zero
(suc a) * b = b + (a * b)

add-commutes0 : (n : ℕ) → (n + 0) ≡ n
add-commutes0 0 =
  begin
    0 + 0 =⟨⟩ 0
  end
add-commutes0 (suc n) =
  begin
                                  suc n  + 0
    =⟨⟩                           suc (n + 0)
    =⟨ ap suc (add-commutes0 n) ⟩ suc n        -- induction hypothesis
  end

add-commutes-sucr : (m n : ℕ) → suc (m + n) ≡ (m + suc n)
add-commutes-sucr 0 n =
  begin
        suc (0 + n)
    =⟨⟩ suc n
    =⟨⟩ 0 + suc n
  end
add-commutes-sucr (suc m) n =
  begin
                                        suc (suc m  + n)
    =⟨⟩                                 suc (suc (m + n))
    =⟨ ap suc (add-commutes-sucr m n) ⟩ suc (m + suc n)
    =⟨⟩                                 suc m  + suc n
  end

add-commutes : (m n : ℕ) → (m + n) ≡ (n + m)
add-commutes 0 n =
  begin
                               0 + n
    =⟨⟩                        n
    =⟨ sym (add-commutes0 n) ⟩ n + 0
  end
add-commutes (suc m) n =
  begin
                                   suc m  + n
    =⟨⟩                            suc (m + n)
    =⟨ ap suc (add-commutes m n) ⟩ suc (n + m)
    =⟨ add-commutes-sucr n m ⟩     n + suc m
  end

-- multiples
data Multiple : ℕ → ℕ → Set where
  div-zero : (k : ℕ) → Multiple k 0
  div-suck : {n k : ℕ} → Multiple k n → Multiple k (n + k) -- oops!

test-multiple : Multiple 3 6
test-multiple = div-suck (div-suck (div-zero 3))

div-coe : {a b k : ℕ} → Multiple k (a + b) → Multiple k (b + a)
div-coe {a} {b} {k} m = J (Multiple k) (add-commutes a b) m

div-four→div-two : {n : ℕ} → Multiple 4 n → Multiple 2 n
div-four→div-two (div-zero .4) = div-zero 2
div-four→div-two (div-suck {k} {4} p) =
  (div-coe {4} {k}
   (div-coe {2 + k} {2}
    (div-suck {2 + k} {2}
     (div-coe {k} {2}
      (div-suck {k} {2} (div-four→div-two p))))))

-- bounded vectors
data Vec (A : Set) : ℕ → Set where
  []   : Vec A zero
  _∷_ : {n : ℕ} → A → Vec A n → Vec A (suc n)

length : {A : Set} {n : ℕ} → Vec A n → ℕ
length {_} {n} _ = n

_!!_ : {A : Set} {n : ℕ} → Vec A n → Fin n → A
(a ∷ as) !! fz   = a
(a ∷ as) !! fs b = as !! b

-- compile-time tests !
test-len : (length (1 ∷ 2 ∷ [])) ≡ 2
test-len = refl 2

_++_ : {A : Set} {x y : ℕ} → Vec A x → Vec A y → Vec A (x + y)
[]        ++ bs = bs
(a ∷ as) ++ bs = a ∷ (as ++ bs)

-- functor laws for A -> Vec A n
map : {A B : Set} {n : ℕ} → (f : A → B) → Vec A n → Vec B n
map f []        = []
map f (a ∷ as) = (f a) ∷ (map f as)

map-id : {A : Set} {n : ℕ} (xs : Vec A n) → (map id xs) ≡ xs
map-id [] =
  begin
    map id [] =⟨⟩ []
  end
map-id (x ∷ xs) =
  begin
                               map id (x ∷ xs)
    =⟨⟩                        (id x) ∷ (map id xs)
    =⟨⟩                        x ∷ (map id xs)
    =⟨ ap (x ∷_) (map-id xs) ⟩ x ∷ xs
  end

map-compose : {A B C : Set} {n : ℕ} (f : B → C) (g : A → B) (xs : Vec A n)
            → map (f ∘ g) xs ≡ map f (map g xs)
map-compose f g [] =
  begin
        map (f ∘ g) []
    =⟨⟩ []
    =⟨⟩ map f []
    =⟨⟩ map f (map g [])
  end
map-compose f g (x ∷ xs) =
  begin
                                              map (f ∘ g) (x ∷ xs)
    =⟨⟩                                       (f ∘ g) x ∷ map (f ∘ g) xs
    =⟨⟩                                       f (g x) ∷ map (f ∘ g) xs
    =⟨ ap (f (g x) ∷_) (map-compose f g xs) ⟩ f (g x) ∷ map f (map g xs)
    =⟨⟩                                       map f ((g x) ∷ map g xs)
    =⟨⟩                                       map f (map g (x ∷ xs))
  end
