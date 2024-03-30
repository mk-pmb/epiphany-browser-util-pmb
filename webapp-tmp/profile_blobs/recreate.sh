#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function recreate_blobs () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$SELFPATH" || return $?

  local LSE="$HOME/.local/share/epiphany"
  local ORIG= BFN= VAL=
  for ORIG in "$LSE"/[a-z]*.*; do
    [ -f "$ORIG" ] || continue
    BFN="$(basename -- "$ORIG")"
    case "$BFN" in
      *'~'* ) continue;;
    esac
    VAL="$(head --bytes=16 -- "$ORIG" | tr -s '\r\n\000' ' ')"
    case "$VAL" in
      'SQLite format 3 ' ) recreate_sqlite_blob || return $?;;
    esac
  done
}


function sqlite3_one_cmd () {
  sqlite3 -bail -batch -cmd "$1" -cmd .quit -- "$2"
}


function dump_sqlite3_schema () {
  sqlite3_one_cmd .fullschema "$1" | sed -rf "$SELFPATH"/nicer_sqlite.sed
}


function recreate_sqlite_blob () {
  echo -n "create $BFN from $ORIG: "
  local SCHEMA="$BFN.schema.txt"
  dump_sqlite3_schema "$ORIG" >"$SCHEMA" || return 4$(
    echo E: "Failed to dump schema from: $ORIG" >&2)
  local EXPECT='CREATE TABLE '
  head --lines=1 -- "$SCHEMA" | grep -qPe "^$EXPECT" || return 4$(
    echo E: "Expected schema file to start with '$EXPECT' in: $SCHEMA" >&2)
  local CLEAN=tmp."${BFN%.sqlite}.sqlite"
  >"$CLEAN" || return $?
  sqlite3 -bail -batch "$CLEAN" <"$SCHEMA" || return $?$(
    echo E: "Failed to create $CLEAN from $SCHEMA" >&2)

  local DIFF=tmp."$BFN".diff
  diff -U 9009009 --label "Schema of $CLEAN" -- <(
    dump_sqlite3_schema "$CLEAN") "$SCHEMA" || return 4$(
    echo E: "Schema verification failed for: $CLEAN" >&2)

  local TBL="$(sqlite3_one_cmd .tables "$CLEAN" | grep -oPe '\w+')"
  local ROWS=
  [ -n "$TBL" ] || return 4$(echo E: "Found no tables in: $CLEAN" >&2)
  for TBL in $TBL; do
    ROWS="$(sqlite3_one_cmd "SELECT COUNT(1) FROM $TBL;" "$CLEAN")"
    [ "$ROWS" == 0 ] || return 4$(
      echo E: "Failed to verify that table '$TBL' is empty in: $CLEAN" >&2)
  done

  gzip <"$CLEAN" >"$BFN".gz || return 4$(echo E: "Failed to gzip: $CLEAN" >&2)
  rm -- "$CLEAN" || return 4$(echo E: "Failed to delete: $CLEAN" >&2)
  echo 'ok.'
}










recreate_blobs "$@"; exit $?
