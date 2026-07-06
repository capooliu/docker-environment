# docker-environment

本 repository 是 Lab 1 的 Docker 開發環境，用來建立 AOC 2026 所需的 Ubuntu 開發環境。

主要檔案：

| 檔案 | 用途 |
|---|---|
| `Dockerfile` | 定義 Docker image 如何建立 |
| `docker.sh` | 簡化 build、run、clean、rebuild 操作 |
| `eman` | container 內的 frontend script，用來測試環境 |
| `.dockerignore` | 排除不需要送進 Docker build context 的檔案 |
| `README.md` | 說明如何使用此 Docker 環境 |

---

# 1. 快速使用

| 情境 | 指令 |
|---|---|
| 第一次使用 | `./docker.sh build` → `./docker.sh run` |
| 再次進入 container | `./docker.sh run` |
| 修改 `Dockerfile` 或 `eman` 後 | `./docker.sh rebuild` → `./docker.sh run` |
| 刪除 container 和 image | `./docker.sh clean` |
| 查看 `docker.sh` 說明 | `./docker.sh help` |

第一次使用：

```bash
./docker.sh build
./docker.sh run
```

之後再次進入 container：

```bash
./docker.sh run
```

進入 container 後，預設工作目錄是：

```text
/workspace/project
```

這個路徑會掛載本機目前的 repository，因此在 container 裡可以直接看到並操作：

```text
Dockerfile
docker.sh
eman
README.md
```

---

# 2. docker.sh 使用方式

`docker.sh` 是本專案的 Docker helper script，用來簡化 Docker image 和 container 的操作。

## 2.1 支援指令

| 指令 | 功能 | 使用時機 |
|---|---|---|
| `./docker.sh build` | 建立 Docker image | 第一次使用，或只想重新 build image |
| `./docker.sh run` | 建立或進入 container | 平常進入開發環境時使用 |
| `./docker.sh clean` | 刪除 container 和 image | 環境壞掉、想清乾淨時使用 |
| `./docker.sh rebuild` | 先 clean 再 build | 修改 `Dockerfile` 或 `eman` 後使用 |
| `./docker.sh help` | 顯示使用說明 | 忘記指令或參數時使用 |

---

## 2.2 預設設定

| 項目 | 預設值 |
|---|---|
| Image name | `aoc2026-env:latest` |
| Container name | `aoc2026-env` |
| Username | `aoc` |
| Hostname | `aoc2026` |
| Dockerfile | `Dockerfile` |
| Build target | `release` |
| Project mount path | `/workspace/project` |

---

## 2.3 `docker.sh run` 的狀態處理

`docker.sh run` 會自動判斷 container 狀態，選擇正確的 Docker 操作。

| Container 狀態 | docker.sh 的處理方式 |
|---|---|
| container 不存在 | 使用 `docker run` 建立並進入 container |
| container 已停止 | 使用 `docker start` 啟動，再用 `docker exec` 進入 |
| container 執行中 | 直接使用 `docker exec` 進入 |
| container paused | 使用 `docker unpause` 後再進入 |

因此平常不需要自己判斷要用 `docker run`、`docker start` 還是 `docker exec`，只要執行：

```bash
./docker.sh run
```

---

## 2.4 可自訂參數

| 參數 | 預設值 | 功能 |
|---|---|---|
| `--image-name` | `aoc2026-env:latest` | 指定 Docker image 名稱 |
| `--cont-name` | `aoc2026-env` | 指定 Docker container 名稱 |
| `--username` | `aoc` | 指定 container 內使用者 |
| `--hostname` | `aoc2026` | 指定 container hostname |
| `--mount` | 無 | 額外掛載本機資料夾到 container |
| `--dockerfile` | `Dockerfile` | 指定 Dockerfile 路徑 |
| `--target` | `release` | 指定 Docker build target stage |

範例：

```bash
./docker.sh run \
    --image-name aoc2026-env:latest \
    --cont-name aoc2026-test \
    --username aoc \
    --hostname aoc2026 \
    --mount /c/Users/angelliu.LAPTOP-3NTJHQPG/Desktop
```

