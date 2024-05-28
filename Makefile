mix          ?= mix
iex          ?= iex


help: Makefile
	@echo
	@echo " Choose a command run in Oak:"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo


## fmt: Format code.
.PHONY: fmt
fmt:
	@echo ">> ============= Format code ============= <<"
	$(mix) format


## fmt_check: Check code format.
.PHONY: fmt_check
fmt_check:
	@echo ">> ============= Check code format ============= <<"
	$(mix) format mix.exs "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}" --check-formatted


## deps: Fetch dependencies
.PHONY: deps
deps:
	@echo ">> ============= Fetch dependencies ============= <<"
	$(mix) deps.get


## test: Test code
.PHONY: test
test:
	@echo ">> ============= Test code ============= <<"
	$(mix) test


## build: Build code
.PHONY: build
build:
	@echo ">> ============= Build code ============= <<"
	-rm -rf _build
	$(mix) compile --warnings-as-errors


## analyze: Analyze code
.PHONY: analyze
analyze:
	@echo ">> ============= Build code ============= <<"
	$(mix) dialyzer


## docs: Build docs
.PHONY: docs
docs:
	@echo ">> ============= Build docs ============= <<"
	MIX_ENV=dev mix docs


## publish: Publish oak
.PHONY: publish
publish:
	@echo ">> ============= Publish oak ============= <<"
	$(mix) hex.publish


## i: Run interactive shell
.PHONY: i
i:
	@echo ">> ============= Interactive shell ============= <<"
	$(iex) -S mix


## ci: Build docs
.PHONY: ci
ci: test
