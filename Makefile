OBJ = bignum_add_p25519.o \
      bignum_sub_p25519.o \
      bignum_mul_p25519.o \
      bignum_sqr_p25519.o


.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


.PHONY: test
test: ## Run tests
	go test -v -count=1 ./...


.PHONY: verify-field
verify-field: verify-field-amd64 verify-field-arm64 ## Verify field operations: both amd64 and arm64 assembly output matches s2n-bignum


.PHONY: verify-field-amd64
verify-field-amd64: build-field ## Verify field operations: amd64 assembly output matches s2n-bignum
	@for obj in $(OBJ); do \
		func=$$(basename $$obj .o); \
		echo "Verifying amd64 $$func..."; \
		\
		objdump --disassemble=github.com/AlexanderYastrebov/vanity25519/field.$$func.abi0 --no-show-raw-insn --no-addresses build/field.amd64.test | \
			awk "/$$func.abi0>:/{flag=1; next} flag {print}" | \
			grep -vF 'mov    0x8(%rsp),%rdi' | \
			grep -vF 'mov    0x10(%rsp),%rsi' | \
			grep -vF 'mov    0x18(%rsp),%rdx' | \
			grep -vF 'mov    0x18(%rsp),%rcx' \
		> build/$$func.amd64.go.asm ; \
		\
		objdump -d --no-show-raw-insn --no-addresses ./s2n-bignum/x86/curve25519/$$func.o | \
			awk "/$$func>:/{flag=1; next} flag {print}" | \
			grep -vF 'endbr64' | \
			grep -vF 'mov    %rdx,%rcx' \
		> build/$$func.amd64.s2n.asm ; \
		\
		diff -U3 build/$$func.amd64.go.asm build/$$func.amd64.s2n.asm || { echo "Verification failed for $$func"; exit 1; }; \
	done


.PHONY: verify-field-arm64
verify-field-arm64: build-field ## Verify field operations: arm64 assembly output matches s2n-bignum
	@for obj in $(OBJ); do \
		func=$$(basename $$obj .o); \
		echo "Verifying arm64 $$func..."; \
		\
		aarch64-linux-gnu-objdump --disassemble=github.com/AlexanderYastrebov/vanity25519/field.$$func.abi0 --no-show-raw-insn --no-addresses build/field.arm64.test | \
			awk "/$$func.abi0>:/{flag=1; next} flag {print}" | \
			grep -vF 'ldr	x0, [sp, #8]' | \
			grep -vF 'ldr	x1, [sp, #16]' | \
			grep -vF 'ldr	x2, [sp, #24]' | \
			grep -vF 'udf	#0' | \
			grep -vF '...' \
		> build/$$func.arm64.go.asm ; \
		\
		aarch64-linux-gnu-objdump -d --no-show-raw-insn --no-addresses ./s2n-bignum/arm/curve25519/$$func.o | \
			awk "/$$func>:/{flag=1; next} flag {print}" \
		> build/$$func.arm64.s2n.asm ; \
		\
		diff -U3 build/$$func.arm64.go.asm build/$$func.arm64.s2n.asm || { echo "Verification failed for $$func"; exit 1; }; \
	done


.PHONY: test-field
test-field: build-field ## Run field tests for both amd64 and arm64. Requires qemu-user-static and binfmt-support installed on amd64 host.
	GOARCH=amd64 go test -count=1 ./field
	GOARCH=arm64 go test -count=1 ./field


.PHONY: build-field
build-field: s2n-bignum ## Build field test binaries and s2n-bignum objects
	mkdir -p build
	GOARCH=amd64 go test -c -o build/field.amd64.test ./field
	GOARCH=arm64 go test -c -o build/field.arm64.test ./field


.PHONY: s2n-bignum
s2n-bignum: ## Clone and build s2n-bignum if not already present
	if [ ! -d ./s2n-bignum/ ]; then \
		git clone --depth=1 git@github.com:awslabs/s2n-bignum.git; \
	fi
	make -C s2n-bignum/x86/curve25519/
	make -C s2n-bignum/arm/curve25519/


.PHONY: fmt
fmt: ## Format Go and assembly code
	gofumpt -w .
	asmfmt -w .


.PHONY: clean
clean: ## Clean build artifacts
	rm -rf build/ s2n-bignum/
