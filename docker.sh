#!/usr/bin/env bash
set -euo pipefail

# Prevent Git Bash path conversion as much as possible.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

COMMAND="${1:-help}"
if [[ $# -gt 0 ]]; then
    shift
fi

IMAGE_NAME="aoc2026-env:latest"
CONT_NAME="aoc2026-env"
USERNAME="aoc"
HOSTNAME="aoc2026"
DOCKERFILE="Dockerfile"
TARGET="release"
EXTRA_MOUNTS=()

usage() {
    cat <<USAGE
Usage:
  ./docker.sh build [options]
  ./docker.sh run [options]
  ./docker.sh clean [options]
  ./docker.sh rebuild [options]
  ./docker.sh help

Options:
  --image-name NAME     Docker image name, default: aoc2026-env:latest
  --cont-name NAME      Docker container name, default: aoc2026-env
  --username NAME       Container user, default: aoc
  --hostname NAME       Container hostname, default: aoc2026
  --mount PATH          Bind mount extra host path into /workspace/<basename>
  --dockerfile FILE     Dockerfile path, default: Dockerfile
  --target STAGE        Docker build target stage, default: release

Examples:
  ./docker.sh build
  ./docker.sh run
  ./docker.sh run --cont-name aoc-test
  ./docker.sh run --mount /c/Users/angelliu.LAPTOP-3NTJHQPG/Desktop
  ./docker.sh clean
  ./docker.sh rebuild
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --cont-name)
            CONT_NAME="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --mount)
            EXTRA_MOUNTS+=("$2")
            shift 2
            ;;
        --dockerfile)
            DOCKERFILE="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[error] Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

is_git_bash_windows() {
    [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || -n "${MSYSTEM:-}" ]]
}

to_host_path() {
    local path="$1"

    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$path"
    else
        echo "$path"
    fi
}

container_path() {
    local path="$1"

    if is_git_bash_windows; then
        echo "/${path}"
    else
        echo "$path"
    fi
}

docker_cmd() {
    docker "$@"
}

docker_interactive() {
    if is_git_bash_windows && command -v winpty >/dev/null 2>&1; then
        winpty docker "$@"
    else
        docker "$@"
    fi
}

image_exists() {
    docker image inspect "$IMAGE_NAME" >/dev/null 2>&1
}

container_exists() {
    docker container inspect "$CONT_NAME" >/dev/null 2>&1
}

container_status() {
    local status

    status="$(docker container inspect -f '{{.State.Status}}' "$CONT_NAME" 2>/dev/null || true)"
    status="$(echo "$status" | tr -d '\r' | tail -n 1)"

    if [[ -z "$status" ]]; then
        echo "not_existed"
    else
        echo "$status"
    fi
}

image_exists() {
    docker image inspect "$IMAGE_NAME" >/dev/null 2>&1
}

build_image() {
    if image_exists; then
        echo "[info] Docker image already exists: ${IMAGE_NAME}"
        echo "[info] Skip build to avoid overwriting the existing image."
        echo
        echo "[info] If you want to remove the image manually, run:"
        echo "       docker image rm ${IMAGE_NAME}"
        echo
        echo "[info] If you want to rebuild the environment, run:"
        echo "       ./docker.sh rebuild"
        return 0
    fi

    echo "[info] Build Docker image: ${IMAGE_NAME}"
    docker build -t "$IMAGE_NAME" -f "$DOCKERFILE" --target "$TARGET" .
}

run_container() {
    if ! image_exists; then
        echo "[info] Image does not exist. Build first."
        build_image
    fi

    local status
    status="$(container_status)"

    local project_target
    local workdir_path
    local shell_path

    project_target="$(container_path "/workspace/project")"
    workdir_path="$(container_path "/workspace/project")"
    shell_path="$(container_path "/bin/bash")"

    case "$status" in
        running)
            echo "[info] Container is already running: $CONT_NAME"
            docker_interactive exec -it "$CONT_NAME" "$shell_path"
            ;;
        exited|created)
            echo "[info] Container exists but is stopped. Starting: $CONT_NAME"
            docker_cmd start "$CONT_NAME" >/dev/null
            docker_interactive exec -it "$CONT_NAME" "$shell_path"
            ;;
        paused)
            echo "[info] Container is paused. Unpausing: $CONT_NAME"
            docker_cmd unpause "$CONT_NAME" >/dev/null
            docker_interactive exec -it "$CONT_NAME" "$shell_path"
            ;;
        not_existed|*not_existed*)
            echo "[info] Creating and running container: $CONT_NAME"

            local host_project_path
            host_project_path="$(to_host_path "$PWD")"

            local -a mount_args
            mount_args=(--mount "type=bind,source=${host_project_path},target=${project_target}")

            for path in "${EXTRA_MOUNTS[@]}"; do
                local host_path
                local base
                local target_path

                host_path="$(to_host_path "$path")"
                base="$(basename "$path")"
                target_path="$(container_path "/workspace/${base}")"

                mount_args+=(--mount "type=bind,source=${host_path},target=${target_path}")
            done

            docker_interactive run -it \
                --name "$CONT_NAME" \
                --hostname "$HOSTNAME" \
                --user "$USERNAME" \
                --workdir "$workdir_path" \
                "${mount_args[@]}" \
                "$IMAGE_NAME" \
                "$shell_path"
            ;;
        *)
            echo "[error] Unsupported container status: $status"
            echo "[hint] Try: docker rm -f $CONT_NAME"
            exit 1
            ;;
    esac
}

clean_all() {
    if container_exists; then
        echo "[info] Removing container: $CONT_NAME"
        docker_cmd rm -f "$CONT_NAME"
    else
        echo "[info] Container does not exist: $CONT_NAME"
    fi

    if image_exists; then
        echo "[info] Removing image: $IMAGE_NAME"
        docker_cmd image rm "$IMAGE_NAME"
    else
        echo "[info] Image does not exist: $IMAGE_NAME"
    fi
}

case "$COMMAND" in
    build)
        build_image
        ;;
    run)
        run_container
        ;;
    clean)
        clean_all
        ;;
    rebuild)
        clean_all
        build_image
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "[error] Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac