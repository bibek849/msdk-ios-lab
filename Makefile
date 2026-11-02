.PHONY: check swift-test python-test docs-check replay handoff

EXPERIMENT ?= experiments/example-synthetic.json
OUT ?= artifacts/handoff

check: swift-test python-test docs-check replay

swift-test:
	swift test

python-test:
	python3 -m unittest discover -s tools/tests -v

docs-check:
	python3 tools/check_repository.py

replay:
	swift run msdk-ios-replay

handoff:
	python3 tools/prepare_handoff.py --experiment "$(EXPERIMENT)" --output "$(OUT)"