這個指令會把本機 Desktop 額外掛載到 container 的：

```text
/workspace/Desktop
```

---

# 3. eman 使用方式

`eman` 是 container 內的 frontend script，用來確認開發環境是否可用。

進入 container 後可以直接執行：

```bash
eman help
```

## 3.1 支援指令

| 指令 | 功能 | 用途 |
|---|---|---|
| `eman help` | 顯示使用說明 | 查看目前支援哪些功能 |
| `eman c-compiler-version` | 顯示 gcc、g++、make 版本 | 確認 C/C++ 編譯工具存在 |
| `eman c-compiler-example` | 跑 Lab 0 C 範例 | 測試 gcc 和 make 是否能正常編譯執行 |
| `eman check-verilator` | 顯示 Verilator 路徑與版本 | 確認目前使用的 Verilator |
| `eman verilator-example` | 跑 Lab 0 Verilog 範例 | 測試 Verilator 是否能正常使用 |
| `eman change-verilator <VERSION>` | 切換 Verilator 版本 | 用於切換不同 Verilator 版本 |

---

## 3.2 常用測試流程

進入 container 後，可以依序執行：

```bash
eman help
eman c-compiler-version
eman c-compiler-example
eman check-verilator
eman verilator-example
```

這組指令可以確認：

| 測試項目 | 對應指令 |
|---|---|
| C/C++ 工具版本 | `eman c-compiler-version` |
| C compiler 是否能編譯執行 | `eman c-compiler-example` |
| Verilator 是否存在 | `eman check-verilator` |
| Verilator 是否能跑範例 | `eman verilator-example` |

---

## 3.3 Lab 0 測試 repo

`eman c-compiler-example` 和 `eman verilator-example` 使用 Lab 0 tutorial repo 作為測試來源：

```text
ssh://git@gitlab.aislab.ee.ncku.edu.tw:3175/aislab-internal/course/aoc/aoc2026/lab-0-tutorial.git
```

目前使用固定路徑：

| 測試 | 使用路徑 | 執行內容 |
|---|---|---|
| C compiler example | `lab-0-tutorial/c_cpp/arrays/multidim_array` | `make clean` → `make` → `make run` |
| Verilator example | `lab-0-tutorial/verilog` | `make clean` → `make` |


---
# 4. Dockerfile 功能說明

本專案使用 multi-stage build，把環境分成多個 stage。  
架構如下：

