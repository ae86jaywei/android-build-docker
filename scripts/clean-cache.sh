#!/bin/bash

# ============================================
# Android 编译缓存清理脚本
# ============================================
#
# 清理编译缓存，包括:
#   - ccache 缓存
#   - Gradle 缓存
#   - Android 构建缓存
#   - 临时文件
#
# 用法:
#   ./scripts/clean-cache.sh [OPTIONS]
#
# 选项:
#   -a, --all         清理所有缓存（默认）
#   -c, --ccache      仅清理 ccache 缓存
#   -g, --gradle      仅清理 Gradle 缓存
#   -d, --android     仅清理 Android 构建缓存
#   -t, --temp        仅清理临时文件
#   -s, --stats       显示缓存统计信息（不清理）
#   -h, --help        显示帮助信息
#
# 示例:
#   ./scripts/clean-cache.sh              # 清理所有缓存
#   ./scripts/clean-cache.sh --ccache     # 仅清理 ccache 缓存
#   ./scripts/clean-cache.sh --stats      # 显示缓存统计
#
# ============================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 缓存目录
CCACHE_DIR="${CCACHE_DIR:-/ccache}"
GRADLE_CACHE_DIR="${HOME:-/home/builder}/.gradle/caches"
ANDROID_CACHE_DIR="${HOME:-/home/builder}/.android/build-cache"
TEMP_DIRS="/tmp /var/tmp"

# 清理模式
CLEAN_ALL=true
CLEAN_CCACHE=false
CLEAN_GRADLE=false
CLEAN_ANDROID=false
CLEAN_TEMP=false
SHOW_STATS=false

# 统计信息
TOTAL_SIZE_BEFORE=0
TOTAL_SIZE_AFTER=0
FILES_REMOVED=0
DIRS_REMOVED=0

# 显示帮助信息
show_help() {
    cat << EOF
Android 编译缓存清理脚本

清理编译缓存，包括 ccache、Gradle、Android 构建缓存和临时文件。

用法:
  $0 [OPTIONS]

选项:
  -a, --all          清理所有缓存（默认）
  -c, --ccache       仅清理 ccache 缓存
  -g, --gradle       仅清理 Gradle 缓存
  -d, --android      仅清理 Android 构建缓存
  -t, --temp         仅清理临时文件
  -s, --stats        显示缓存统计信息（不清理）
  -h, --help         显示帮助信息

示例:
  $0                    # 清理所有缓存
  $0 --ccache           # 仅清理 ccache 缓存
  $0 --gradle --android # 清理 Gradle 和 Android 缓存
  $0 --stats            # 显示缓存统计

环境变量:
  CCACHE_DIR           ccache 缓存目录（默认: /ccache）
  GRADLE_USER_HOME     Gradle 用户目录（默认: ~/.gradle）
  ANDROID_SDK_ROOT     Android SDK 根目录
EOF
}

# 解析命令行参数
parse_args() {
    # 如果没有参数，使用默认模式（清理所有）
    if [[ $# -eq 0 ]]; then
        CLEAN_ALL=true
        return
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                CLEAN_ALL=true
                shift
                ;;
            -c|--ccache)
                CLEAN_CCACHE=true
                CLEAN_ALL=false
                shift
                ;;
            -g|--gradle)
                CLEAN_GRADLE=true
                CLEAN_ALL=false
                shift
                ;;
            -d|--android)
                CLEAN_ANDROID=true
                CLEAN_ALL=false
                shift
                ;;
            -t|--temp)
                CLEAN_TEMP=true
                CLEAN_ALL=false
                shift
                ;;
            -s|--stats)
                SHOW_STATS=true
                CLEAN_ALL=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 计算目录大小
