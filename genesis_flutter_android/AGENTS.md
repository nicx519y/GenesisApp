# AGENTS.md

## 项目概述
这是一个名为GenesisApp的Flutter应用程序项目，主要针对Android平台开发。项目使用Dart语言编写，集成了Google登录、地图显示、聊天功能等模块。

## 目录结构
- **lib/**: 包含Dart源代码
  - **main.dart**: 应用程序入口点
  - **app/**: 应用核心逻辑
    - **genesis_app.dart**: 主应用类
    - **components/**: UI组件
    - **models/**: 数据模型
    - **network/**: 网络相关代码
    - **pages/**: 页面组件
    - **platform/**: 平台特定服务
    - **routers/**: 路由配置
  - **icons/**: 自定义图标
- **android/**: Android平台特定代码和配置
  - **app/**: Android应用模块
  - **gradle/**: Gradle构建工具配置
- **assets/**: 静态资源文件
  - **custom-icons/**: 自定义图标资源
  - **images/**: 图片资源
- **test/**: 单元测试和集成测试代码
- **build/**: 构建输出目录（自动生成）
- **analysis_options.yaml**: Dart代码分析配置
- **pubspec.yaml**: Flutter项目依赖和配置
- **README.md**: 项目说明文档

## 主要功能模块
- 用户认证（Google登录）
- 世界地图显示
- 聊天功能
- 起源相关页面
- 搜索功能

## 构建和运行
使用Flutter SDK进行构建。Android平台需要配置相应的Gradle环境。