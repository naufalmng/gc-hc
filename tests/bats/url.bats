#!/usr/bin/env bats
# tests/bats/url.bats — URL parsing helpers.

load test_helper

@test "host_from_url: bare https host" {
  run host_from_url "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "example.com" ]
}

@test "host_from_url: with path" {
  run host_from_url "https://prom-prod-01.grafana.net/api/prom/push"
  [ "$output" = "prom-prod-01.grafana.net" ]
}

@test "host_from_url: with explicit port" {
  run host_from_url "https://logs.example.com:8443/loki/api/v1/push"
  [ "$output" = "logs.example.com" ]
}

@test "host_from_url: empty input fails" {
  run host_from_url "https://"
  [ "$status" -ne 0 ]
}

@test "port_from_url: defaults to 443" {
  run port_from_url "https://example.com/foo"
  [ "$output" = "443" ]
}

@test "port_from_url: explicit port preserved" {
  run port_from_url "https://example.com:9999/foo"
  [ "$output" = "9999" ]
}

@test "prom_query_url: rewrites push to buildinfo" {
  run prom_query_url "https://prom.example.com/api/prom/push"
  [ "$output" = "https://prom.example.com/api/prom/api/v1/status/buildinfo" ]
}

@test "prom_query_url: trims trailing slash" {
  run prom_query_url "https://example.com/foo/"
  [ "$output" = "https://example.com/foo" ]
}

@test "prom_query_url: passthrough for non-push URLs" {
  run prom_query_url "https://example.com/api/v1/query"
  [ "$output" = "https://example.com/api/v1/query" ]
}
