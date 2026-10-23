.DEFAULT_GOAL := build
BEND ?= .tools/bend/bin/bend
PYTHON ?= python3
THREADS ?= 4

.PHONY: setup check proof build test bench clean

setup:
	bash scripts/setup.sh

$(BEND):
	bash scripts/setup.sh

check: $(BEND)
	"$(BEND)" main.bend --check-only

proof: $(BEND)
	$(PYTHON) -m tools.proof_gate --bend "$(BEND)" --record results/proof-check.json

build: build/sort

build/sort: main.bend core.bend $(BEND) | proof
	mkdir -p build
	"$(BEND)" main.bend -o "$@"

test: check build
	$(PYTHON) -m tools.test_sort

bench: build
	$(PYTHON) -m tools.benchmark --bend "$(BEND)" --threads "$(THREADS)"

clean:
	rm -rf build
