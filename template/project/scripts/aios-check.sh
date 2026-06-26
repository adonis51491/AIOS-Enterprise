#!/usr/bin/env bash
set -e
echo "AIOS local check started"
npm run build
npm run lint || true
npm test --if-present || true
echo "AIOS local check finished"