get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# 格式化文件大小
format_size() {
    local size="$1"
    if [[ $size -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif [[ $size -ge 1048576 ]]; then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    elif [[ $size -ge 1024 ]]; then
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    else
        echo "${size} B"
    fi
}

# 显示缓存统计
show_cache_stats() {
    log_info "缓存统计信息"
    log_info "====================================="
    
    # ccache 统计
    if command -v ccache &> /dev/null; then
        log_info "ccache 统计:"
        ccache -s 2>/dev/null | grep -E "(cache directory|cache hit rate|files in cache|cache size)" || true
        echo ""
    else
        log_warning "ccache 未安装"
    fi
    
    # Gradle 缓存统计
    if [[ -d "$GRADLE_CACHE_DIR" ]]; then
        local gradle_size=$(get_dir_size "$GRADLE_CACHE_DIR")
        log_info "Gradle 缓存: $(format_size $gradle_size)"
    else
        log_info "Gradle 缓存目录不存在: $GRADLE_CACHE_DIR"
    fi
    
    # Android 缓存统计
    if [[ -d "$ANDROID_CACHE_DIR" ]]; then
        local android_size=$(get_dir_size "$ANDROID_CACHE_DIR")
        log_info "Android 构建缓存: $(format_size $android_size)"
    else
        log_info "Android 构建缓存目录不存在: $ANDROID_CACHE_DIR"
    fi
    
    # 临时文件统计
    local temp_size=0
    for temp_dir in $TEMP_DIRS; do
        if [[ -d "$temp_dir" ]]; then
            local dir_size=$(get_dir_size "$temp_dir")
            temp_size=$((temp_size + dir_size))
        fi
    done
    log_info "临时文件: $(format_size $temp_size)"
    
    log_info "====================================="
}

# 清理 ccache 缓存
clean_ccache() {
    log_info "清理 ccache 缓存..."
    
    if command -v ccache &> /dev/null; then
        local size_before=$(get_dir_size "$CCACHE_DIR")
        
        # 显示当前统计
        log_info "清理前 ccache 统计:"
        ccache -s 2>/dev/null | head -20 || true
        
        # 清理缓存
        ccache -C 2>/dev/null || true
        
        # 显示清理后统计
        log_info "清理后 ccache 统计:"
        ccache -s 2>/dev/null | head -20 || true
        
        local size_after=$(get_dir_size "$CCACHE_DIR")
        local size_diff=$((size_before - size_after))
        
        log_success "ccache 缓存清理完成，释放空间: $(format_size $size_diff)"
        
        TOTAL_SIZE_BEFORE=$((TOTAL_SIZE_BEFORE + size_before))
        TOTAL_SIZE_AFTER=$((TOTAL_SIZE_AFTER + size_after))
    else
        log_warning "ccache 未安装，跳过清理"
    fi
}

# 清理 Gradle 缓存
clean_gradle() {
    log_info "清理 Gradle 缓存..."
    
    if [[ -d "$GRADLE_CACHE_DIR" ]]; then
        local size_before=$(get_dir_size "$GRADLE_CACHE_DIR")
        local file_count=0
        local dir_count=0
        
        # 清理特定目录
        local gradle_dirs=(
            "$GRADLE_CACHE_DIR/transforms"
            "$GRADLE_CACHE_DIR/jars"
            "$GRADLE_CACHE_DIR/modules-2/files-2.1"
            "$GRADLE_CACHE_DIR/wrapper"
        )
        
        for dir in "${gradle_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                local dir_files=$(find "$dir" -type f | wc -l)
                local dir_dirs=$(find "$dir" -type d | wc -l)
                
                rm -rf "$dir"/*
                ((file_count += dir_files))
                ((dir_count += dir_dirs))
                
                log_info "清理目录: $dir"
            fi
        done
        
        local size_after=$(get_dir_size "$GRADLE_CACHE_DIR")
        local size_diff=$((size_before - size_after))
        
        log_success "Gradle 缓存清理完成，释放空间: $(format_size $size_diff)，删除文件: $file_count，删除目录: $dir_count"
        
        TOTAL_SIZE_BEFORE=$((TOTAL_SIZE_BEFORE + size_before))
        TOTAL_SIZE_AFTER=$((TOTAL_SIZE_AFTER + size_after))
        FILES_REMOVED=$((FILES_REMOVED + file_count))
        DIRS_REMOVED=$((DIRS_REMOVED + dir_count))
    else
        log_info "Gradle 缓存目录不存在: $GRADLE_CACHE_DIR"
    fi
}

# 清理 Android 构建缓存
clean_android() {
    log_info "清理 Android 构建缓存..."
    
    if [[ -d "$ANDROID_CACHE_DIR" ]]; then
        local size_before=$(get_dir_size "$ANDROID_CACHE_DIR")
        local file_count=$(find "$ANDROID_CACHE_DIR" -type f | wc -l)
        local dir_count=$(find "$ANDROID_CACHE_DIR" -type d | wc -l)
        
        rm -rf "$ANDROID_CACHE_DIR"/*
        
        local size_after=$(get_dir_size "$ANDROID_CACHE_DIR")
        local size_diff=$((size_before - size_after))
        
        log_success "Android 构建缓存清理完成，释放空间: $(format_size $size_diff)，删除文件: $file_count，删除目录: $dir_count"
        
        TOTAL_SIZE_BEFORE=$((TOTAL_SIZE_BEFORE + size_before))
        TOTAL_SIZE_AFTER=$((TOTAL_SIZE_AFTER + size_after))
        FILES_REMOVED=$((FILES_REMOVED + file_count))
        DIRS_REMOVED=$((DIRS_REMOVED + dir_count))
    else
        log_info "Android 构建缓存目录不存在: $ANDROID_CACHE_DIR"
    fi
}

# 清理临时文件
clean_temp() {
    log_info "清理临时文件..."
    
    local total_files=0
    local total_dirs=0
    local total_size=0
    
    for temp_dir in $TEMP_DIRS; do
        if [[ -d "$temp_dir" ]]; then
            log_info "清理临时目录: $temp_dir"
            
            # 查找并清理旧文件（超过7天）
            local old_files=$(find "$temp_dir" -type f -mtime +7 2>/dev/null | wc -l)
            local old_dirs=$(find "$temp_dir" -type d -empty -mtime +7 2>/dev/null | wc -l)
            
            # 计算清理前大小
            local dir_size_before=0
            if [[ $old_files -gt 0 ]] || [[ $old_dirs -gt 0 ]]; then
                dir_size_before=$(find "$temp_dir" -type f -mtime +7 -exec du -cb {} + 2>/dev/null | tail -1 | cut -f1 || echo "0")
            fi
            
            # 清理旧文件
            if [[ $old_files -gt 0 ]]; then
                find "$temp_dir" -type f -mtime +7 -delete 2>/dev/null || true
            fi
            
            # 清理空目录
            if [[ $old_dirs -gt 0 ]]; then
                find "$temp_dir" -type d -empty -mtime +7 -delete 2>/dev/null || true
            fi
            
            total_files=$((total_files + old_files))
            total_dirs=$((total_dirs + old_dirs))
            total_size=$((total_size + dir_size_before))
            
            log_info "清理 $temp_dir: 删除 $old_files 个文件，$old_dirs 个目录"
        fi
    done
    
    if [[ $total_files -gt 0 ]] || [[ $total_dirs -gt 0 ]]; then
        log_success "临时文件清理完成，释放空间: $(format_size $total_size)，删除文件: $total_files，删除目录: $total_dirs"
        
        TOTAL_SIZE_BEFORE=$((TOTAL_SIZE_BEFORE + total_size))
        FILES_REMOVED=$((FILES_REMOVED + total_files))
        DIRS_REMOVED=$((DIRS_REMOVED + total_dirs))
    else
        log_info "没有找到需要清理的临时文件"
    fi
}

# 显示清理摘要
show_cleanup_summary() {
    log_info "====================================="
    log_info "清理摘要"
    log_info "====================================="
    
    local total_freed=$((TOTAL_SIZE_BEFORE - TOTAL_SIZE_AFTER))
    
    log_info "释放总空间: $(format_size $total_freed)"
    log_info "删除文件数: $FILES_REMOVED"
    log_info "删除目录数: $DIRS_REMOVED"
    
    if [[ $total_freed -gt 0 ]]; then
        log_success "缓存清理完成！"
    else
        log_info "没有需要清理的缓存。"
    fi
    
    log_info "====================================="
}

# 确认清理操作
confirm_cleanup() {
    if [[ "$SHOW_STATS" == "true" ]]; then
        return 0
    fi
    
    log_warning "即将清理缓存，此操作不可逆！"
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消。"
        exit 0
    fi
}

# 主函数
main() {
    log_info "Android 编译缓存清理脚本"
    log_info "====================================="
    
    # 解析参数
    parse_args "$@"
    
    # 如果只显示统计信息
    if [[ "$SHOW_STATS" == "true" ]]; then
        show_cache_stats
        exit 0
    fi
    
    # 确认清理操作
    confirm_cleanup
    
    # 根据模式执行清理
    if [[ "$CLEAN_ALL" == "true" ]]; then
        log_info "清理所有缓存..."
        clean_ccache
        clean_gradle
        clean_android
        clean_temp
    else
        [[ "$CLEAN_CCACHE" == "true" ]] && clean_ccache
        [[ "$CLEAN_GRADLE" == "true" ]] && clean_gradle
        [[ "$CLEAN_ANDROID" == "true" ]] && clean_android
        [[ "$CLEAN_TEMP" == "true" ]] && clean_temp
    fi
    
    # 显示清理摘要
    show_cleanup_summary
    
    log_info "清理完成。"
}

# 执行主函数
main "$@"