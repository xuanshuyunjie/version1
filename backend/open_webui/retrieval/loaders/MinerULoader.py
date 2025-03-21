import subprocess
import os
import re
from bs4 import BeautifulSoup
from langchain_core.documents import Document
import time

class MinerULoader:
    def __init__(self, input_path: str, output_path: str = None):
        """
        :param input_path: PDF 文件的绝对路径
        :param output_path: 生成后的 .md 文件和相关输出存放的路径
        """
        self.input_path = input_path
        # 如果外部没传 output_path，就使用默认的 PDFoutput 目录

        # 计算正确的 BASE_DIR，确保 `data/outputpdf` 目录指向 `/app/backend/data/outputpdf`
        BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))

        # 确保 `outputpdf` 目录指向 `/app/backend/data/outputpdf`
        self.output_path = output_path or os.path.join(BASE_DIR, "data/outputpdf")
        # 确保输出目录存在
        os.makedirs(self.output_path, exist_ok=True)

    def load(self) -> list[Document]:
        """
        1. 调用 magic-pdf 生成 .md 文件
        2. 清洗 .md 文件中的特殊符号 & LaTeX 公式
        3. 将处理后的文本写回 .md 文件
        4. 返回一个 Document 列表
        """
        # ✅ 修正 `conda activate` 的使用
#         command = [
#             "bash", "-c",
#             f"""
#             source ~/miniconda3/etc/profile.d/conda.sh && \
#             conda activate mineru || (conda create -n mineru python=3.10 -y && conda activate mineru) && \
#             pip install -U 'magic-pdf[full]' --extra-index-url https://wheels.myhloli.com && \
#             magic-pdf -p '{self.input_path}' -o '{self.output_path}' -m auto
#             """
#         ]

        command = [
            "bash", "-c",
            "source /opt/conda/etc/profile.d/conda.sh && conda activate mineru && magic-pdf -p '{}' -o '{}' -m auto".format(self.input_path, self.output_path)
        ]

        print(f"🚀 DEBUG: 执行命令: {command}")
        print(f"DEBUG: input_path={self.input_path}, output_path={self.output_path}")

        # ✅ 运行 magic-pdf 并获取输出
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # ✅ 处理错误
        if process.returncode != 0:
            print(f"❌ 运行 magic-pdf 失败！\nSTDOUT: {process.stdout}\nSTDERR: {process.stderr}")
            raise RuntimeError("magic-pdf 执行失败！")

        print(f"✅ magic-pdf 运行成功: {process.stdout}")

        # 根据 input_path 构造 .md 文件名（UUID_test 这样的拼法）
        base_filename = os.path.basename(self.input_path)  # e.g. "0a121757-9af0-457e-8cd9-3979e5373de8_test.pdf"
        # 先移除所有可能的扩展名
        uuid_dir = re.sub(r"\.(pdf|ppt|pptx|doc|docx)$", "", base_filename, flags=re.IGNORECASE)

        print(uuid_dir)  # 这里测试一下结果


        # 拼接出生成的 .md 文件绝对路径
        md_file_path = os.path.join(self.output_path, uuid_dir, "auto", f"{uuid_dir}.md")
        print(f"DEBUG: Expected MD file path: {md_file_path}")




        # 如果 .md 不存在，抛出异常
        if not os.path.exists(md_file_path):
            raise FileNotFoundError(f"ERROR: .md file not found at expected location: {md_file_path}")

        # 读取 .md 文件内容
        with open(md_file_path, "r", encoding="utf-8") as f:
            md_text = f.read()

        # 调用 clean_text() 进行清洗
        cleaned_text = self.clean_text(md_text)

        # 将清洗后的文本写回 .md 文件
        with open(md_file_path, "w", encoding="utf-8") as f:
            f.write(cleaned_text)

        # 这里创建 Document 对象
        doc = Document(page_content=cleaned_text, metadata={"source": md_file_path})

        # ========== 在此处打印你要给模型的文本内容 ==========
        # 如果文本太长，可以只打印一部分
        print(f"\n=== 最终传给大模型的文本（长度：{len(cleaned_text)}） ===")
        print(cleaned_text[:5000])  # 只打印前 5000 个字符，避免过长
        # ========== 打印结束 ==========

        # 返回 list[Document]
        return [doc]

    def clean_text(self, text: str) -> str:
        """
        1) 用 BeautifulSoup 解析 .md (HTML)
        2) 在所有文本节点上：
           - 移除 `$...$` 或 `$$...$$` 中的内容
           - 移除特殊符号(◆, ★, ~, +)
        3) 保留其余 HTML 标签/结构
        """

        # 用 BeautifulSoup 解析，lxml 或 html.parser 均可
        soup = BeautifulSoup(text, "html.parser")

        # 遍历所有文本节点
        for text_node in soup.strings:
            original_str = str(text_node)

            # 1) 移除 LaTeX 公式 (单/双 $)
            # 例如: $...$ 或 $$...$$
            # DOTALL: 公式可能跨行的话需要 flags=re.DOTALL
            removed_latex = re.sub(r"\${1,2}[^$]*?\${1,2}", "", original_str)

            # 2) 移除无用特殊符号(◆, ★, ~, +)
            removed_special = re.sub(r"[◆★~+]", "", removed_latex)

            # 将处理后的文本替换回 DOM
            text_node.replace_with(removed_special)

        # 转回字符串
        cleaned_text = str(soup)

        return cleaned_text