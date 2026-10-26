# `make BOX2D_DIR=/path/to/box2d` - generate the header from an existing checkout.
# To run tests:
# * Compile but not link:
#     make run_tests BOX2D_DIR=/path/to/box2d SYNTAX_ONLY=1
# * Compile, link and run:
#     make run_tests BOX2D_DIR=/path/to/box2d FLAGS=-L/path/to/box2d/lib
#       For MSVC, use FLAGS_CL instead of FLAGS.
#   You can set `COMPILERS=...` to only test specific compilers.
#
# Windows users should run this in MSYS2 `make`. To test MSVC, run `msys2_shell.cmd` inside VS developer prompt.

ifeq (OS,Windows_NT)
COMPILERS = clang++ g++ cl clang-cl
else
COMPILERS = clang++ g++
endif

# Compiler flags, for GCC-like compilers and for MSVC-like respectively.
FLAGS :=
FLAGS_CL :=

ifeq ($(wildcard $(BOX2D_DIR)/include/box2d/box2d.h),)
$(error Set BOX2D_DIR to an existing Box2D checkout, e.g. make BOX2D_DIR=../box2d)
endif

# Set to 1 to only compile the tests but don't link.
SYNTAX_ONLY := 0
override SYNTAX_ONLY := $(filter-out 0,$(SYNTAX_ONLY))

# Generate the file.
include/box2cpp/box2cpp.h: $(BOX2D_DIR) $(wildcard $(BOX2D_DIR)/include/box2d/*.h) generator/generate.awk | include test
	$(call, ### Strip the newlines inside parentheses, then give the result to awk.)
	$(call, ### `box2d.h` is the primary header. `types.h` and `joint_types.h` are needed for `b2Default...Def` functions.)
	$(call, ### Yes, `cat` will mangle first/last lines, but it doesn't matter.)
	cat $(BOX2D_DIR)/include/box2d/*.h \
		| perl -pe 'while ((tr/(//) > (tr/)//)) { my $$n = <>; last unless defined $$n; chomp; $$n =~ s/^\s+//; $$_ .= " " . $$n; }' \
		| gawk -vbox2d_dir="$(BOX2D_DIR)" -vsecond_file=tmp.part2 -f generator/generate.awk >include/box2cpp/box2cpp.h
	cat tmp.part2 >>include/box2cpp/box2cpp.h
	rm tmp.part2
	sed 's|<box2d/\(.*\)>|"$(abspath $(BOX2D_DIR))/include/box2d/\1"|' include/box2cpp/box2cpp.h >test/test_header.h

# Directories:
$(strip include) test:
	mkdir -p $@

# Force regeneration.
.PHONY: include/box2cpp/box2cpp.h

.PHONY: generate
generate: include/box2cpp/box2cpp.h

override all_test_targets =
define test_snippet
.PHONY: test_$1
test_$1: include/box2cpp/box2cpp.h
	MSYS2_ARG_CONV_EXCL=* LANG= $1 test/test.cpp $(if $(filter %cl,$1)\
		,/nologo /EHsc /std:c++latest /W4 /WX \
			$(if $(SYNTAX_ONLY),/Zs,/link -lbox2d '/out:test/test_$1.exe') \
			$(FLAGS_CL) \
		,-std=c++20 -I"$(BOX2D_DIR)/include" -Wall -Wextra -pedantic-errors -Wconversion -Wextra-semi -Wdeprecated -Werror -g \
			$(if $(filter windows,$(TARGET_OS)),,-fsanitize=address -fsanitize=undefined) \
			$(if $(SYNTAX_ONLY),-fsyntax-only,-lbox2d -o 'test/test_$1') \
			$(FLAGS) \
	)
	$(if $(SYNTAX_ONLY),,'test/test_$1')
	@echo 'Test passed on: $1'
	@rm -f test.obj

$(eval override all_test_targets += test_$1)
endef

$(foreach c,$(COMPILERS),\
	$(if $(shell command -v $c 2>/dev/null),$(eval $(call test_snippet,$c)))\
)

.PHONY: run_tests
run_tests: $(all_test_targets)

.DEFAULT_GOAL := generate
