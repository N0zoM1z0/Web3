# ALL_FOUNDRY_PRODUCTS contains a list of all products that have a foundry
# profile defined and use the Foundry snapshots.
ALL_FOUNDRY_PRODUCTS = ccip functions keystone l2ep llo-feeds operatorforwarder shared workflow data-feeds

# To make a snapshot for a specific product, either set the `FOUNDRY_PROFILE` env var
# or call the target with `FOUNDRY_PROFILE=product`
# When developing with Foundry, you'll most likely already have the env var set
# to run the tests for the product you're working on. In that case, you can just
# call `make snapshot` and it will use the env var.
# env var example
#		export FOUNDRY_PROFILE=llo-feeds
#		make snapshot
# make call example
# 		make FOUNDRY_PROFILE=llo-feeds snapshot
# note make snapshot skips fuzz tests named according to best practices, although forge uses
# a static fuzz seed by default, flaky gas results per platform are still observed.
.PHONY: snapshot
snapshot: ## Make a snapshot for a specific product.
	export FOUNDRY_PROFILE=$(FOUNDRY_PROFILE) && forge snapshot --nmt "test?(Fuzz|Fork|.*_RevertWhen)_.*" --snap gas-snapshots/$(FOUNDRY_PROFILE).gas-snapshot

.PHONY: snapshot-diff
snapshot-diff: ## Make a snapshot for a specific product.
	export FOUNDRY_PROFILE=$(FOUNDRY_PROFILE) && forge snapshot --nmt "test?(Fuzz|Fork|.*_RevertWhen)_.*" --diff gas-snapshots/$(FOUNDRY_PROFILE).gas-snapshot


.PHONY: snapshot-all
snapshot-all: ## Make a snapshot for all products.
	for foundry_profile in $(ALL_FOUNDRY_PRODUCTS) ; do \
		make snapshot FOUNDRY_PROFILE=$$foundry_profile ; \
	done

.PHONY: pnpmdep
pnpmdep: ## Install solidity contract dependencies through pnpm
	 pnpm i

.PHONY: abigen
abigen: ## Build & install abigen.
	../tools/bin/build_abigen

.PHONY: mockery
mockery: $(mockery) ## Install mockery.
	go install github.com/vektra/mockery/v2@v2.52.3

.PHONY: foundry
foundry: ## Install foundry.
	foundryup --install v1.0.0

.PHONY: foundry-refresh
foundry-refresh: foundry
	git submodule deinit -f .
	git submodule update --init --recursive

ccip-precommit: export FOUNDRY_PROFILE=ccip
.PHONY: ccip-precommit
ccip-precommit:
	forge test
	make snapshot
	forge fmt
	pnpm solhint

ccip-lcov: export FOUNDRY_PROFILE=ccip
.PHONY: ccip-lcov
ccip-lcov:
	forge coverage --report lcov
	../tools/ci/ccip_lcov_prune ./lcov.info ./lcov.info.pruned
	genhtml -o report lcov.info.pruned --branch-coverage

data-feeds-precommit: export FOUNDRY_PROFILE=data-feeds
.PHONY: data-feeds-precommit
data-feeds-precommit:
	forge test
	make snapshot
	forge fmt
	make wrappers
	pnpm solhint

# To generate gethwrappers for a specific product, either set the `FOUNDRY_PROFILE`
# env var or call the target with `FOUNDRY_PROFILE=product`
# This uses FOUNDRY_PROFILE, even though it does support non-foundry products. This
# is to improve the workflow for developers working with Foundry, which is the
# recommended way to develop Solidity for CL products.
# env var example
#		export FOUNDRY_PROFILE=llo-feeds
#		make wrappers
# make call example
# 		make FOUNDRY_PROFILE=llo-feeds wrappers
.PHONY: wrappers
wrappers: pnpmdep mockery abigen ## Recompiles solidity contracts and their go wrappers.
	./scripts/native_solc_compile_all_$(FOUNDRY_PROFILE)
	go generate ../core/gethwrappers/$(FOUNDRY_PROFILE)

# This call generates all gethwrappers for all products. It does so based on the
# assumption that native_solc_compile_all contains sub-calls to each product, and
# go_generate does the same.
.PHONY: wrappers-all
wrappers-all: pnpmdep mockery abigen ## Recompiles solidity contracts and their go wrappers.
	# go_generate contains a call to  compile all contracts before generating wrappers
	go generate ../core/gethwrappers/go_generate.go

# Use this to generate compiled JSON artifacts for gauntlet-plus-plus.
# This is currently only used for CCIP.
# example: make artifact-generate contract=LockReleaseTokenPoolAndProxy solcversion=0.8.24 artifactpath=../../gauntlet-plus-plus/packages-ethereum/operations-ccip/src/artifacts/1.5.0/lock-release-token-pool-and-proxy.json
artifact-generate: export FOUNDRY_PROFILE=ccip
.PHONY: artifact-generate
artifact-generate:
	chmod +x ./scripts/generate_compiled_json_ccip.sh
	./scripts/generate_compiled_json_ccip.sh $(contract) $(solcversion) $(artifactpath)


help:
	@echo ""
	@echo "         .__           .__       .__  .__        __"
	@echo "    ____ |  |__ _____  |__| ____ |  | |__| ____ |  | __"
	@echo "  _/ ___\|  |  \\\\\\__  \ |  |/    \|  | |  |/    \|  |/ /"
	@echo "  \  \___|   Y  \/ __ \|  |   |  \  |_|  |   |  \    <"
	@echo "   \___  >___|  (____  /__|___|  /____/__|___|  /__|_ \\"
	@echo "       \/     \/     \/        \/             \/     \/"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
