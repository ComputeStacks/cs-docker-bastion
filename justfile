# help
default:
    @just --list --justfile {{ justfile() }}

# build
build:
    docker pull debian:bookworm-slim
    docker build -t ghcr.io/computestacks/cs-docker-bastion:latest .
