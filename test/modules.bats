#!/usr/bin/env bats

load test_helper

@test "DNS module should be loadable" {
    source "$DEVBOOST_ROOT/modules/dns.sh"
    type run_dns
}

@test "System mirror module should be loadable" {
    source "$DEVBOOST_ROOT/modules/system_mirror.sh"
    type run_system_mirror
}