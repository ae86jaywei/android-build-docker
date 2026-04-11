#!/bin/bash

# ============================================
# Android 编译环境验证脚本
# ============================================
#
# 验证 Docker 镜像中的 Android 编译环境是否完整。
# 检查所有必需的工具和依赖是否已正确安装和配置。
#
# 退出码:
#   0: 环境正常
#   1: 缺少必需依赖
#   2: 配置错误
#   3: 版本不匹配
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

# 检查结果
PASS=0
FAIL=0
WARN=0

# 检查命令是否存在
check_command() {
    local cmd="$1"
    local name="$2"
    local required="${3:-true}"
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>/dev/null | head -n1)
        log_success "$name: $version"
        ((PASS++))
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_error "$name: 未找到命令 '$cmd'"
            ((FAIL++))
            return 1
        else
            log_warning "$name: 可选命令 '$cmd' 未找到"
            ((WARN++))
            return 0
        fi
    fi
}

# 检查目录是否存在
check_directory() {
    local dir="$1"
    local name="$2"
    local required="${3:-true}"
    
    if [[ -d "$dir" ]]; then
        log_success "$name: 目录存在 ($dir)"
        ((PASS++))
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_error "$name: 目录不存在 ($dir)"
            ((FAIL++))
            return 1
        else
            log_warning "$name: 可选目录不存在 ($dir)"
            ((WARN++))
            return 0
        fi
    fi
}

# 检查环境变量
check_env_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    local name="$2"
    local required="${3:-true}"
    
    if [[ -n "$var_value" ]]; then
        log_success "$name: $var_value"
        ((PASS++))
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_error "$name: 环境变量 $var_name 未设置"
            ((FAIL++))
            return 1
        else
            log_warning "$name: 可选环境变量 $var_name 未设置"
            ((WARN++))
            return 0
        fi
    fi
}

# 检查文件是否存在
check_file() {
    local file="$1"
    local name="$2"
    local required="${3:-true}"
    
    if [[ -f "$file" ]]; then
        log_success "$name: 文件存在 ($file)"
        ((PASS++))
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_error "$name: 文件不存在 ($file)"
            ((FAIL++))
            return 1
        else
            log_warning "$name: 可选文件不存在 ($file)"
            ((WARN++))
            return 0
        fi
    fi
}

# 检查版本
check_version() {
    local cmd="$1"
    local pattern="$2"
    local name="$3"
    local min_version="$4"
    
    if command -v "$cmd" &> /dev/null; then
        local version_output=$($cmd --version 2>/dev/null | head -n1)
        local version=$(echo "$version_output" | grep -o "$pattern" | head -n1)
        
        if [[ -n "$version" ]]; then
            log_success "$name: $version"
            
            # 检查最小版本要求
            if [[ -n "$min_version" ]]; then
                # 简单的版本比较（仅支持 x.y.z 格式）
                local current_num=$(echo "$version" | sed 's/[^0-9.]//g')
                local min_num=$(echo "$min_version" | sed 's/[^0-9.]//g')
                
                # 使用 sort -V 进行版本比较
                if [[ $(printf "%s\n%s" "$current_num" "$min_num" | sort -V | head -n1) == "$min_num" ]]; then
                    log_success "$name: 版本满足要求 (>= $min_version)"
                else
                    log_warning "$name: 版本可能过低 (当前: $version, 要求: >= $min_version)"
                    ((WARN++))
                fi
            fi
            
            ((PASS++))
            return 0
        else
            log_warning "$name: 无法获取版本信息"
            ((WARN++))
            return 0
        fi
    else
        log_error "$name: 命令 '$cmd' 未找到"
        ((FAIL++))
        return 1
    fi
}

# 检查系统信息
check_system_info() {
    log_info "检查系统信息..."
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_success "操作系统: $NAME $VERSION"
        ((PASS++))
    else
        log_warning "无法确定操作系统信息"
        ((WARN++))
    fi
    
    # 检查内核版本
    check_command "uname" "内核版本" false
    
    # 检查架构
    local arch=$(uname -m)
    log_success "系统架构: $arch"
    ((PASS++))
}

# 检查基础工具
check_basic_tools() {
    log_info "检查基础工具..."
    
    check_command "bash" "Bash"
    check_command "git" "Git"
    check_command "curl" "cURL"
    check_command "wget" "Wget"
    check_command "unzip" "Unzip"
    check_command "make" "Make"
    check_command "python3" "Python 3"
}

# 检查 Java 环境
check_java_env() {
    log_info "检查 Java 环境..."
    
    check_env_var "JAVA_HOME" "JAVA_HOME"
    check_directory "$JAVA_HOME" "JAVA_HOME 目录"
    
    if [[ -n "$JAVA_HOME" ]]; then
        check_file "$JAVA_HOME/bin/java" "Java 可执行文件"
        check_version "java" "[0-9]+\.[0-9]+\.[0-9]+" "Java 版本" "17"
    fi
}

