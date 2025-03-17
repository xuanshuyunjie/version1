#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

echo " 启动 MinerU..."
source /opt/conda/etc/profile.d/conda.sh
conda activate mineru

# 检查 `magic-pdf` 是否安装，若没有则安装
if ! command -v magic-pdf &> /dev/null; then
echo "️ magic-pdf 未安装，正在安装..."
pip install -U 'magic-pdf[full]' --extra-index-url https://wheels.myhloli.com
fi

# 🛠️ 下载 MinerU 模型（如果尚未下载）
if [ ! -f 'download_models_hf.py' ]; then
    echo "📥 下载 MinerU 模型..."
    pip install modelscope
    wget https://gcore.jsdelivr.net/gh/opendatalab/MinerU@master/scripts/download_models.py -O /app/backend/download_models.py
fi

echo "️ 正在下载：download_models.py！！！"
python download_models.py



# 启动 `MinerU`
magic-pdf -v &

# Add conditional Playwright browser installation
if [[ "${RAG_WEB_LOADER_ENGINE,,}" == "playwright" ]]; then
if [[ -z "${PLAYWRIGHT_WS_URI}" ]]; then
echo "Installing Playwright browsers..."
playwright install chromium
playwright install-deps chromium
fi

python -c "import nltk; nltk.download('punkt_tab')"
fi

KEY_FILE=.webui_secret_key

PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"
if test "$WEBUI_SECRET_KEY $WEBUI_JWT_SECRET_KEY" = " "; then
echo "Loading WEBUI_SECRET_KEY from file, not provided as an environment variable."

if ! [ -e "$KEY_FILE" ]; then
echo "Generating WEBUI_SECRET_KEY"
echo $(head -c 12 /dev/random | base64) > "$KEY_FILE"
fi

echo "Loading WEBUI_SECRET_KEY from $KEY_FILE"
WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi

if [[ "${USE_OLLAMA_DOCKER,,}" == "true" ]]; then
echo "USE_OLLAMA is set to true, starting ollama serve."
ollama serve &
fi

if [[ "${USE_CUDA_DOCKER,,}" == "true" ]]; then
echo "CUDA is enabled, appending LD_LIBRARY_PATH to include torch/cudnn & cublas libraries."
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib/python3.11/site-packages/torch/lib:/usr/local/lib/python3.11/site-packages/nvidia/cudnn/lib"
fi

# Check if SPACE_ID is set, if so, configure for space
if [ -n "$SPACE_ID" ]; then
echo "Configuring for HuggingFace Space deployment"
if [ -n "$ADMIN_USER_EMAIL" ] && [ -n "$ADMIN_USER_PASSWORD" ]; then
echo "Admin user configured, creating"
WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' &
webui_pid=$!
echo "Waiting for webui to start..."
while ! curl -s http://localhost:8080/health > /dev/null; do
sleep 1
done
echo "Creating admin user..."
curl \
-X POST "http://localhost:8080/api/v1/auths/signup" \
-H "accept: application/json" \
-H "Content-Type: application/json" \
-d "{ \"email\": \"${ADMIN_USER_EMAIL}\", \"password\": \"${ADMIN_USER_PASSWORD}\", \"name\": \"Admin\" }"
echo "Shutting down webui..."
kill $webui_pid
fi

export WEBUI_URL=${SPACE_HOST}
fi

WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*'