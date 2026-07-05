# docker-environment

本 repository 是 Lab 1 的 Docker 開發環境，主要包含：

- `Dockerfile`：定義 image 如何被建立
- `docker.sh`：簡化 build、run、clean、rebuild 的操作
- `.dockerignore`：排除不需要送進 Docker build context 的檔案

---

## 使用流程

第一次使用或 image 不存在時：

```bash
./docker.sh build
./docker.sh run
```

之後再次進入 container：

```bash
./docker.sh run
```

刪除 container 和 image：

```bash
./docker.sh clean
```

刪除後重新 build：

```bash
./docker.sh rebuild
```

---

## 進入 Container 後

執行：

```bash
./docker.sh run
```

成功後會進入 container，預設工作目錄是：

```text
/workspace/project
```

這個位置會掛載本機目前的 repository，因此在 container 裡可以直接看到專案檔案，例如：

```text
Dockerfile
docker.sh
README.md
```

可以用以下指令確認環境：

```bash
pwd
whoami
git --version
gcc --version
g++ --version
make --version
python3 --version
pip --version
verilator --version
echo $SYSTEMC_HOME
```



---

## Dockerfile 程式說明

`Dockerfile` 使用 multi-stage build，分成以下 stages：

```text
base
→ common_pkg_provider
→ verilator_provider
→ systemc_provider
→ release
```

### base

`base` 是最底層環境，負責建立 Ubuntu 基礎設定。

主要內容：

```dockerfile
FROM ubuntu:26.04 AS base
```

使用 Ubuntu 26.04 作為基礎 image，並把這個 stage 命名為 `base`。

```dockerfile
ARG USERNAME=aoc
ARG USER_UID=1001
ARG USER_GID=1001
```

設定 build-time 參數，用來建立 container 內的使用者。

```dockerfile
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Taipei
```

設定 apt 安裝時不要進入互動模式，並把時區設成台灣時間。

```dockerfile
RUN apt-get update && ...
```

在同一個 `RUN` 裡完成套件更新、安裝 `tzdata`、設定時區、建立 non-root user、建立 `/workspace`，最後清除 apt cache。

```dockerfile
WORKDIR /workspace
USER ${USERNAME}
CMD ["/bin/bash"]
```

設定 container 預設工作目錄、預設使用者，以及啟動後預設執行 bash。

---

### common_pkg_provider

`common_pkg_provider` 從 `base` 繼承，負責安裝常用開發工具。

```dockerfile
FROM base AS common_pkg_provider
```

代表這個 stage 會沿用 `base` 的環境設定。

```dockerfile
USER root
```

因為 apt 安裝套件需要 root 權限，所以暫時切回 root。

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        vim git curl wget ca-certificates \
        build-essential python3 python3-pip
```

安裝常用工具，例如 Git、C/C++ compiler、make、Python、pip。

```dockerfile
USER aoc
```

安裝完成後切回 non-root user。

---

### verilator_provider

`verilator_provider` 從 `common_pkg_provider` 繼承，負責從 source code build Verilator。

```dockerfile
FROM common_pkg_provider AS verilator_provider
```

代表這個 stage 已經可以使用前面安裝好的 git、compiler、make 等工具。

```dockerfile
ARG VERILATOR_VERSION=stable
ARG VERILATOR_JOBS=2
```

設定 Verilator 版本與編譯時使用的 jobs 數量。

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        autoconf flex bison help2man perl \
        libfl-dev zlib1g-dev liblz4-dev ccache
```

安裝 build Verilator 需要的額外相依套件。

```dockerfile
RUN git clone --depth 1 --branch ${VERILATOR_VERSION} ... && \
    autoconf && \
    ./configure && \
    make -j${VERILATOR_JOBS} && \
    make install && \
    verilator --version
```

從 GitHub clone Verilator source code，接著 configure、compile、install，最後用 `verilator --version` 確認安裝成功。

---

### systemc_provider

`systemc_provider` 從 `verilator_provider` 繼承，負責從 source code build SystemC 2.3.4。

```dockerfile
FROM verilator_provider AS systemc_provider
```

代表這個 stage 已經包含 common packages 和 Verilator。

```dockerfile
ARG SYSTEMC_VERSION=2.3.4
ARG SYSTEMC_JOBS=2
```

設定 SystemC 版本與編譯 jobs 數量。

```dockerfile
ENV SYSTEMC_HOME=/opt/systemc
ENV SYSTEMC_CXXFLAGS="-I/opt/systemc/include"
ENV SYSTEMC_LDFLAGS="-L/opt/systemc/lib -lsystemc -Wl,-rpath,/opt/systemc/lib -pthread"
```

設定之後編譯 SystemC 程式會用到的 include path 和 link flags。

```dockerfile
RUN git clone https://github.com/accellera-official/systemc.git ... && \
    git checkout ${SYSTEMC_VERSION} && \
    cmake ... && \
    cmake --build ... && \
    cmake --install ...
```

下載 SystemC source code，切到指定版本，用 CMake build 並安裝到 `/opt/systemc-2.3.4`。

```dockerfile
ln -sfn /opt/systemc-${SYSTEMC_VERSION} /opt/systemc
```

建立 symbolic link，讓 `/opt/systemc` 永遠指向目前使用的 SystemC 版本。

```dockerfile
g++ ${SYSTEMC_CXXFLAGS} /tmp/systemc_test.cpp ${SYSTEMC_LDFLAGS} ...
```

在 build 階段編譯一個最小 SystemC 測試程式，確認 include path、library path 和 link flags 正確。

