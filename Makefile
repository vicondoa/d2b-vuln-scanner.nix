.PHONY: check test test-unit test-shell test-fixtures test-nix test-policy test-nixling-discovery

check: test

test: test-unit

test-unit: test-shell test-fixtures test-nix test-policy test-nixling-discovery

test-shell:
	shellcheck bin/d2b-vuln-*

test-fixtures:
	bash tests/test-scan-report.sh
	bash tests/test-status-adapters.sh
	bash tests/test-open.sh
	bash tests/test-remediate.sh

test-nix:
	nix flake check --no-build --all-systems

test-policy:
	bash tests/test-policy.sh

test-nixling-discovery:
	bash tests/test-nixling-discovery.sh
