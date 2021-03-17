# syntax=docker/dockerfile:1.2
ARG GIT_BRANCH=develop
ARG DOCKER_REGISTRY_PREFIX=frappe
FROM ${DOCKER_REGISTRY_PREFIX}/app-worker:${GIT_BRANCH}
