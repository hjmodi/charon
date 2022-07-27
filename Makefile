PYTHON ?= python3.8
OFFICIAL ?= no
CHROMIUM_BIN=/tmp/chrome-linux/chrome
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
VERSION := $(shell $(PYTHON) setup.py --version)

VENV_BASE ?= /var/lib/charon/venv

# Python packages to install only from source (not from binary wheels)
# Comma separated list
SRC_ONLY_PKGS ?= cffi,pycparser,psycopg2,twilio
# These should be upgraded in the Charon venv before attempting
# to install the actual requirements
VENV_BOOTSTRAP ?= pip setuptools wheel

NAME ?= charon

# TAR build parameters
SDIST_TAR_NAME=$(NAME)-$(VERSION)

SDIST_COMMAND ?= sdist
SDIST_TAR_FILE ?= $(SDIST_TAR_NAME).tar.gz

.PHONY: clean clean-tmp clean-venv requirements requirements_dev \
	develop refresh adduser migrate dbchange \
	receiver test test_unit test_coverage coverage_html \
	dev_build release_build sdist \
	VERSION PYTHON_VERSION docker-compose-sources \
	.git/hooks/pre-commit

clean-tmp:
	rm -rf tmp/

clean-venv:
	rm -rf venv/

clean-dist:
	rm -rf dist

# Remove temporary build files, compiled Python files.
clean: clean-dist clean-tmp clean-venv

# convenience target to assert environment variables are defined
guard-%:
	@if [ "$${$*}" = "" ]; then \
	    echo "The required environment variable '$*' is not set"; \
	    exit 1; \
	fi

virtualenv: virtualenv_charon

# flit is needed for offline install of certain packages, specifically ptyprocess
# it is needed for setup, but not always recognized as a setup dependency
# similar to pip, setuptools, and wheel, these are all needed here as a bootstrapping issues
virtualenv_charon:
	if [ "$(VENV_BASE)" ]; then \
		if [ ! -d "$(VENV_BASE)" ]; then \
			mkdir $(VENV_BASE); \
		fi; \
		if [ ! -d "$(VENV_BASE)/charon" ]; then \
			$(PYTHON) -m venv $(VENV_BASE)/charon; \
			$(VENV_BASE)/charon/bin/pip install $(PIP_OPTIONS) $(VENV_BOOTSTRAP); \
		fi; \
	fi

# Install third-party requirements needed for charon's environment.
# this does not use system site packages intentionally
requirements_charon: virtualenv_charon
	$(VENV_BASE)/charon/bin/pip install -r requirements.txt

requirements_charon_dev:
	$(VENV_BASE)/charon/bin/pip install -r requirements-dev.txt

requirements: requirements_charon

requirements_dev: requirements_charon requirements_charon_dev

# "Install" charon package in development mode.
develop:
	@if [ "$(VIRTUAL_ENV)" ]; then \
	    pip uninstall -y charon; \
	    $(PYTHON) setup.py develop; \
	else \
	    pip uninstall -y charon; \
	    $(PYTHON) setup.py develop; \
	fi

version_file:
	mkdir -p /var/lib/charon/; \
	if [ "$(VENV_BASE)" ]; then \
		. $(VENV_BASE)/charon/bin/activate; \
	fi; \
	$(PYTHON) -c "import charon; print(charon.__version__)" > /var/lib/charon/.charon_version; \

# Refresh development environment after pulling new code.
refresh: clean requirements_dev version_file develop migrate

.git/hooks/pre-commit:
	@echo "if [ -x pre-commit.sh ]; then" > .git/hooks/pre-commit
	@echo "    ./pre-commit.sh;" >> .git/hooks/pre-commit
	@echo "fi" >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit


HEADLESS ?= no
ifeq ($(HEADLESS), yes)
dist/$(SDIST_TAR_FILE):
else
dist/$(SDIST_TAR_FILE): $(UI_BUILD_FLAG_FILE)
endif
	$(PYTHON) setup.py $(SDIST_COMMAND)
	ln -sf $(SDIST_TAR_FILE) dist/charon.tar.gz

sdist: dist/$(SDIST_TAR_FILE)
	echo $(HEADLESS)
	@echo "#############################################"
	@echo "Artifacts:"
	@echo dist/$(SDIST_TAR_FILE)
	@echo "#############################################"

VERSION:
	@echo "charon: $(VERSION)"

PYTHON_VERSION:
	@echo "$(PYTHON)" | sed 's:python::'

print-%:
	@echo $($*)
