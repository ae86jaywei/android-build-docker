#!/bin/bash

# ============================================
# Android Build Docker Image 构建脚本
# ============================================
#
# 用法:
#   ./scripts/build-image.sh [OPTIONS]
#
# 选项:
#   -t, --tag         镜像标签 (默认: android-build:latest)
#   -v, --version     Android SDK 版本 (默认: 34)
#   -n, --ndk         Android NDK 版本 (默认: r26)
#   -g, --gradle      Gradle 版本 (默认: 8.5)
#   -c, --cache       启用构建缓存 (默认: true)
#   -p, --push        推送镜像到注册表
#   -r, --registry    注册表地址 (默认: ghcr.io)
#   -h, --help        显示帮助信息
#
# 示例:
#   ./scripts/build-image.sh
#   ./scripts/build-image.sh -t my-android-build -v 33
#   ./scripts/build-image.sh --tag android-build:1.0.0 --version 34 --push
#
# ============================================

set -e

# 默认值
IMAGE_TAG="android-build:latest"
ANDROID_SDK_VERSION="34"
ANDROID_NDK_VERSION="r26"
GRADLE_VERSION="8.5"
ENABLE_CACHE="true"
PUSH_IMAGE="false"
REGISTRY="ghcr.io"
REPOSITORY=""

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

# 显示帮助信息
show_help() {
    cat << EOF
Android Build Docker Image 构建脚本

用法:
  $0 [OPTIONS]

选项:
  -t, --tag TAG         镜像标签 (默认: android-build:latest)
  -v, --version VERSION Android SDK 版本 (默认: 34)
  -n, --ndk VERSION     Android NDK 版本 (默认: r26)
  -g, --gradle VERSION  Gradle 版本 (默认: 8.5)
  -c, --cache BOOL      启用构建缓存 (默认: true)
  -p, --push            推送镜像到注册表
  -r, --registry REG    注册表地址 (默认: ghcr.io)
  -h, --help            显示帮助信息

示例:
  $0
  $0 -t my-android-build -v 33
  $0 --tag android-build:1.0.0 --version 34 --push

环境变量:
  DOCKER_BUILDKIT       设置为1启用BuildKit (推荐)
  BUILDKIT_PROGRESS      设置为plain或auto控制构建输出
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            -v|--version)
                ANDROID_SDK_VERSION="$2"
                shift 2
                ;;
            -n|--ndk)
                ANDROID_NDK_VERSION="$2"
                shift 2
                ;;
            -g|--gradle)
                GRADLE_VERSION="$2"
                shift 2
                ;;
            -c|--cache)
                ENABLE_CACHE="$2"
                shift 2
                ;;
            -p|--push)
                PUSH_IMAGE="true"
                shift
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
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

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装。请先安装 Docker。"
        exit 1
    fi
    
    log_info "Docker 版本: $(docker --version)"
}

# 检查 BuildKit 是否启用
check_buildkit() {
    if [[ "${DOCKER_BUILDKIT:-1}" != "1" ]]; then
        log_warning "建议启用 BuildKit 以获得更好的构建性能。"
        log_warning "设置环境变量: export DOCKER_BUILDKIT=1"
    fi
}

# 构建镜像
build_image() {
    local build_args=""
    local cache_args=""
    local push_args=""
    
    # 构建参数
    build_args="--build-arg ANDROID_SDK_VERSION=${ANDROID_SDK_VERSION}"
    build_args="${build_args} --build-arg ANDROID_NDK_VERSION=${ANDROID_NDK_VERSION}"
    build_args="${build_args} --build-arg GRADLE_VERSION=${GRADLE_VERSION}"
    
    # 缓存设置
    if [[ "${ENABLE_CACHE}" == "true" ]]; then
        cache_args="--cache-from type=registry,ref=${IMAGE_TAG}"
        cache_args="${cache_args} --cache-to type=inline,mode=max"
        log_info "启用构建缓存"
    else
        log_info "禁用构建缓存"
    fi
    
    # 推送设置
    if [[ "${PUSH_IMAGE}" == "true" ]]; then
        push_args="--push"
        log_info "构建完成后将推送镜像"
    fi
    
    # 完整的镜像标签
    local full_tag="${IMAGE_TAG}"
    if [[ -n "${REGISTRY}" ]] && [[ -n "${REPOSITORY}" ]]; then
        full_tag="${REGISTRY}/${REPOSITORY}/${IMAGE_TAG}"
    elif [[ -n "${REGISTRY}" ]] && [[ "${IMAGE_TAG}" != *"/"* ]]; then
        full_tag="${REGISTRY}/${IMAGE_TAG}"
    fi
    
    log_info "开始构建镜像..."
    log_info "镜像标签: ${full_tag}"
    log_info "Android SDK 版本: ${ANDROID_SDK_VERSION}"
    log_info "Android NDK 版本: ${ANDROID_NDK_VERSION}"
    log_info "Gradle 版本: ${GRADLE_VERSION}"
    
    # 执行构建命令
    docker buildx build \
        --tag "${full_tag}" \
        ${build_args} \
        ${cache_args} \
        ${push_args} \
        --progress=auto \
        .
    
    if [[ $? -eq 0 ]]; then
        log_success "镜像构建成功: ${full_tag}"
        
        # 显示镜像信息
        if [[ "${PUSH_IMAGE}" != "true" ]]; then
            log_info "镜像信息:"
            docker images | grep "${full_tag%%:*}" || true
        fi
    else
        log_error "镜像构建失败"
        exit 1
    fi
}

# 验证构建参数
validate_args() {
    # 验证 Android SDK 版本
    if [[ ! "${ANDROID_SDK_VERSION}" =~ ^[0-9]+$ ]]; then
        log_error "Android SDK 版本必须是数字: ${ANDROID_SDK_VERSION}"
        exit 1
    fi
    
    # 验证 Android NDK 版本
    if [[ ! "${ANDROID_NDK_VERSION}" =~ ^r[0-9]+$ ]]; then
        log_error "Android NDK 版本格式不正确，应为 r<数字>: ${ANDROID_NDK_VERSION}"
        exit 1
    fi
    
    # 验证 Gradle 版本
    if [[ ! "${GRADLE_VERSION}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "Gradle 版本格式不正确: ${GRADLE_VERSION}"
        exit 1
    fi
    
    # 验证缓存参数
    if [[ "${ENABLE_CACHE}" != "true" ]] && [[ "${ENABLE_CACHE}" != "false" ]]; then
        log_error "缓存参数必须是 true 或 false: ${ENABLE_CACHE}"
        exit 1
    fi
}

# 主函数
main() {
    log_info "Android Build Docker Image 构建脚本"
    log_info "====================================="
    
    # 解析参数
    parse_args "$@"
    
    # 验证参数
    validate_args
    
    # 检查依赖
    check_docker
    check_buildkit
    
    # 构建镜像
    build_image
    
    log_success "构建完成！"
}

# 执行主函数
main "$@"