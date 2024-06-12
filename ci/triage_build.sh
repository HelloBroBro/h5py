#!/bin/bash

set -eo pipefail

if [[ "$1" == "" ]] || [[ "$2" == "" ]]; then
    echo "Usage: $0 <ARCH> <SHA>"
    exit 1
fi

ARCH=$1
SHA=$2
MSG="$(git show -s --format=%s $SHA)"
KIND="$RUNNER_OS $ARCH"
CIBW_BUILD=""

# If it's a PR, and aarch64 architecture, and no [aarch64] in the commit message, just build and test one aarch64 wheel with one tox config
if [[ "$ARCH" == "aarch64" ]]; then
    echo "Limiting aarch64 test set for speed"
    echo "TOX_TEST_LIMITED=1" | tee -a $GITHUB_ENV
    if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]] && [[ "$MSG" != *'[aarch64]'* ]]; then
        echo "Building limited $KIND wheels for PR with commit message: $MSG"
        CIBW_BUILD="cp312-*_$ARCH"
    fi
fi
if [[ "$CIBW_BUILD" == "" ]]; then
    echo "Building full $KIND wheels on event_name=$GITHUB_EVENT_NAME with commit message: $MSG"
    CIBW_BUILD="*_$ARCH"
fi
CIBW_SKIP="pp* *musllinux*"
# If it's a scheduled build or [pip-pre] in commit message, use pip-pre
if [[ "$GITHUB_EVENT_NAME" == "schedule" ]] || [[ "$MSG" = *'[pip-pre]'* ]]; then
    echo "Using NumPy pip-pre wheel for wheel building, setting CIBW_BEFORE_BUILD and CIBW_BUILD_FRONTEND"
    # No Python 3.9 or 3.10 on scientific-python-nightly-wheels
    CIBW_SKIP="$CIBW_SKIP cp38-* cp39-*"
    echo "CIBW_BEFORE_BUILD=pip install --pre --only-binary numpy --extra-index-url https://pypi.anaconda.org/scientific-python-nightly-wheels/simple \"numpy>=2.1.0.dev0\" \"Cython>=0.29.31,<4\" pkgconfig \"setuptools>=61\" wheel" | tee -a $GITHUB_ENV
    echo "CIBW_BUILD_FRONTEND=pip; args: --no-build-isolation" | tee -a $GITHUB_ENV
fi
echo "CIBW_BUILD=$CIBW_BUILD" | tee -a $GITHUB_ENV
echo "CIBW_SKIP=$CIBW_SKIP" | tee -a $GITHUB_ENV
