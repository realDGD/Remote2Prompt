.PHONY: help build test check docs-check privacy-check run homebrew clean

help:
	@echo "build       Build dist/VoiRemote.app using Command Line Tools"
	@echo "test        Run dependency-free core checks (no XCTest/Xcode required)"
	@echo "check       Run checks, build and verify the app, check documentation"
	@echo "docs-check  Verify Agent Note lifecycle, Markdown links and repository hygiene"
	@echo "privacy-check Check tracked source for local paths, device IDs and private files"
	@echo "run         Build and open the native settings window"
	@echo "homebrew    Prepare a local source archive and Homebrew tap"
	@echo "clean       Remove generated .build/ and dist/"

build:
	./scripts/build-app.sh

test:
	./scripts/test.sh

check: test build
	./scripts/verify-app.sh
	./scripts/check-signing-identity.sh
	$(MAKE) docs-check
	$(MAKE) privacy-check

docs-check:
	/usr/bin/ruby scripts/check-repository.rb

privacy-check:
	/usr/bin/ruby scripts/check-publication.rb

run: build
	open dist/VoiRemote.app

homebrew:
	/usr/bin/ruby scripts/prepare-homebrew.rb

clean:
	rm -rf .build dist
