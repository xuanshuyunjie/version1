#!/bin/bash
# 3️⃣ 启动 OpenWeb-UI（当前终端）
PORT="${PORT:-8080}"
echo "🚀 正在启动 OpenWeb-UI..."
uvicorn open_webui.main:app --port $PORT --host 0.0.0.0 --forwarded-allow-ips '*' --reload

