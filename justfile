set dotenv-load := true

# List all available commands
_default:
    @just --list --unsorted

# ----------------------------------------------------------------------
# DEPENDENCIES
# ----------------------------------------------------------------------

# Bootstrap local development environment
@bootstrap:
    hatch env create
    hatch env create dev
    hatch env create docs
    just install

# Setup local environnment (maybe install hatch and setup postgres (create database, etc..))
@setup:
    just bootstrap
    just cmd pre-commit install --install-hooks
    just migrate
    just createsuperuser
    just lint > /dev/null 2>&1 || true

# Install dependencies
@install *ARGS:
    just cmd python --version

# Generate and upgrade dependencies
@upgrade:
    just cmd hatch-pip-compile --upgrade
    just cmd hatch-pip-compile dev --upgrade

# Clean up local development environment
@clean:
    hatch env prune
    rm -f .coverage.*

# ----------------------------------------------------------------------
# TESTING/TYPES
# ----------------------------------------------------------------------

# Run the test suite, generate code coverage, and export html report
@coverage-html: test
    rm -rf htmlcov
    @just cmd python -m coverage html --skip-covered --skip-empty

# Run the test suite, generate code coverage, and print report to stdout
coverage-report: test
    @just cmd python -m coverage report

# Run tests using pytest
@test *ARGS:
    just cmd coverage run -m pytest {{ ARGS }}

# Run mypy on project
@types:
    just cmd python -m mypy .

# Run the django deployment checks
@deploy-checks:
    just dj check --deploy

# ----------------------------------------------------------------------
# DJANGO
# ----------------------------------------------------------------------

# Run a falco command
@falco *COMMAND:
    just cmd falco {{ COMMAND }}

# Run a django management command
@dj *COMMAND:
    just cmd python -m manage {{ COMMAND }}

# Run the django development server
@server:
    just falco work

# Open a Django shell using django-extensions shell_plus command
@shell:
    just dj shell_plus

alias mm := makemigrations

# Generate Django migrations
@makemigrations *APPS:
    just dj makemigrations {{ APPS }}

# Run Django migrations
@migrate *ARGS:
    just dj migrate {{ ARGS }}

# Reset the database
@reset-db:
    just dj reset_db --noinput

alias su := createsuperuser

# Quickly create a superuser with the provided credentials
createsuperuser EMAIL="admin@localhost" PASSWORD="admin":
    @export DJANGO_SUPERUSER_PASSWORD='{{ PASSWORD }}' && just dj createsuperuser --noinput --email "{{ EMAIL }}"

# Generate admin code for a django app
@admin APP:
    just dj admin_generator {{ APP }} | tail -n +2 > pyapp_docker_example/{{ APP }}/admin.py

# ----------------------------------------------------------------------
# DOCS
# ----------------------------------------------------------------------

# Build documentation using Sphinx
@docs-build LOCATION="docs/_build/html":
    sphinx-build docs {{ LOCATION }}

# Install documentation dependencies
@docs-install:
    hatch run docs:python --version

# Serve documentation locally
@docs-serve:
    hatch run docs:sphinx-autobuild docs docs/_build/html --port 8001

# Generate and upgrade documentation dependencies
docs-upgrade:
    just cmd hatch-pip-compile dev --upgrade

# ----------------------------------------------------------------------
# UTILS
# ----------------------------------------------------------------------

# Build a wheel distribution of the project using hatch
buildwheel:
    #!/usr/bin/env sh
    export DEBUG="False"
    just dj tailwind build
    just dj collectstatic --no-input --skip-checks
    just dj compress
    hatch build

# Build a binary distribution of the project using hatch / pyapp
buildbin:
    #!/usr/bin/env sh
    current_version=$(hatch version)
    wheel_path="${PWD}/dist/pyapp_docker_example-${current_version}-py3-none-any.whl"
    [ -f "$wheel_path" ] || { echo "Wheel file does not exist. Please build the wheel first using the 'buildwheel' recipe."; exit 1; }
    export PYAPP_UV_ENABLED="1"
    export PYAPP_PYTHON_VERSION="3.12"
    export PYAPP_FULL_ISOLATION="1"
    export PYAPP_EXPOSE_METADATA="1"
    export PYAPP_PROJECT_NAME="pyapp_docker_example"
    export PYAPP_PROJECT_VERSION="${current_version}"
    export PYAPP_PROJECT_PATH="${wheel_path}"
    export PYAPP_DISTRIBUTION_EMBED="1"
    hatch build -t binary


# Build binary in docker
buildbin-docker:
    mkdir dist || true
    docker build -t build-bin-container . -f deploy/Dockerfile.binary
    docker run -it -v "${PWD}:/app" -w /app --name final-build build-bin-container just build-wheel && just build-bin
    docker cp final-build:/app/dist .
    docker rm -f final-build


# Run a command within the dev environnment
@cmd *ARGS:
    hatch --env dev run {{ ARGS }}

# Run all formatters
@fmt:
    just --fmt --unstable
    hatch fmt --formatter
    just cmd pre-commit run pyproject-fmt -a
    just cmd pre-commit run reorder-python-imports -a
    just cmd pre-commit run djlint-reformat-django -a

# Run pre-commit on all files
@lint:
    hatch --env dev run pre-commit run --all-files

# Bump project version and update changelog
bumpver version:
    #!/usr/bin/env sh
    just cmd bump-my-version bump {{ version }}
    just cmd git-cliff --output CHANGELOG.md
    version = "$(hatch version)"
    git add CHANGELOG.md
    git commit -m "Generate changelog for version ${version}"
    git tag -f "v${version}"
    git push && git push --tags