# 检查 Android 环境
check_android_env() {
    log_info "检查 Android 环境..."
    
    check_env_var "ANDROID_HOME" "ANDROID_HOME"
    check_directory "$ANDROID_HOME" "ANDROID_HOME 目录"
    
    if [[ -n "$ANDROID_HOME" ]]; then
        # 检查 SDK 工具
        check_file "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "SDK Manager"
        check_file "$ANDROID_HOME/platform-tools/adb" "ADB"
        
        # 检查平台工具
        check_directory "$ANDROID_HOME/platforms" "Android 平台目录" false
        check_directory "$ANDROID_HOME/build-tools" "Android 构建工具目录" false
        
        # 检查环境变量是否在 PATH 中
        if echo "$PATH" | grep -q "$ANDROID_HOME"; then
            log_success "ANDROID_HOME 在 PATH 中"
            ((PASS++))
        else
            log_warning "ANDROID_HOME 不在 PATH 中"
            ((WARN++))
        fi
    fi
    
    # 检查 NDK
    check_env_var "ANDROID_NDK_HOME" "ANDROID_NDK_HOME"
    if [[ -n "$ANDROID_NDK_HOME" ]]; then
        check_directory "$ANDROID_NDK_HOME" "ANDROID_NDK_HOME 目录"
        
        # 检查 NDK 工具
        check_file "$ANDROID_NDK_HOME/ndk-build" "NDK Build" false
        check_file "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" "NDK Clang" false
    fi
}

# 检查构建工具
check_build_tools() {
    log_info "检查构建工具..."
    
    check_command "gradle" "Gradle"
    check_version "gradle" "[0-9]+\.[0-9]+(\.[0-9]+)?" "Gradle 版本" "8.5"
    
    check_command "ccache" "ccache"
    check_version "ccache" "[0-9]+\.[0-9]+(\.[0-9]+)?" "ccache 版本" "4.0"
    
    check_command "ninja" "Ninja"
    check_version "ninja" "[0-9]+\.[0-9]+(\.[0-9]+)?" "Ninja 版本" "1.10"
    
    check_command "repo" "Repo 工具"
}

# 检查编译工具链
check_compiler_toolchain() {
    log_info "检查编译工具链..."
    
    check_command "gcc" "GCC"
    check_version "gcc" "[0-9]+\.[0-9]+\.[0-9]+" "GCC 版本" "11.0"
    
    check_command "g++" "G++"
    check_version "g++" "[0-9]+\.[0-9]+\.[0-9]+" "G++ 版本" "11.0"
    
    check_command "clang" "Clang"
    check_version "clang" "[0-9]+\.[0-9]+\.[0-9]+" "Clang 版本" "14.0"
    
    check_command "clang++" "Clang++"
    check_version "clang++" "[0-9]+\.[0-9]+\.[0-9]+" "Clang++ 版本" "14.0"
}

# 检查 Python 包
check_python_packages() {
    log_info "检查 Python 包..."
    
    local packages=("protobuf" "six" "future" "psutil" "colorama" "requests")
    
    for pkg in "${packages[@]}"; do
        if python3 -c "import $pkg" 2>/dev/null; then
            local version=$(python3 -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "unknown")
            log_success "Python 包: $pkg ($version)"
            ((PASS++))
        else
            log_warning "Python 包: $pkg 未安装"
            ((WARN++))
        fi
    done
}

# 检查工作目录权限
check_workspace_permissions() {
    log_info "检查工作目录权限..."
    
    local workspace="/workspace"
    local ccache_dir="/ccache"
    
    if [[ -d "$workspace" ]]; then
        if [[ -w "$workspace" ]]; then
            log_success "工作目录可写: $workspace"
            ((PASS++))
        else
            log_error "工作目录不可写: $workspace"
            ((FAIL++))
        fi
    else
        log_warning "工作目录不存在: $workspace"
        ((WARN++))
    fi
    
    if [[ -d "$ccache_dir" ]]; then
        if [[ -w "$ccache_dir" ]]; then
            log_success "ccache 目录可写: $ccache_dir"
            ((PASS++))
        else
            log_error "ccache 目录不可写: $ccache_dir"
            ((FAIL++))
        fi
    else
        log_warning "ccache 目录不存在: $ccache_dir"
        ((WARN++))
    fi
}

# 生成报告
generate_report() {
    log_info "====================================="
    log_info "环境验证报告"
    log_info "====================================="
    log_info "通过: $PASS"
    log_info "警告: $WARN"
    log_info "失败: $FAIL"
    log_info "总计: $((PASS + WARN + FAIL))"
    log_info "====================================="
    
    if [[ $FAIL -gt 0 ]]; then
        log_error "环境验证失败: 有 $FAIL 个必需项未通过"
        return 1
    elif [[ $WARN -gt 0 ]]; then
        log_warning "环境验证通过，但有 $WARN 个警告"
        return 0
    else
        log_success "环境验证完全通过！"
        return 0
    fi
}

# 主函数
main() {
    log_info "Android 编译环境验证脚本"
    log_info "开始验证环境..."
    log_info "====================================="
    
    # 执行所有检查
    check_system_info
    check_basic_tools
    check_java_env
    check_android_env
    check_build_tools
    check_compiler_toolchain
    check_python_packages
    check_workspace_permissions
    
    log_info "====================================="
    
    # 生成报告
    generate_report
    local exit_code=$?
    
    log_info "验证完成。"
    exit $exit_code
}

# 执行主函数
main "$@"