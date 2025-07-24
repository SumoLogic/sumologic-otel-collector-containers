.PHONY: all
all: lint

.PHONY: lint
lint: check-lint-dependencies
lint:
	@echo "Running linters..."
	@actionlint

.PHONY: check-lint-dependencies
check-lint-dependencies:
	@echo "Checking required dependencies..."
	@command -v actionlint >/dev/null 2>&1 || { echo >&2 "actionlint is required but not installed. Aborting."; exit 1; }
	@echo "All required dependencies are installed."
