#!/usr/bin/env bash
# Add CITATION.cff, LICENSE placeholder (if missing), release workflow and README DOI placeholder.
# Usage:
#   1) Create repo_list.txt with full repo names (owner/repo), one per line.
#   2) Run: ./add-metadata-and-workflow.sh repo_list.txt
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 repo_list.txt"
  exit 1
fi

LIST="$1"

while IFS= read -r REPO_FULL; do
  echo ""
  echo "=== Adding files to ${REPO_FULL} ==="
  TMPDIR=$(mktemp -d)
  cd "${TMPDIR}"
  git clone "git@github.com:${REPO_FULL}.git" repo
  cd repo

  REPO_NAME=$(basename "$(pwd)")

  # Add CITATION.cff (if not present)
  if [ ! -f CITATION.cff ]; then
    cat > CITATION.cff <<EOF
cff-version: 1.2.0
title: "${REPO_NAME}"
version: "0.1.0"
authors:
  - family-names: "Grinstead"
    given-names: "Liam"
    affiliation: "RenderedFrameTheory / RFTSystems"
date-released: "$(date -I)"
url: "https://github.com/${REPO_FULL}"
message: "This repository is archived on Zenodo; update the doi field after Zenodo mints the DOI."
doi: ""
EOF
    git add CITATION.cff
  else
    echo "CITATION.cff already exists, skipping."
  fi

  # Ensure LICENSE exists (if HF mirror already included it it will be present)
  if [ ! -f LICENSE ]; then
    cat > LICENSE <<'EOF'
[PLEASE COPY THE LICENSE TEXT FROM THE CORRESPONDING HUGGING FACE SPACE here.
Example: visit the HF space URL and open the LICENSE file, then paste it here.]
EOF
    git add LICENSE
  else
    echo "LICENSE already present, leaving existing LICENSE."
  fi

  # Add workflow
  mkdir -p .github/workflows
  if [ ! -f .github/workflows/create-release-on-tag.yml ]; then
    cat > .github/workflows/create-release-on-tag.yml <<'EOF'
# Creates a GitHub Release automatically when you push a tag that starts with "v"
on:
  push:
    tags:
      - 'v*'

jobs:
  create_release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: ${{ github.ref_name }}
          name: Release ${{ github.ref_name }}
          body: "Automated release for tag ${{ github.ref_name }}. Zenodo (if enabled) will archive this release."
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF
    git add .github/workflows/create-release-on-tag.yml
  else
    echo "Workflow already exists, skipping."
  fi

  # Add README DOI placeholder if README exists; otherwise create one
  if [ -f README.md ]; then
    # Add DOI placeholder only if not already present
    if ! grep -q "DOI:" README.md; then
      cat >> README.md <<'EOF'

DOI: https://doi.org/<PUT_YOUR_DOI_HERE>
[![DOI](https://zenodo.org/badge/DOI/YOUR_DOI_HERE.svg)](https://doi.org/YOUR_DOI_HERE)
EOF
      git add README.md
    else
      echo "README contains DOI info already, skipping."
    fi
  else
    cat > README.md <<EOF
# ${REPO_NAME}

Code and files from the Hugging Face Space ${REPO_NAME}.
DOI: https://doi.org/<PUT_YOUR_DOI_HERE>
[![DOI](https://zenodo.org/badge/DOI/YOUR_DOI_HERE.svg)](https://doi.org/YOUR_DOI_HERE)
EOF
    git add README.md
  fi

  # Commit & push
  git commit -m "Add CITATION.cff, LICENSE placeholder, release workflow, and README DOI placeholder" || echo "Nothing to commit"
  git push origin HEAD

  cd -
  rm -rf "${TMPDIR}"
done < "${LIST}"

echo ""
echo "Metadata & workflow added to all repos."