PYTHON ?= python3.6
VERSION := $(shell $(PYTHON) setup.py --version)

VENV_BASE ?= /var/lib/charon/venv

VENV_BOOTSTRAP ?= pip==21.3.1 setuptools==59.6.0 wheel==0.37.1

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

virtualenv:
	if [ "$(VENV_BASE)" ]; then \
		if [ ! -d "$(VENV_BASE)" ]; then \
			mkdir $(VENV_BASE); \
		fi; \
		if [ ! -d "$(VENV_BASE)/charon" ]; then \
			$(PYTHON) -m venv $(VENV_BASE)/charon; \
			$(VENV_BASE)/charon/bin/pip install $(PIP_OPTIONS) $(VENV_BOOTSTRAP); \
			$(VENV_BASE)/charon/bin/pip config set global.index https://repository.engineering.redhat.com/nexus/repository/pypi.org/pypi; \
			$(VENV_BASE)/charon/bin/pip config set global.index_url https://repository.engineering.redhat.com/nexus/repository/pypi.org/simple; \
			$(VENV_BASE)/charon/bin/pip config set global.trusted-host repository.engineering.redhat.com; \
		fi; \
	fi

# Install third-party requirements needed for charon's environment.
# this does not use system site packages intentionally
requirements_charon: virtualenv
	$(VENV_BASE)/charon/bin/pip install -r requirements.txt

requirements_charon_dev: virtualenv
	$(VENV_BASE)/charon/bin/pip install -r requirements-dev.txt

requirements: requirements_charon

requirements_dev: requirements_charon requirements_charon_dev

dist/$(SDIST_TAR_FILE): $(UI_BUILD_FLAG_FILE)
	$(PYTHON) setup.py $(SDIST_COMMAND)

sdist: dist/$(SDIST_TAR_FILE)
	@echo "#############################################"
	@echo "Artifacts:"
	@echo dist/$(SDIST_TAR_FILE)
	@echo "#############################################"
