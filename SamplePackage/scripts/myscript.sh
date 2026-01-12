#!/bin/bash
echo "XXHR_TOP: $XXHR_TOP"
cd "$XXHR_TOP/mds"

echo "Working directory: $(pwd)"
echo ""

echo "unzipping zipped_files.zip"
unzip -o -q zipped_files.zip
echo ""

ls -ltra
