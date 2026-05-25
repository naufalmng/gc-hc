#!/usr/bin/env bats
# tests/bats/utils.bats — utility helpers (trim, json_escape, mask).

load test_helper

@test "trim: removes leading and trailing spaces" {
  run trim "  hello  "
  [ "$output" = "hello" ]
}

@test "trim: removes carriage returns" {
  run trim "$(printf 'hello\r')"
  [ "$output" = "hello" ]
}

@test "trim: empty input returns empty" {
  run trim ""
  [ "$output" = "" ]
}

@test "json_escape: escapes double quotes" {
  run json_escape 'say "hi"'
  [ "$output" = 'say \"hi\"' ]
}

@test "json_escape: escapes backslashes" {
  run json_escape 'C:\path'
  [ "$output" = 'C:\\path' ]
}

@test "json_escape: escapes newlines" {
  run json_escape "$(printf 'line1\nline2')"
  [ "$output" = 'line1\nline2' ]
}

@test "json_escape: empty input returns empty" {
  run json_escape ""
  [ "$output" = "" ]
}

@test "mask: empty value renders <empty>" {
  run mask ""
  [ "$output" = "<empty>" ]
}

@test "mask: short value fully obscured" {
  run mask "tinykey"
  [ "$output" = "********" ]
}

@test "mask: long value shows 6 prefix + 4 suffix" {
  run mask "glc_eyJvIjoiMTIzNDUifQwxyz"
  [ "$output" = "glc_ey...wxyz" ]
}