```text
base
└── common_pkg_provider
    ├── verilator_provider
    │   └── build Verilator 到 /opt/verilator
    │
    ├── systemc_provider
    │   └── build SystemC 到 /opt/systemc
    │
    └── release
        ├── 繼承 common_pkg_provider 的一般開發工具
        ├── COPY /opt/verilator from verilator_provider
        └── COPY /opt/systemc from systemc_provider
````

每個 stage 負責不同工作，讓 Verilator 和 SystemC 的 build 過程彼此獨立，最後再由 `release` 組合成真正要給使用者使用的 image。

---

## 4.1 `base`

`base` 是最底層環境，負責建立 Ubuntu 基礎設定。

| 功能         | 說明                                              |
| ---------- | ----------------------------------------------- |
| Base image | 使用 `ubuntu:26.04`                               |
| Timezone   | 設定為 `Asia/Taipei`                               |
| apt mode   | 使用 `DEBIAN_FRONTEND=noninteractive`，避免安裝時卡在互動輸入 |
| User       | 建立 non-root user：`aoc`                          |
| UID/GID    | 使用固定 UID/GID：`1001`                             |
| Workdir    | 建立並使用 `/workspace`                              |

使用 non-root user 的原因是避免 container 預設用 root 執行，減少權限與安全問題。
固定 UID/GID 則可以降低 bind mount 本機資料夾時產生權限混亂的機率。

---

## 4.2 `common_pkg_provider`

`common_pkg_provider` 從 `base` 繼承，負責安裝一般開發工具。

| 工具                       | 用途                                      |
| ------------------------ | --------------------------------------- |
| `vim`                    | 編輯文字檔                                   |
| `git`                    | clone / pull / 版本控制                     |
| `curl`, `wget`           | 下載檔案                                    |
| `ca-certificates`        | 支援 HTTPS 憑證                             |
| `build-essential`        | 提供 gcc、g++、make 等工具                     |
| `python3`, `python3-pip` | Python 環境                               |
| `openssh-client`         | 在 container 內使用 SSH / clone GitLab repo |

這個 stage 的重點是提供後續所有 stage 都會用到的基本能力。
Verilator、SystemC 和 final release image 都會從 `common_pkg_provider` 開始，但它們各自負責不同事情。

---

## 4.3 `verilator_provider`

`verilator_provider` 從 `common_pkg_provider` 繼承，專門負責從 source code build Verilator。

Verilator 是自己從 source 編譯出來的第三方工具，安裝位置為：

```text
/opt/verilator
```

主要功能：

| 功能                    | 說明                                                              |
| --------------------- | --------------------------------------------------------------- |
| 安裝 build dependencies | 安裝 `autoconf`、`flex`、`bison`、`help2man` 等 Verilator build 需要的工具 |
| 下載 source code        | 從 Verilator GitHub repo clone                                   |
| 編譯安裝                  | 執行 `autoconf`、`./configure`、`make`、`make install`               |
| 安裝位置                  | 安裝到 `/opt/verilator`                                            |
| 驗證                    | 用 `/opt/verilator/bin/verilator --version` 確認安裝成功               |

相關 build 參數：

| 參數                  | 用途                      |
| ------------------- | ----------------------- |
| `VERILATOR_VERSION` | 指定 Verilator 版本或 branch |
| `VERILATOR_JOBS`    | 指定 `make -j` 平行編譯數量     |

這個 stage 裡的 Verilator build tools 只用來編譯 Verilator，不會直接繼承到 SystemC stage。

---

## 4.4 `systemc_provider`

`systemc_provider` 從 `common_pkg_provider` 繼承，專門負責 build SystemC 2.3.4。

SystemC 是完整第三方 library，安裝位置為：

```text
/opt/systemc
```

主要功能：

| 功能         | 說明                                     |
| ---------- | -------------------------------------- |
| 安裝 CMake   | 用來 build SystemC                       |
| 下載 SystemC | clone Accellera SystemC source code    |
| 指定版本       | checkout `2.3.4`                       |
| 編譯安裝       | 使用 CMake configure / build / install   |
| 安裝位置       | 安裝到 `/opt/systemc`                     |
| 驗證         | 編譯最小 SystemC 程式，確認 include 和 link 設定正確 |

SystemC 相關環境變數：

| 變數                                                                                  | 用途                   |
| ----------------------------------------------------------------------------------- | -------------------- |
| `SYSTEMC_HOME=/opt/systemc`                                                         | SystemC 安裝位置         |
| `SYSTEMC_CXXFLAGS=-I/opt/systemc/include`                                           | 編譯時 include header   |
| `SYSTEMC_LDFLAGS=-L/opt/systemc/lib -lsystemc -Wl,-rpath,/opt/systemc/lib -pthread` | link SystemC library |
| `LD_LIBRARY_PATH=/opt/systemc/lib`                                                  | 執行時尋找 shared library |

編譯 SystemC 程式時可以使用：

```bash
g++ $SYSTEMC_CXXFLAGS test.cpp $SYSTEMC_LDFLAGS -o test
./test
```

修改後 `systemc_provider` 不再繼承 `verilator_provider`，而是直接從 `common_pkg_provider` 開始。
這樣 SystemC stage 不會攜帶 Verilator 的 build tools，例如 `autoconf`、`flex`、`bison`、`help2man` 等。

---

## 4.5 `release`

`release` 是最後實際給使用者執行的 image stage。

本專案修改後使用：

```dockerfile
FROM common_pkg_provider AS release
```

也就是讓 `release` 先繼承一般開發工具，再從其他 provider stage 複製真正需要的工具成果：

```dockerfile
COPY --from=verilator_provider /opt/verilator /opt/verilator
COPY --from=systemc_provider /opt/systemc /opt/systemc
```

因此 final image 會包含：

| 來源                    | 提供內容                                             |
| --------------------- | ------------------------------------------------ |
| `base`                | Ubuntu 基本設定、non-root user、timezone               |
| `common_pkg_provider` | 一般開發工具，例如 git、gcc、make、python、ssh                |
| `verilator_provider`  | `/opt/verilator`                                 |
| `systemc_provider`    | `/opt/systemc`                                   |
| `release`             | runtime dependencies、環境變數、`eman` frontend script |

`release` 需要設定 Verilator 和 SystemC 的環境變數，例如：

```dockerfile
ENV VERILATOR_HOME=/opt/verilator
ENV SYSTEMC_HOME=/opt/systemc
ENV PATH="/opt/verilator/bin:/home/${USERNAME}/.local/bin:${PATH}"
ENV SYSTEMC_CXXFLAGS="-I/opt/systemc/include"
ENV SYSTEMC_LDFLAGS="-L/opt/systemc/lib -lsystemc -Wl,-rpath,/opt/systemc/lib -pthread"
ENV LD_LIBRARY_PATH="/opt/systemc/lib"
```

這樣使用者進入 container 後可以直接使用：

```bash
verilator --version
eman help
```

---

## 4.6 為什麼 release 不再直接繼承 `systemc_provider`

原本架構是：

```text
base
→ common_pkg_provider
→ verilator_provider
→ systemc_provider
→ release
```

這種寫法會讓 `systemc_provider` 繼承 Verilator 的 build tools，例如：

```text
autoconf
flex
bison
help2man
libfl-dev
zlib1g-dev
liblz4-dev
ccache
```

但 SystemC 本身主要只需要 CMake，不需要 Verilator 的 build dependencies。
因此新的架構把 Verilator 和 SystemC 拆成兩個獨立 provider：

```text
common_pkg_provider
├── verilator_provider
└── systemc_provider
```

最後再由 `release` 統一組合：

```text
release
├── COPY /opt/verilator
└── COPY /opt/systemc
```

這樣可以讓每個 stage 的責任更清楚，也可以避免 SystemC stage 攜帶不必要的套件。

---

## 4.7 為什麼 release 不直接 COPY 整個 `/usr`

`apt` 和 `pip` 安裝的內容通常會分散在：

```text
/usr/bin
/usr/lib
/usr/share
/usr/local
/etc
/var/lib/dpkg
```

如果直接使用：

```dockerfile
COPY --from=common_pkg_provider /usr /usr
```

可能造成：

| 問題          | 原因                                |
| ----------- | --------------------------------- |
| image 變大    | 整個 `/usr` 會包含大量不一定需要的檔案           |
| 覆蓋系統檔案      | 可能覆蓋 release stage 原本的系統內容        |
| 漏掉 metadata | apt package metadata 不一定只在 `/usr` |
| 難以除錯        | 無法清楚知道哪些檔案來自哪個套件                  |

因此本專案採用：

```text
一般開發工具 → 用 FROM common_pkg_provider 繼承
自己 source build 出來的工具 → 安裝到 /opt，再用 COPY --from 複製
```

也就是：

```dockerfile
FROM common_pkg_provider AS release

