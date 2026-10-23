import Base
import ./core.bend as S
import ./LAWS.bend as L

# Eliminate a contradictory Boolean equality without axioms or unsafe code.
def TrueOnly(value: Bool) -> Type:
  match value:
    case True{}:
      Unit
    case False{}:
      Empty

def true_false(e: {True{} == False{} : Bool}) -> Empty:
  %e : TrueOnly(_)
  Unit{}

def L.add_zero(a):
  match a:
    case 0n:
      {==}
    case 1n+p:
      %L.add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def L.add_succ(a, b):
  match a:
    case 0n:
      {==}
    case 1n+p:
      %L.add_succ(p, b) : {2n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def L.add_assoc(a, b, c):
  match a:
    case 0n:
      {==}
    case 1n+p:
      %L.add_assoc(p, b, c) :
        {1n+Nat.add(Nat.add(p, b), c) == 1n+_ : Nat}
      {==}

def L.bump_left(yes, a, b):
  match yes:
    case True{}:
      {==}
    case False{}:
      {==}

def L.bump_right(yes, a, b):
  match yes:
    case True{}:
      L.add_succ(a, b)
    case False{}:
      {==}

def L.zero_le(a):
  match a:
    case 0n:
      {==}
    case 1n+p:
      {==}

def L.flip_false(a, b, e):
  match a b:
    case 0n 0n:
      Empty.absurd({Nat.is_le(0n, 0n) == True{} : Bool}, true_false(e))
    case 0n 1n+bp:
      Empty.absurd({Nat.is_le(1n+bp, 0n) == True{} : Bool}, true_false(e))
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+bp:
      L.flip_false(ap, bp, e)

def L.merge_from(xs, ys, lo, left, e, fx, fy):
  match xs ys left fx fy:
    case Nil{} _ _ _ _:
      fy
    case _ Nil{} _ _ _:
      fx
    case Con{x, xt} Con{y, yt} True{} Tuple{lo_x, sorted_xt} Tuple{lo_y, sorted_yt}:
      (lo_x, L.merge_from(xt, ys, x, S.head_le(xt, ys), {==}, sorted_xt, (e, sorted_yt)))
    case Con{x, xt} Con{y, yt} False{} Tuple{lo_x, sorted_xt} Tuple{lo_y, sorted_yt}:
      (lo_y, L.merge_from(xs, yt, y, S.head_le(xs, yt), {==}, (L.flip_false(x, y, e), sorted_xt), sorted_yt))

def L.merge_count(xs, ys, left, key):
  match xs ys left:
    case Nil{} _ _:
      {==}
    case Con{x, xt} Nil{} _:
      Equal.sym(Nat, Nat.add(L.count(key, xs), 0n), L.count(key, xs), L.add_zero(L.count(key, xs)))
    case Con{x, xt} Con{y, yt} True{}:
      +yes = Nat.is_eq(key, x)
      +a = L.count(key, xt)
      +b = L.count(key, ys)
      +child = S.merge_go(xt, ys, S.head_le(xt, ys))
      Equal.trans(Nat, L.bump(yes, L.count(key, child)), L.bump(yes, Nat.add(a, b)),
        Nat.add(L.bump(yes, a), b),
        Equal.cong(Nat, Nat, n => L.bump(yes, n), L.count(key, child), Nat.add(a, b),
          L.merge_count(xt, ys, S.head_le(xt, ys), key)), L.bump_left(yes, a, b))
    case Con{x, xt} Con{y, yt} False{}:
      +yes = Nat.is_eq(key, y)
      +a = L.count(key, xs)
      +b = L.count(key, yt)
      +child = S.merge_go(xs, yt, S.head_le(xs, yt))
      Equal.trans(Nat, L.bump(yes, L.count(key, child)), L.bump(yes, Nat.add(a, b)),
        Nat.add(a, L.bump(yes, b)),
        Equal.cong(Nat, Nat, n => L.bump(yes, n), L.count(key, child), Nat.add(a, b),
          L.merge_count(xs, yt, S.head_le(xs, yt), key)), L.bump_right(yes, a, b))

def L.carry_count(forest, tree, key):
  match forest:
    case Nil{}:
      {==}
    case Con{S.Gap{}, rest}:
      {==}
    case Con{S.Run{old}, rest}:
      +a = L.tree_count(key, tree)
      +b = L.tree_count(key, old)
      +c = L.forest_count(key, rest)
      Equal.trans(Nat, L.forest_count(key, S.carry(rest, S.Node{tree, old})),
        Nat.add(Nat.add(a, b), c), Nat.add(a, Nat.add(b, c)),
        L.carry_count(rest, S.Node{tree, old}, key), L.add_assoc(a, b, c))

def L.build_count(xs, key):
  match xs:
    case Nil{}:
      {==}
    case Con{x, rest}:
      +yes = Nat.is_eq(key, x)
      +hit = L.bump(yes, 0n)
      +a = L.forest_count(key, S.build(rest))
      +b = L.count(key, rest)
      Equal.trans(Nat, L.forest_count(key, S.build(xs)), Nat.add(hit, b), L.bump(yes, b),
        Equal.trans(Nat, L.forest_count(key, S.build(xs)), Nat.add(hit, a), Nat.add(hit, b),
          L.carry_count(S.build(rest), S.Leaf{x}, key),
          Equal.cong(Nat, Nat, n => Nat.add(hit, n), a, b, L.build_count(rest, key))),
        Equal.sym(Nat, L.bump(yes, b), Nat.add(hit, b), L.bump_left(yes, 0n, b)))

def L.tree_sorted(tree, forks):
  match tree forks:
    case S.Leaf{x} _:
      (L.zero_le(x), Unit{})
    case S.Node{left, right} 0n:
      +a = S.tree_sort(left, 0n)
      +b = S.tree_sort(right, 0n)
      L.merge_from(a, b, 0n, S.head_le(a, b), {==}, L.tree_sorted(left, 0n), L.tree_sorted(right, 0n))
    case S.Node{left, right} 1n+depth:
      +a = S.tree_sort(left, depth)
      +b = S.tree_sort(right, depth)
      L.merge_from(a, b, 0n, S.head_le(a, b), {==}, L.tree_sorted(left, depth), L.tree_sorted(right, depth))

def L.tree_preserves_count(tree, forks, key):
  match tree forks:
    case S.Leaf{x} _:
      {==}
    case S.Node{left, right} 0n:
      +a = S.tree_sort(left, 0n)
      +b = S.tree_sort(right, 0n)
      %L.tree_preserves_count(left, 0n, key) :
        {L.count(key, S.merge(a, b)) == Nat.add(_, L.tree_count(key, right)) : Nat}
      %L.tree_preserves_count(right, 0n, key) :
        {L.count(key, S.merge(a, b)) == Nat.add(L.count(key, a), _) : Nat}
      L.merge_count(a, b, S.head_le(a, b), key)
    case S.Node{left, right} 1n+depth:
      +a = S.tree_sort(left, depth)
      +b = S.tree_sort(right, depth)
      %L.tree_preserves_count(left, depth, key) :
        {L.count(key, S.merge(a, b)) == Nat.add(_, L.tree_count(key, right)) : Nat}
      %L.tree_preserves_count(right, depth, key) :
        {L.count(key, S.merge(a, b)) == Nat.add(L.count(key, a), _) : Nat}
      L.merge_count(a, b, S.head_le(a, b), key)

def L.forest_sorted(forest, forks):
  match forest:
    case Nil{}:
      Unit{}
    case Con{S.Gap{}, rest}:
      L.forest_sorted(rest, forks)
    case Con{S.Run{tree}, rest}:
      +a = S.tree_sort(tree, forks)
      +b = S.forest_sort(rest, forks)
      L.merge_from(a, b, 0n, S.head_le(a, b), {==}, L.tree_sorted(tree, forks), L.forest_sorted(rest, forks))

def L.forest_preserves_count(forest, forks, key):
  match forest:
    case Nil{}:
      {==}
    case Con{S.Gap{}, rest}:
      L.forest_preserves_count(rest, forks, key)
    case Con{S.Run{tree}, rest}:
      +a = S.tree_sort(tree, forks)
      +b = S.forest_sort(rest, forks)
      %L.tree_preserves_count(tree, forks, key) :
        {L.count(key, S.merge(a, b)) == Nat.add(_, L.forest_count(key, rest)) : Nat}
      %L.forest_preserves_count(rest, forks, key) :
        {L.count(key, S.merge(a, b)) == Nat.add(L.count(key, a), _) : Nat}
      L.merge_count(a, b, S.head_le(a, b), key)

def L.sort_is_sorted(xs, forks):
  L.forest_sorted(S.build(xs), forks)

def L.sort_is_permutation(xs, forks, key):
  %L.build_count(xs, key) : {L.count(key, S.sort(xs, forks)) == _ : Nat}
  L.forest_preserves_count(S.build(xs), forks, key)
