#!/usr/bin/env bats

load test_helper

@test "detect_system should set OS_NAME and PKG_MANAGER" {
    detect_system
    [ -n "$OS_NAME" ]
    [ -n "$PKG_MANAGER" ]
}

@test "check_network should return reachable or unreachable" {
    result=$(check_network 8.8.8.8)
    [[ "$result" == "reachable" || "$result" == "unreachable" ]]
}

@test "backup_file should create backup and record manifest" {
    local testfile="$BATS_TEST_TMPDIR/test.txt"
    echo "content" > "$testfile"
    run backup_file "$testfile" "test"
    [ -f "$output" ]  # 备份文件存在
    [ -f "$DEVBOOST_MANIFEST" ]
    grep -q "test.txt" "$DEVBOOST_MANIFEST"
}