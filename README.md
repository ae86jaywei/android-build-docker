# Android Build Docker Image

一个用于 Android 系统和应用程序编译的 Docker 镜像，提供标准化的 Android 编译环境。

## 特性

- 🐳 **基于 Ubuntu 24.10** - 最新的 Ubuntu 版本，提供最新的工具链
- 🔧 **完整的 Android 编译工具链** - 包含 AOSP 和 Android 应用编译所需的所有工具
- 🚀 **多阶段构建优化** - 分离构建环境和运行时环境，优化镜像体积
- 🔄 **GitHub Actions 集成** - 支持自动化构建和编译工作流
- 💾 **编译缓存支持** - 集成 ccache 加速重复编译
- 🔒 **安全最佳实践** - 非 root 用户运行，定期安全扫描

## 包含的工具

### 系统工具
- Ubuntu 24.04 基础系统
- build-essential, make, ninja-build
- Git, curl, wget, unzip
- Python 3.12, pip

### Java 环境
- OpenJDK 17

### Android 工具链
- Android SDK Command-line Tools
- Android SDK Platform 34
- Android SDK Build-Tools 34
- Android Platform-Tools
- Android NDK r26
- repo 工具

### 构建工具
- Gradle 8.5
- ccache 4.x

## 快速开始

### 拉取镜像

```bash
docker pull ghcr.io/ae86jaywei/android-build:latest
```

### 运行容器

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ccache-data:/ccache \
  ghcr.io/your-org/android-build:latest \
  /bin/bash
```

### 验证环境

```bash
# 检查 Java 版本
java -version

# 检查 Android SDK
sdkmanager --list

# 检查 Gradle
gradle --version

# 检查 ccache
ccache --version
```

## 使用示例

### 编译 Android 应用

```bash
# 进入项目目录
cd /workspace

# 使用 Gradle 编译
./gradlew assembleDebug

# 使用 ccache 加速编译
export USE_CCACHE=1
export CCACHE_DIR=/ccache
./gradlew clean assembleDebug
```

### 编译 AOSP 系统

```bash
# 初始化 repo
repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r1

# 同步代码
repo sync -j8

# 设置环境
source build/envsetup.sh

# 选择目标
lunch aosp_arm-eng

# 开始编译
make -j$(nproc)
```

## GitHub Actions 集成

### 镜像构建工作流

当推送代码到 main 分支或手动触发时，自动构建和推送 Docker 镜像到 GitHub Container Registry。

### Android 编译工作流

使用该镜像执行 Android 编译任务，支持自定义参数：
- Android 版本
- 编译类型（系统/应用）
- 是否启用缓存

## 配置

### 环境变量

| 变量名 | 默认值 | 描述 |
|--------|--------|------|
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk-amd64` | Java 安装目录 |
| `ANDROID_HOME` | `/opt/android-sdk` | Android SDK 目录 |
| `ANDROID_NDK_HOME` | `/opt/android-ndk` | Android NDK 目录 |
| `GRADLE_HOME` | `/opt/gradle` | Gradle 安装目录 |
| `CCACHE_DIR` | `/ccache` | ccache 缓存目录 |
| `PATH` | 包含所有工具路径 | 系统 PATH |

### 构建参数

构建镜像时可自定义以下参数：

```dockerfile
ARG UBUNTU_VERSION=24.10
ARG JAVA_VERSION=17
ARG PYTHON_VERSION=3.12
ARG ANDROID_SDK_VERSION=34
ARG ANDROID_NDK_VERSION=r26
ARG GRADLE_VERSION=8.5
```

## 本地构建

### 构建镜像

```bash
# 使用默认参数构建
./scripts/build-image.sh

# 自定义参数构建
./scripts/build-image.sh -t my-android-build -v 14
```

### 验证环境

```bash
# 验证所有工具是否安装正确
./scripts/verify-env.sh
```

### 清理缓存

```bash
# 清理编译缓存
./scripts/clean-cache.sh
```

## 目录结构

```
android-build-docker/
├── Dockerfile              # Docker 镜像定义
├── .github/workflows/     # GitHub Actions 工作流
│   ├── build-image.yml    # 镜像构建工作流
│   ├── android-build.yml  # Android 编译工作流
│   └── security-scan.yml  # 安全扫描工作流
├── scripts/               # 构建脚本
│   ├── build-image.sh     # 镜像构建脚本
│   ├── verify-env.sh      # 环境验证脚本
│   └── clean-cache.sh     # 缓存清理脚本
├── config/                # 配置文件
│   ├── default.env        # 默认环境变量
│   ├── cache.env          # 缓存配置
│   └── tools.env          # 工具版本配置
├── examples/              # 使用示例
│   ├── docker-compose.yml # Docker Compose 示例
│   └── github-actions.yml # GitHub Actions 示例
├── docs/                  # 文档
└── README.md              # 项目说明
```

## 许可证

本项目基于 Apache License 2.0 许可证开源。详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 支持

- 报告问题: [GitHub Issues](https://github.com/your-org/android-build-docker/issues)
- 讨论: [GitHub Discussions](https://github.com/your-org/android-build-docker/discussions)
- 文档: [Wiki](https://github.com/your-org/android-build-docker/wiki)

## 版本历史

- v1.0.0 (2025-04-10): 初始版本发布
  - 基于 Ubuntu 24.10
  - 支持 Android 12+ 编译
  - 集成 GitHub Actions
  - 支持 ccache 编译缓存
