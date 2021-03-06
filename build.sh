#!/bin/bash -e
export PATH="$PWD/build/venv/bin:$PWD/build/venv/Scripts:$PATH"
if [[ ! -d "$PWD/build/venv" ]]; then
  echo "virtualenv not ready"
  exit 1
fi

# Install the core packages.
pip install \
  'PyInstaller==3.3.1' \
  'PyYAML==3.13' \
  'Sphinx==1.7.6'

# Install the extensions.
pip install \
  'javasphinx==0.9.15' \
  'recommonmark==0.4.0' \
  'sphinxcontrib-httpdomain==1.7.0' \
  'sphinxcontrib-inlinesyntaxhighlight==0.2' \
  'sphinxcontrib-openapi==0.3.2' \
  'sphinxcontrib-plantuml==0.12' \
  'sphinxcontrib-redoc==1.5.1' \
  'git+https://github.com/shomah4a/sphinxcontrib.youtube.git@404e8f17c2505333a0781a62800c5a8a08ba3c52#egg=sphinxcontrib.youtube' \
  'sphinx-markdown-tables==0.0.8'

# Install the themes.
pip install \
  'sphinx_bootstrap_theme==0.6.5' \
  'sphinx_rtd_theme==0.4.1'

# Apply some patches and recompile the patched files.
PATCH_DIR="$PWD/patches"
if [[ -d build/venv/Lib/site-packages ]]; then
  SITEPKG_DIR="build/venv/Lib/site-packages"
else
  SITEPKG_DIR="build/venv/lib/python3.6/site-packages"
fi
pushd "$SITEPKG_DIR"
if [[ ! -a sphinxcontrib/__init__.py ]]; then
  echo "__import__('pkg_resources').declare_namespace(__name__)" > sphinxcontrib/__init__.py
fi
find "$PATCH_DIR" -name '*.diff' -print -exec patch -p1 -i {} ';'
find . -type d -name '__pycache__' -exec rm -fr {} ';' >/dev/null 2>&1 || true
python -m compileall . >/dev/null 2>&1
popd

# Build the binary.
python -OO -m PyInstaller \
  --noconfirm \
  --console \
  --onefile \
  --distpath build/dist \
  --specpath build \
  --additional-hooks-dir=hooks \
  run_sphinx.py

# Rename the binary.
OS_CLASSIFIER="$(./os_classifier.sh)"
if [[ -f build/dist/run_sphinx.exe ]]; then
  SPHINX_BIN="build/dist/sphinx.$OS_CLASSIFIER.exe"
  mv -v build/dist/run_sphinx.exe "$SPHINX_BIN"
else
  SPHINX_BIN="build/dist/sphinx.$OS_CLASSIFIER"
  mv -v build/dist/run_sphinx "$SPHINX_BIN"
fi

# Generate the SHA256 checksum.
if [[ -x /usr/local/bin/gsha256sum ]]; then
  SHA256SUM_BIN=/usr/local/bin/gsha256sum
else
  SHA256SUM_BIN=sha256sum
fi
"$SHA256SUM_BIN" -b "$SPHINX_BIN" | sed 's/ .*//g' > "$SPHINX_BIN.sha256"
echo "sha256sum: $(cat "$SPHINX_BIN.sha256") ($SPHINX_BIN.sha256)"

# Build a test site with the binary to make sure it really works.
"build/dist/sphinx.$OS_CLASSIFIER" test_site build/test_site
