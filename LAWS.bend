import Base
import ./core.bend as S

# Adjacent ordering with a threaded lower bound, not just a Boolean test.
# Sorted(xs) is From(0,xs), since all values are natural numbers.
def From(+lo: Nat, xs: List<&2, Nat>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case Con{+head, rest}:
      {Nat.is_le(lo, head) == True{} : Bool} & From(head, rest)

def bump(yes: Bool, count: Nat) -> Nat:
  match yes:
    case True{}:
      1n+count
    case False{}:
      count

# Occurrence counting, not a checksum: duplicates must be preserved exactly.
def count(+key: Nat, xs: List<&2, Nat>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{head, rest}:
      bump(Nat.is_eq(key, head), count(key, rest))

def tree_count(+key: Nat, tree: S.Tree) -> Nat:
  match tree:
    case S.Leaf{value}:
      bump(Nat.is_eq(key, value), 0n)
    case S.Node{left, right}:
      Nat.add(tree_count(key, left), tree_count(key, right))

def forest_count(+key: Nat, forest: List<&2, S.Slot>) -> Nat:
  match forest:
    case Nil{}:
      0n
    case Con{S.Gap{}, rest}:
      forest_count(key, rest)
    case Con{S.Run{tree}, rest}:
      Nat.add(tree_count(key, tree), forest_count(key, rest))

# Small arithmetic and ordering lemmas used by the actual correctness proofs.
law add_zero:
  for +a: Nat
  {Nat.add(a, 0n) == a : Nat}

law add_succ:
  for +a: Nat
  for +b: Nat
  {1n+Nat.add(a, b) == Nat.add(a, 1n+b) : Nat}

law add_assoc:
  for +a: Nat
  for +b: Nat
  for +c: Nat
  {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}

law bump_left:
  for +yes: Bool
  for +a: Nat
  for +b: Nat
  {bump(yes, Nat.add(a, b)) == Nat.add(bump(yes, a), b) : Nat}

law bump_right:
  for +yes: Bool
  for +a: Nat
  for +b: Nat
  {bump(yes, Nat.add(a, b)) == Nat.add(a, bump(yes, b)) : Nat}

law zero_le:
  for +a: Nat
  {Nat.is_le(0n, a) == True{} : Bool}

law flip_false:
  for +a: Nat
  for +b: Nat
  for e: {Nat.is_le(a, b) == False{} : Bool}
  {Nat.is_le(b, a) == True{} : Bool}

law merge_from:
  for +xs: List<&2, Nat>
  for +ys: List<&2, Nat>
  for +lo: Nat
  for +left: Bool
  for e: {S.head_le(xs, ys) == left : Bool}
  for fx: From(lo, xs)
  for fy: From(lo, ys)
  From(lo, S.merge_go(xs, ys, left))

law merge_count:
  for +xs: List<&2, Nat>
  for +ys: List<&2, Nat>
  for +left: Bool
  for +key: Nat
  {count(key, S.merge_go(xs, ys, left)) == Nat.add(count(key, xs), count(key, ys)) : Nat}

law carry_count:
  for +forest: List<&2, S.Slot>
  for +tree: S.Tree
  for +key: Nat
  {forest_count(key, S.carry(forest, tree)) == Nat.add(tree_count(key, tree), forest_count(key, forest)) : Nat}

law build_count:
  for +xs: List<&2, Nat>
  for +key: Nat
  {forest_count(key, S.build(xs)) == count(key, xs) : Nat}

law tree_sorted:
  for +tree: S.Tree
  for +forks: Nat
  From(0n, S.tree_sort(tree, forks))

law tree_preserves_count:
  for +tree: S.Tree
  for +forks: Nat
  for +key: Nat
  {count(key, S.tree_sort(tree, forks)) == tree_count(key, tree) : Nat}

law forest_sorted:
  for +forest: List<&2, S.Slot>
  for +forks: Nat
  From(0n, S.forest_sort(forest, forks))

law forest_preserves_count:
  for +forest: List<&2, S.Slot>
  for +forks: Nat
  for +key: Nat
  {count(key, S.forest_sort(forest, forks)) == forest_count(key, forest) : Nat}

# Public requirements: universal over arbitrary finite input lists and fork depths.
law sort_is_sorted:
  for +xs: List<&2, Nat>
  for +forks: Nat
  From(0n, S.sort(xs, forks))

law sort_is_permutation:
  for +xs: List<&2, Nat>
  for +forks: Nat
  for +key: Nat
  {count(key, S.sort(xs, forks)) == count(key, xs) : Nat}
