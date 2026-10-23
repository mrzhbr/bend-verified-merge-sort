import Base

# A merge sort over arbitrary lists of natural numbers. No unsafe recursion,
# foreign comparison, trusted sort primitive or pre-sorted-input assumption.
def head_le(xs: List<&2, Nat>, ys: List<&2, Nat>) -> Bool:
  match xs ys:
    case Con{x, xt} Con{y, yt}:
      Nat.is_le(x, y)
    case _ _:
      True{}

# The flag lets Bend match a parameter instead of a computed comparison.
# Recursive calls decrease xs, or keep xs and decrease ys (lexicographic).
def merge_go(+xs: List<&2, Nat>, +ys: List<&2, Nat>, left: Bool) -> List<&2, Nat>:
  match xs:
    case Nil{}:
      ys
    case Con{x, xt}:
      match ys:
        case Nil{}:
          xs
        case Con{y, yt}:
          match left:
            case True{}:
              x <> merge_go(xt, ys, head_le(xt, ys))
            case False{}:
              y <> merge_go(xs, yt, head_le(xs, yt))

def merge(+xs: List<&2, Nat>, +ys: List<&2, Nat>) -> List<&2, Nat>:
  merge_go(xs, ys, head_le(xs, ys))

type Tree is Data:
  Leaf{value: Nat}
  Node{left: Tree, right: Tree}

type Slot is Data:
  Gap{}
  Run{tree: Tree}

# Binary carrying creates balanced power-of-two runs. The forest, not the
# growing tree, is the decreasing recursive argument.
def carry(forest: List<&2, Slot>, tree: Tree) -> List<&2, Slot>:
  match forest:
    case Nil{}:
      [Run{tree}]
    case Con{Gap{}, rest}:
      Run{tree} <> rest
    case Con{Run{old}, rest}:
      Gap{} <> carry(rest, Node{tree, old})

# Build from right to left, retaining input order within runs.
def build(xs: List<&2, Nat>) -> List<&2, Slot>:
  match xs:
    case Nil{}:
      []
    case Con{x, rest}:
      carry(build(rest), Leaf{x})

# The cutoff controls scheduling only, not the sorting algorithm.
def tree_sort(tree: Tree, +forks: Nat) -> List<&2, Nat>:
  match tree:
    case Leaf{x}:
      [x]
    case Node{left, right}:
      match forks:
        case 0n:
          a = tree_sort(left, 0n)
          b = tree_sort(right, 0n)
          merge(a, b)
        case 1n+depth:
          a b = tree_sort(left, depth) tree_sort(right, depth)
          merge(a, b)

# Runs are processed in input order; each nontrivial tree can use all workers.
def forest_sort(forest: List<&2, Slot>, +forks: Nat) -> List<&2, Nat>:
  match forest:
    case Nil{}:
      []
    case Con{Gap{}, rest}:
      forest_sort(rest, forks)
    case Con{Run{tree}, rest}:
      a = tree_sort(tree, forks)
      b = forest_sort(rest, forks)
      merge(a, b)

def sort(xs: List<&2, Nat>, forks: Nat) -> List<&2, Nat>:
  forest_sort(build(xs), forks)
