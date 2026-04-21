# M001 技术研究

## bash脚本最佳实践

### 1. 目录结构
```
mihomo-quick/
├── mihomo-quick.sh      # 主入口
├── lib/                 # 功能模块
├── templates/           # 配置模板
├── configs/             # 配置文件
└── README.md
```

### 2. 模块化设计
- 使用source命令导入模块
- 统一的函数命名规范
- 清晰的接口定义

### 3. 错误处理
- set -e 遇到错误立即退出
- trap捕获信号
- 统一的错误日志

### 4. 用户界面
- 清晰的菜单设计
- 友好的提示信息
- 完整的帮助文档

## 参考项目
1. [mihomo官方脚本](https://github.com/MetaCubeX/mihomo)
2. [clash-premium-installer](https://github.com/jeessy2/clash-premium-installer)
3. [clash-for-linux-install](https://github.com/ermaozi01/install_clash_on_linux)
