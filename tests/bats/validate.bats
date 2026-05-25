#!/usr/bin/env bats
# tests/bats/validate.bats — input validation rules.

load test_helper

@test "valid_url: accepts https URL" {
  run valid_url "URL" "https://example.com/api"
  [ "$status" -eq 0 ]
}

@test "valid_url: rejects http (insecure)" {
  run valid_url "URL" "http://example.com"
  [ "$status" -ne 0 ]
}

@test "valid_url: rejects empty value" {
  run valid_url "URL" ""
  [ "$status" -ne 0 ]
}

@test "valid_url: rejects whitespace" {
  run valid_url "URL" "https://has space.com"
  [ "$status" -ne 0 ]
}

@test "valid_url: rejects angle brackets" {
  run valid_url "URL" 'https://bad.com/<script>'
  [ "$status" -ne 0 ]
}

@test "valid_url: rejects backtick" {
  run valid_url "URL" 'https://bad.com/`whoami`'
  [ "$status" -ne 0 ]
}

@test "valid_id: accepts numeric" {
  run valid_id "ID" "123456"
  [ "$status" -eq 0 ]
}

@test "valid_id: rejects letters" {
  run valid_id "ID" "abc"
  [ "$status" -ne 0 ]
}

@test "valid_id: rejects mixed" {
  run valid_id "ID" "12a"
  [ "$status" -ne 0 ]
}

@test "valid_key: accepts glc_ prefix" {
  run valid_key "glc_eyJvIjoiMTIzNDUifQ=="
  [ "$status" -eq 0 ]
}

@test "valid_key: rejects non-glc prefix" {
  run valid_key "wrong_prefix_xyz"
  [ "$status" -ne 0 ]
}

@test "valid_key: rejects whitespace" {
  run valid_key "glc_with space"
  [ "$status" -ne 0 ]
}

@test "valid_interval: accepts 5m" {
  run valid_interval "5m"
  [ "$status" -eq 0 ]
}

@test "valid_interval: accepts 1h" {
  run valid_interval "1h"
  [ "$status" -eq 0 ]
}

@test "valid_interval: rejects bare number" {
  run valid_interval "5"
  [ "$status" -ne 0 ]
}

@test "valid_interval: rejects unknown unit" {
  run valid_interval "5y"
  [ "$status" -ne 0 ]
}

@test "valid_timeout: accepts 10" {
  run valid_timeout "10"
  [ "$status" -eq 0 ]
}

@test "valid_timeout: rejects 0" {
  run valid_timeout "0"
  [ "$status" -ne 0 ]
}

@test "valid_timeout: rejects 301 (out of range)" {
  run valid_timeout "301"
  [ "$status" -ne 0 ]
}

@test "calendar_from_interval: 5m -> *:0/5:00" {
  run calendar_from_interval "5m"
  [ "$output" = "*:0/5:00" ]
}

@test "calendar_from_interval: 30s -> seconds form" {
  run calendar_from_interval "30s"
  [ "$output" = "*:*:0/30" ]
}

@test "calendar_from_interval: 1h -> hourly form" {
  run calendar_from_interval "1h"
  [ "$output" = "*-*-* 0/1:00:00" ]
}

@test "calendar_from_interval: rejects bad unit" {
  run calendar_from_interval "5y"
  [ "$status" -ne 0 ]
}
