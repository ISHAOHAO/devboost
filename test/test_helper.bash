#!/usr/bin/env bash

setup() {
    # 加载公共库
    load_lib() {
        source "$BATS_TEST_DIRNAME/../lib/common.sh"
        source "$BATS_TEST_DIRNAME/../lib/detect.sh"
    }
    load_lib

    # 设置测试环境变量
    export DEVBOOST_ROOT="$BATS_TEST_DIRNAME/.."
    export DEVBOOST_BACKUP_DIR="$BATS_TEST_TMPDIR/backups"
    export DEVBOOST_LOG_DIR="$BATS_TEST_TMPDIR/logs"
    export DEVBOOST_LOG_FILE="$DEVBOOST_LOG_DIR/devboost.log"
    export DEVBOOST_MANIFEST="$DEVBOOST_BACKUP_DIR/manifest.txt"
    mkdir -p "$DEVBOOST_BACKUP_DIR" "$DEVBOOST_LOG_DIR"
}