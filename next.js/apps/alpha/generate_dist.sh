#!/usr/bin/env bash

set -o pipefail -o errexit -o nounset # -o xtrace -o verbose

################################################################################
#
# Generates a standalone dist folder for Next.js Applications
#
# Notes:
#
#   next.config.js must have `output` set to `standalone`.
#
################################################################################

NEXT_DIR=$1
NEXT_PUBLIC_DIR=$2
DIST_DIR=$3

echo "NEXT_DIR: $NEXT_DIR"
echo "NEXT_PUBLIC_DIR: $NEXT_PUBLIC_DIR"
echo "DIST_DIR: $DIST_DIR"

if [ ! -d "$NEXT_DIR" ]; then
  echo "Error: .next directory does not exist"
  exit 1
fi

if [ ! -d "$NEXT_PUBLIC_DIR" ]; then
  echo "Error: public directory does not exist"
  exit 1
fi

cp -rf "$NEXT_DIR/standalone/" "$DIST_DIR"
cp -rf "$NEXT_DIR/static/" "$DIST_DIR/.next/static"
cp -rf "$NEXT_PUBLIC_DIR/" "$DIST_DIR/public"
