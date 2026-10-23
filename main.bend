import Base
import ./core.bend as S

type Pattern is Data:
  Random{}
  Ascending{}
  Descending{}
  Duplicates{}
  Equal{}

def usage() -> String:
  "Usage:\n  sort values fork_depth [unsigned_number ...]\n  sort bench count seed fork_depth random|sorted|reverse|duplicates|equal\nRuntime option: --threads N before application arguments.\nValues are U32 inputs represented as Nat in the verified sorter; count <= 1048576, fork_depth <= 12."

def bounded(ok: Bool, value: U32, label: String) -> IO(U32):
  match ok:
    case True{}:
      IO.pure(U32, value)
    case False{}:
      IO.die(U32, 2, "Out of range: " ++ label)

def number_result(value: Maybe<&2, U32>, label: String, +max: U32) -> IO(U32):
  match value:
    case None{}:
      IO.die(U32, 2, "Invalid unsigned integer: " ++ label)
    case Some{+n}:
      bounded((n <= max : U32), n, label)

def number(text: String, label: String, max: U32) -> IO(U32):
  number_result(U32.read(text), label, max)

def read_values(args: List<String>) -> IO(List<&2, Nat>):
  match args:
    case Nil{}:
      IO.pure(List<&2, Nat>, [])
    case Con{value, rest}:
      do IO<List<&2, Nat>>:
        value : U32 <- number(value, "value", 4294967295)
        rest : List<&2, Nat> <- read_values(rest)
        return U32.to_nat(value) <> rest

def pattern_result(random: Bool, sorted: Bool, reverse: Bool, duplicates: Bool, equal: Bool) -> IO(Pattern):
  match random sorted reverse duplicates equal:
    case True{} _ _ _ _:
      IO.pure(Pattern, Random{})
    case _ True{} _ _ _:
      IO.pure(Pattern, Ascending{})
    case _ _ True{} _ _:
      IO.pure(Pattern, Descending{})
    case _ _ _ True{} _:
      IO.pure(Pattern, Duplicates{})
    case _ _ _ _ True{}:
      IO.pure(Pattern, Equal{})
    case _ _ _ _ _:
      IO.die(Pattern, 2, "Unknown input pattern")

def read_pattern(+text: String) -> IO(Pattern):
  pattern_result(String.eq(text, "random"), String.eq(text, "sorted"), String.eq(text, "reverse"),
    String.eq(text, "duplicates"), String.eq(text, "equal"))

def next(+state: U32) -> U32:
  +a = U32.xor(state, U32.shln(state, 13n))
  +b = U32.xor(a, U32.shrn(a, 17n))
  U32.xor(b, U32.shln(b, 5n))

def value(pattern: Pattern, state: U32, index: U32, total: U32) -> U32:
  match pattern:
    case Random{}:
      state
    case Ascending{}:
      index
    case Descending{}:
      (total - 1 - index : U32)
    case Duplicates{}:
      (state % 16 : U32)
    case Equal{}:
      17

def generate(left: Nat, +index: U32, +total: U32, +seed: U32,
  +pattern: Pattern, acc: List<&2, Nat>) -> List<&2, Nat>:
  match left:
    case 0n:
      List.reverse(&2, Nat, acc)
    case 1n+rest:
      +state = next(seed)
      item = value(pattern, state, index, total)
      generate(rest, (index + 1 : U32), total, state, pattern, U32.to_nat(item) <> acc)

# Runtime diagnostics, separate from the universal proofs and timed sort.
def digest(xs: List<&2, Nat>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{x, rest}:
      digest(rest, U32.mul(U32.xor(acc, U32.from_nat(x)), 16777619))

def ordered(xs: List<&2, Nat>, +lo: Nat) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+x, rest}:
      Nat.is_le(lo, x) && ordered(rest, x)

def bool_text(value: Bool) -> String:
  match value:
    case True{}:
      "true"
    case False{}:
      "false"

def show_nat(value: Nat) -> String:
  U32.show(U32.from_nat(value))

def values_text(xs: List<&2, Nat>, emit: Bool) -> String:
  match emit:
    case True{}:
      ",\"values\":" ++ List.show(~&2, ~Nat, ~show_nat, xs)
    case False{}:
      ""

def run(+xs: List<&2, Nat>, +forks: U32, emit: Bool) -> IO(Unit):
  do IO<Unit>:
    threads : U32 <- IO.thread_count()
    input_hash : U32 = digest(xs, 2166136261)
    start : Nat <- IO.now()
    +result : List<&2, Nat> = S.sort(xs, U32.to_nat(forks))
    end : Nat <- IO.now()
    IO.print("{\"fork_depth\":" ++ U32.show(forks) ++ ",\"threads\":" ++ U32.show(threads) ++
      ",\"elapsed_ms\":" ++ Nat.show(Nat.sub(end, start)) ++
      ",\"input_hash\":" ++ U32.show(input_hash) ++
      ",\"output_hash\":" ++ U32.show(digest(result, 2166136261)) ++
      ",\"count\":" ++ Nat.show(List.length(&2, Nat, result)) ++
      ",\"ordered\":" ++ bool_text(ordered(result, 0n)) ++ values_text(result, emit) ++ "}")

def values_command(forks: String, args: List<String>) -> IO(Unit):
  do IO<Unit>:
    forks : U32 <- number(forks, "fork_depth", 12)
    xs : List<&2, Nat> <- read_values(args)
    run(xs, forks, True{})

def bench_command(n: String, seed: String, forks: String, pattern: String) -> IO(Unit):
  do IO<Unit>:
    +count : U32 <- number(n, "count", 1048576)
    seed : U32 <- number(seed, "seed", 4294967295)
    forks : U32 <- number(forks, "fork_depth", 12)
    pattern : Pattern <- read_pattern(pattern)
    xs : List<&2, Nat> = generate(U32.to_nat(count), 0, count, U32.or(seed, 1), pattern, [])
    run(xs, forks, False{})

def command(args: List<String>, values: Bool, bench: Bool) -> IO(Unit):
  match args values bench:
    case Con{forks, rest} True{} _:
      values_command(forks, rest)
    case Con{n, Con{seed, Con{forks, Con{pattern, Nil{}}}}} _ True{}:
      bench_command(n, seed, forks, pattern)
    case _ _ _:
      IO.die(Unit, 2, usage())

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case Con{+name, rest}:
      command(rest, String.eq(name, "values"), String.eq(name, "bench"))
    case Nil{}:
      IO.print(usage())

def command_line(args: List<String>) -> IO(Unit):
  match args:
    case Con{program, rest}:
      arguments(rest)
    case Nil{}:
      IO.print(usage())

def main() -> IO(Unit):
  IO.bind(List<String>, Unit, IO.args(), command_line)
