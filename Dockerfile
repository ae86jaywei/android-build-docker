# ============================================
# Android Build Docker Image
# ============================================
# 
# 这是一个用于 Android 系统和应用程序编译的 Docker 镜像。
# 基于 Ubuntu 24.04，包含完整的 Android 编译工具链。
#
# 构建参数:
#   UBUNTU_VERSION: Ubuntu 版本 (默认: 24.04)
#   JAVA_VERSION: Java 版本 (默认: 17)
#   PYTHON_VERSION: Python 版本 (默认: 3.12)
#   ANDROID_SDK_VERSION: Android SDK 版本 (默认: 34)
#   ANDROID_NDK_VERSION: Android NDK 版本 (默认: r26)
#   GRADLE_VERSION: Gradle 版本 (默认: 8.5)
#
# 使用示例:
#   docker build -t android-build:latest .
#   docker build --build-arg ANDROID_SDK_VERSION=33 -t android-build:33 .
#
# ============================================
# 阶段 1: Builder - 安装所有构建工具
# ============================================
# 构建参数
ARG UBUNTU_VERSION=24.04
ARG JAVA_VERSION=17
ARG PYTHON_VERSION=3.12
ARG ANDROID_SDK_VERSION=34
ARG ANDROID_NDK_VERSION=r26
ARG GRADLE_VERSION=8.10

FROM ubuntu:${UBUNTU_VERSION} AS builder

# 重新声明构建参数以在 FROM 之后使用
ARG ANDROID_SDK_VERSION=34
ARG ANDROID_NDK_VERSION=r26

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV GRADLE_HOME=/opt/gradle
ENV PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${GRADLE_HOME}/bin:/usr/local/bin:${PATH}"

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    openjdk-17-jdk \
    python3 \
    python3-pip \
    git \
    curl \
    wget \
    unzip \
    ninja-build \
    ccache \
    make \
    gcc \
    g++ \
    clang \
    clang-format \
    clang-tidy \
    lld \
    llvm \
    && rm -rf /var/lib/apt/lists/*

# 安装 Android SDK Command-line Tools
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools/latest && \
    curl -f -L --retry 5 --retry-delay 10 -o /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11079833_latest.zip || \
    curl -f -L --retry 5 --retry-delay 10 -o /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-tmp && \
    mv /tmp/cmdline-tools-tmp/cmdline-tools/* ${ANDROID_HOME}/cmdline-tools/latest/ && \
    rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-tmp

# 接受 Android SDK 许可证并安装组件
RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses && \
    ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
    "platforms;android-${ANDROID_SDK_VERSION}" \
    "platform-tools" \
    "emulator" \
    "tools"

# 安装 Android NDK
RUN curl -f -L --retry 5 --retry-delay 10 -o /tmp/ndk.zip https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    unzip /tmp/ndk.zip -d /opt && \
    mv /opt/android-ndk-${ANDROID_NDK_VERSION} ${ANDROID_NDK_HOME} && \
    rm /tmp/ndk.zip

# 安装 Gradle
RUN curl -f -L --retry 5 --retry-delay 10 -o /tmp/gradle.zip https://downloads.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip || \
    curl -f -L --retry 5 --retry-delay 10 -o /tmp/gradle.zip https://downloads.gradle.org/distributions/gradle-8.10-bin.zip || \
    curl -f -L --retry 5 --retry-delay 10 -o /tmp/gradle.zip https://downloads.gradle.org/distributions/gradle-8.9-bin.zip && \
    unzip /tmp/gradle.zip -d /opt && \
    GRADLE_DIR=$(ls -d /opt/gradle-*) && \
    mv $GRADLE_DIR ${GRADLE_HOME} && \
    rm /tmp/gradle.zip

# 安装 repo 工具
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo && \
    chmod a+x /usr/local/bin/repo

# 安装额外的 Python 包
RUN pip3 install --break-system-packages \
    protobuf \
    six \
    future \
    psutil \
    colorama \
    requests

# 保存 Python 版本信息供后续阶段使用
RUN python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" > /python_version.txt

# 清理临时文件
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================
# 阶段 2: Runtime - 最终运行环境
# ============================================
# 构建参数
ARG UBUNTU_VERSION=24.04
ARG JAVA_VERSION=17

FROM ubuntu:${UBUNTU_VERSION}

# 重新定义构建参数
ARG JAVA_VERSION

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV GRADLE_HOME=/opt/gradle
ENV CCACHE_DIR=/ccache
ENV USE_CCACHE=1
ENV CCACHE_EXEC=/usr/bin/ccache
ENV PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${GRADLE_HOME}/bin:/usr/local/bin:${PATH}"

# 从 builder 阶段复制必需文件
COPY --from=builder /usr/lib/jvm /usr/lib/jvm
COPY --from=builder /opt/android-sdk /opt/android-sdk
COPY --from=builder /opt/android-ndk /opt/android-ndk
COPY --from=builder /opt/gradle /opt/gradle
COPY --from=builder /usr/local/bin/repo /usr/local/bin/repo
COPY --from=builder /usr/bin/ccache /usr/bin/ccache
COPY --from=builder /usr/bin/ninja /usr/bin/ninja
COPY --from=builder /python_version.txt /python_version.txt
# 动态复制 Python 文件
COPY --from=builder /usr/lib/python3.12 /usr/lib/python3.12
COPY --from=builder /usr/local/lib/python3.12/dist-packages /usr/local/lib/python3.12/dist-packages

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    python3-pip \
    make \
    curl \
    wget \
    unzip \
    ca-certificates \
    ccache \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录和缓存目录
RUN mkdir -p /workspace /ccache && \
    if ! id builder &>/dev/null; then useradd -m builder; fi && \
    chown -R builder:builder /workspace /ccache

# 设置 ccache 配置
RUN ccache -M 50G && \
    ccache -o compression=true && \
    ccache -o compression_level=6

# 设置工作目录
WORKDIR /workspace

# 设置非 root 用户
USER builder

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python3 -c "import sys; sys.exit(0)"

# 镜像元数据
LABEL maintainer="Android Build Team"
LABEL version="1.0.0"
LABEL description="Docker image for Android system and application compilation"
LABEL org.opencontainers.image.source="https://github.com/your-org/android-build-docker"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# 默认命令
CMD ["/bin/bash"]