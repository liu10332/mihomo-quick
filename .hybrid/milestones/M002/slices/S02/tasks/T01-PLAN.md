# T01 向导界面设计 任务计划

## 任务目标
设计友好的向导界面，提供清晰的步骤导航和输入界面。

## 步骤分解

### 步骤1: 设计欢迎界面
```bash
show_welcome() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    mihomo-quick 配置向导                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}欢迎使用 mihomo-quick 配置向导！${NC}"
    echo ""
    echo "这个向导将帮助您快速生成mihomo配置文件。"
    echo "请按照提示逐步完成配置。"
    echo ""
    echo -e "${YELLOW}提示: 可以随时按 Ctrl+C 取消${NC}"
    echo ""
    read -p "按 Enter 键开始..."
}
```

### 步骤2: 设计步骤导航
```bash
show_step_navigation() {
    local current=$1
    local total=$2
    local step_name=$3
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}步骤 $current/$total: $step_name${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}
```

### 步骤3: 设计输入界面
```bash
show_input_prompt() {
    local prompt=$1
    local default=$2
    local options=$3
    
    echo -e "${WHITE}$prompt${NC}"
    
    if [[ -n "$default" ]]; then
        echo -e "默认值: ${GREEN}$default${NC}"
    fi
    
    if [[ -n "$options" ]]; then
        echo -e "可选值: $options"
    fi
    
    echo ""
}
```

### 步骤4: 设计预览界面
```bash
show_preview() {
    local config_file=$1
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}配置预览${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ -f "$config_file" ]]; then
        head -50 "$config_file"
    else
        echo "配置文件不存在"
    fi
    
    echo ""
}
```

### 步骤5: 设计确认界面
```bash
show_confirmation() {
    local config_file=$1
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}确认配置${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "配置文件将保存到: $config_file"
    echo ""
    echo -e "${GREEN}1${NC}. 确认生成配置"
    echo -e "${YELLOW}2${NC}. 重新配置"
    echo -e "${RED}3${NC}. 取消"
    echo ""
}
```

## 验收标准
1. 界面友好
2. 导航清晰
3. 输入方便
4. 预览清晰
5. 确认可靠

## 预计时间
2小时

## 创建日期
2026-04-21 13:11:19
