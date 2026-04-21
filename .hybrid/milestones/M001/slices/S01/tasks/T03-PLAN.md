# T03 初始化git仓库 任务计划

## 任务目标
初始化git仓库，创建.gitignore文件，进行初始提交。

## 步骤分解

### 步骤1: 初始化git仓库
```bash
cd /home/liu/workspace/mihomo-quick
git init
```

### 步骤2: 创建.gitignore文件
```gitignore
# 配置文件
configs/*.yaml
configs/*.yml
!configs/*.template

# 日志文件
logs/*.log
*.log

# 备份文件
backups/*.tar.gz
*.bak

# 临时文件
*.tmp
*.swp
*~

# 系统文件
.DS_Store
Thumbs.db

# 编辑器文件
.vscode/
.idea/
*.sublime-*

# 运行时文件
*.pid
*.sock

# 敏感信息
.env
*.key
*.pem
```

### 步骤3: 添加文件到git
```bash
git add .
git status
```

### 步骤4: 进行初始提交
```bash
git commit -m "Initial commit: mihomo-quick project"
```

### 步骤5: 验证git状态
```bash
git log --oneline
git status
```

## 验收标准
1. git仓库可用
2. .gitignore完整
3. 初始提交成功

## 预计时间
30分钟

## 创建日期
2026-04-21 11:28:29
