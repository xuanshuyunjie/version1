#!/bin/bash

# 1️⃣ 在新终端窗口启动 MinerU
echo "🚀 在新终端窗口启动 MinerU..."
gnome-terminal -- bash -c "
    echo '🚀 正在启动 MinerU...';

    conda init

    if ! conda info --envs | grep -q mineru; then
        conda create -n mineru python=3.10 -y
    fi

    # 确保 `conda activate` 可用
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate mineru

    # 安装 MinerU 依赖（如果尚未安装）
    pip list | grep -q 'magic-pdf' || pip install -U 'magic-pdf[full]' --extra-index-url https://wheels.myhloli.com
    pip list | grep -q 'modelscope' || pip install modelscope


    # 下载 MinerU 模型（如果尚未下载）
    if [ ! -f 'download_models_hf.py' ]; then
        wget https://gcore.jsdelivr.net/gh/opendatalab/MinerU@master/scripts/download_models.py -O download_models.py
    fi
    python download_models_hf.py

    # 运行 MinerU
    echo '🚀 MinerU 正在运行...';
    magic-pdf -v;

    exec bash
"


# 3️⃣ 启动 OpenWeb-UI（当前终端）
PORT="${PORT:-8080}"
echo "🚀 正在启动 OpenWeb-UI..."
uvicorn open_webui.main:app --port $PORT --host 0.0.0.0 --forwarded-allow-ips '*' --reload