---

### release

`release` 是最後真正使用的 image stage。

```dockerfile
FROM systemc_provider AS release
```

`release` 直接從 `systemc_provider` 繼承，因此可以使用前面 stage 安裝好的工具。

這樣做的原因是：`apt` 和 `pip` 安裝的內容通常會分散在 `/usr/bin`、`/usr/lib`、`/usr/share`、`/etc` 等位置，不適合用 `COPY --from=... /usr /usr` 整包複製。

透過 stage 繼承，可以讓 final image 直接保留前面安裝好的環境，又不需要手動搬移大量系統檔案。

---

## docker.sh 程式說明

`docker.sh` 是一個 Bash helper script，用來簡化 Docker 指令。

支援的 command：

```text
build
run
clean
rebuild
help
```

---

### 預設參數

script 開頭定義預設值：

```bash
IMAGE_NAME="aoc2026-env:latest"
CONT_NAME="aoc2026-env"
USERNAME="aoc"
HOSTNAME="aoc2026"
DOCKERFILE="Dockerfile"
TARGET="release"
```

代表預設會 build `release` stage，image 名稱是 `aoc2026-env:latest`，container 名稱是 `aoc2026-env`。

---
## Customized Command Line Arguments

為了讓 Docker 環境更有彈性，本專案在 `docker.sh` 中加入 CLI 參數，讓使用者可以自行指定 image、container、使用者、hostname，以及要掛載進 container 的資料夾。

支援的參數如下：

```bash
--image-name   指定 Docker image 名稱，預設為 aoc2026-env:latest
--cont-name    指定 Docker container 名稱，預設為 aoc2026-env
--username     指定 container 內執行的使用者，預設為 aoc
--hostname     指定 container hostname，預設為 aoc2026
--mount        額外掛載本機資料夾到 container 的 /workspace/<資料夾名稱>
--dockerfile   指定 Dockerfile 路徑，預設為 Dockerfile
--target       指定 docker build 的 target stage，預設為 release
````

範例：

```bash
./docker.sh run \
    --image-name aoc2026-env:latest \
    --cont-name aoc2026-test \
    --username aoc \
    --hostname aoc2026 \
    --mount /c/Users/angelliu.LAPTOP-3NTJHQPG/Desktop
```

這樣執行時，script 會使用指定的 image name 和 container name 建立 container，並把本機的 Desktop 資料夾額外 bind mount 到 container 裡的：

```text
/workspace/Desktop
```

此外，`docker.sh run` 也會自動判斷 container 狀態：

```text
container 不存在 → docker run 建立並進入 container
container 已停止 → docker start 後 docker exec 進入
container 執行中 → docker exec 直接進入
container paused → docker unpause 後 docker exec 進入
```

因此使用者只需要執行：

```bash
./docker.sh run
```

就可以進入開發環境，不需要自己手動判斷 image 或 container 是否已存在。


---

### build_image()

```bash
build_image() {
    docker build -t "$IMAGE_NAME" -f "$DOCKERFILE" --target "$TARGET" .
}
```

這個 function 負責 build Docker image。

預設等價於：

```bash
docker build -t aoc2026-env:latest -f Dockerfile --target release .
```

---

### run_container()

`run_container()` 是 `docker.sh` 最主要的 function。

它會先檢查 image 是否存在：

```bash
if ! image_exists; then
    build_image
fi
```

如果 image 不存在，就先 build。

接著檢查 container 狀態：

```bash
status="$(container_status)"
```

然後依照狀態執行不同動作：

```text
running      → docker exec 進入 container
exited       → docker start 後再 docker exec
not_existed  → docker run 建立新 container
paused       → docker unpause 後再 docker exec
```

這樣使用者不需要自己判斷 container 目前是執行中、停止中，還是根本不存在。

---

### mount 設定

當 container 不存在，需要新建時，script 會把目前 repository 掛進 container：

```bash
--mount type=bind,source=<本機repo>,target=/workspace/project
```

因此進入 container 後會在：

```text
/workspace/project
```

並且可以直接操作本機專案檔案。

如果使用 `--mount`，可以額外掛載其他本機資料夾：

```bash
./docker.sh run --mount /c/Users/angelliu.LAPTOP-3NTJHQPG/Desktop
```

會掛載到：

```text
/workspace/Desktop
```

---

### clean_all()

```bash
clean_all() {
    docker rm -f "$CONT_NAME"
    docker image rm "$IMAGE_NAME"
}
```

這個 function 用來刪除指定的 container 和 image。

---

### rebuild

`rebuild` 會先執行 `clean_all()`，再執行 `build_image()`：

```text
rebuild = clean + build
```

適合 Dockerfile 改很多、想重新建立環境時使用。

---

### Windows Git Bash 處理

在 Windows Git Bash 中，Linux path 可能會被錯誤轉成 Windows path，例如：

```text
/workspace/project
/bin/bash
```

可能被轉成：

```text
C:/Program Files/Git/workspace/project
C:/Program Files/Git/usr/bin/bash.exe
```

所以 `docker.sh` 會設定：

```bash
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"
```

並在 Git Bash 環境中把 container path 轉成較安全的形式，例如：

```text
//workspace/project
//bin/bash
```

避免 Git Bash 自動轉換 container 內部路徑。

---

## 常用指令

Build image：

```bash
./docker.sh build
```

Run container：

```bash
./docker.sh run
```

Clean：

```bash
./docker.sh clean
```

Rebuild：

```bash
./docker.sh rebuild
```

查看說明：

```bash
./docker.sh help
```
