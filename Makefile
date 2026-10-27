.PHONY: help build test check docs-check run homebrew clean

help:
	@echo "build       Build dist/Remote2Prompt.app using Command Line Tools"
	@echo "test        Run dependency-free core checks (no XCTest/Xcode required)"
	@echo "check       Run checks, build and verify the app, check documentation"
	@echo "docs-check  Verify Agent Note lifecycle, Markdown links and repository hygiene"
	@echo "run         Build and open the native settings window"
	@echo "homebrew    Prepare a local source archive and Homebrew tap"
	@echo "clean       Remove generated .build/ and dist/"

build:
	./scripts/build-app.sh

test:
	./scripts/test.sh

check: test build
	./scripts/verify-app.sh
	$(MAKE) docs-check

docs-check:
	/usr/bin/ruby scripts/check-repository.rb

run: build
	open dist/Remote2Prompt.app

homebrew:
	/usr/bin/ruby scripts/prepare-homebrew.rb

clean:
	rm -rf .build dist