COPY --from=verilator_provider /opt/verilator /opt/verilator
COPY --from=systemc_provider /opt/systemc /opt/systemc
```

這樣 final image 可以保留必要工具，同時避免直接搬整個系統目錄。

---

# 5. docker.sh 功能說明

`docker.sh` 的目的不是取代 Docker，而是把本 Lab 會重複使用的 Docker 指令包起來，降低操作錯誤。

主要功能：

| 功能                       | 說明                                                         |
| ------------------------ | ---------------------------------------------------------- |
| Build image              | 建立 `aoc2026-env:latest`                                    |
| Image exists check       | `build` 前檢查 image 是否已存在，若已存在則提示使用者刪除或 rebuild              |
| Run container            | 建立或進入 `aoc2026-env`                                        |
| Clean                    | 刪除 container 和 image                                       |
| Rebuild                  | 重新建立 image                                                 |
| 狀態判斷                     | 自動判斷 container 不存在、停止、執行中、paused                           |
| Bind mount               | 把本機 repo 掛到 `/workspace/project`                           |
| CLI 參數                   | 可自訂 image name、container name、username、hostname、mount path |
| Windows Git Bash path 處理 | 避免 `/workspace/project`、`/bin/bash` 被轉成 Windows path       |

---

## 5.1 `build` 的 image 檢查

修改後 `./docker.sh build` 會先檢查 image 是否已經存在。

| 狀況        | 行為                       |
| --------- | ------------------------ |
| image 不存在 | 正常執行 `docker build`      |
| image 已存在 | 不直接覆蓋，印出提示訊息             |
| 想重新建立     | 使用 `./docker.sh rebuild` |

如果 image 已存在，會提示類似：

```text
[info] Docker image already exists: aoc2026-env:latest
[info] Skip build to avoid overwriting the existing image.

