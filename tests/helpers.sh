#!/usr/bin/env bash
PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
summarize() { echo ""; echo "Results: $PASS passed, $FAIL failed"; [[ $FAIL -eq 0 ]]; }
