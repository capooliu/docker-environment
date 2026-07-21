# Lab 3 Docker 使用方式

這個 image 延續 Lab 2 的硬體開發環境，並加入 Lab 3 協作所需的 Python 工具：

- Python 3.11 以上
- uv
- pre-commit
- Ruff
- pytest
- Git、OpenSSH client、編譯工具、Verilator、SystemC

## 隊友第一次使用

先安裝 Docker Desktop，並用 Git Bash 執行：

```bash
git clone <Lab3-GroupN-repo-url>
cd <Lab3-GroupN>
./docker.sh build
./docker.sh run
```

目前的 repository 會掛載到 container 的 `/workspace/project`，所以在 container 內修改的程式會直接保留在本機 Git working tree。

進入 container 後，初始化專案環境與 Git hook：

```bash
uv sync --locked
uv run pre-commit install
uv run pre-commit run --all-files
uv run pytest
```

若專案剛建立、尚未有 `uv.lock`，第一次改用 `uv sync` 產生 lockfile，之後把 `uv.lock` 一起 commit。其他隊友及 CI 應使用 `uv sync --locked`，避免每個人解析到不同依賴版本。

## 日常使用

```bash
./docker.sh run

# 在 container 內
uv run ruff check .
uv run ruff format --check .
uv run pytest
uv run pre-commit run --all-files
```

雖然 image 內已提供全域的 `pre-commit`、`ruff`、`pytest` 指令，專案工作仍建議使用 `uv run ...`，因為它會遵守 `pyproject.toml` 與 `uv.lock` 中團隊共同鎖定的版本。

## Linux bind mount 權限

預設 container 使用 UID/GID 1001。在 Linux 上若本機帳號不是 1001，第一次 build 時應改成自己的 UID/GID：

```bash
./docker.sh build --user-uid $(id -u) --user-gid $(id -g)
./docker.sh run
```

若先前已用其他 UID/GID build，請使用相同參數執行 `rebuild`。`rebuild` 會刪除舊 container 與 image，但 bind-mounted repository 的本機檔案不會被刪除。

## 各自使用不同 container 名稱

```bash
./docker.sh build --image-name lab3-groupN:latest
./docker.sh run --image-name lab3-groupN:latest --cont-name lab3-groupN-alice
```

不要把 `.venv/`、cache、SSH key 或其他人的 Git credentials commit 進 repository。每位成員應在自己的主機設定 Git identity。

## 環境檢查

```bash
python3 --version
uv --version
pre-commit --version
ruff --version
pytest --version
git --version
```

Python 顯示 3.11 或更新版本即符合本環境的版本要求。