[info] If you want to remove the image manually, run:
       docker image rm aoc2026-env:latest

[info] If you want to rebuild the environment, run:
       ./docker.sh rebuild
```

這樣可以避免使用者不小心用 `build` 覆蓋已經存在的 image。

---

## 5.2 `run` 的狀態判斷

`docker.sh run` 會自動判斷 container 狀態，選擇正確操作。

| Container 狀態     | docker.sh 的處理方式                          |
| ---------------- | ---------------------------------------- |
| container 不存在    | 使用 `docker run` 建立並進入 container          |
| container 已停止    | 使用 `docker start` 啟動，再用 `docker exec` 進入 |
| container 執行中    | 直接使用 `docker exec` 進入                    |
| container paused | 使用 `docker unpause` 後再進入                 |

因此平常不需要自己判斷要用 `docker run`、`docker start` 還是 `docker exec`，只要執行：

```bash
./docker.sh run
```

---

## 5.3 Bind Mount

`docker.sh run` 會把目前 repository 掛進 container：

```text
本機 repository → /workspace/project
```

這樣可以在 container 內編譯、測試，同時檔案仍然保留在本機 Git repo 中。

如果使用 `--mount`，也可以額外掛載其他本機資料夾，例如 dataset、測試資料或 `.ssh` 資料夾。

---

## 5.4 Windows Git Bash 處理

在 Windows Git Bash 中，Linux path 可能被自動轉成 Windows path。

例如：

```text
/workspace/project
/bin/bash
```

可能被轉成：

```text
C:/Program Files/Git/workspace/project
C:/Program Files/Git/usr/bin/bash.exe
```

因此 `docker.sh` 會處理 Git Bash path conversion，避免 container 內部路徑被錯誤轉換。

---

# 6. eman 功能說明

`eman` 是 container 內的環境測試工具。  
它的目的不是建立環境，而是確認環境是否真的能使用。

Dockerfile 會把 `eman` 放到：

```text
/usr/local/bin/eman
```

因此進入 container 後可以直接執行：

```bash
eman help
```

`eman` 主要確認：

| 測試內容 | 對應指令 |
|---|---|
| C/C++ 工具版本 | `eman c-compiler-version` |
| C compiler 是否能編譯並執行範例 | `eman c-compiler-example` |
| Verilator 是否存在 | `eman check-verilator` |
| Verilator 是否能跑 Lab 0 範例 | `eman verilator-example` |
| Verilator 版本切換 | `eman change-verilator <VERSION>` |

# 7. Docker Hub Image

本環境已上傳至 Docker Hub：

```bash
docker pull capooliu0424/docker-environment:latest

使用方式：

docker run -it --rm capooliu0424/docker-environment:latest /bin/bash