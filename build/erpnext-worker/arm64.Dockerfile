# syntax=docker/dockerfile:1.2
ARG FRAPPE_VERSION=develop
ARG APP_NAME=erpnext
ARG APP_REPO=https://github.com/frappe/erpnext
ARG APP_BRANCH=develop
ARG DOCKER_REGISTRY_PREFIX=frappe
FROM ${DOCKER_REGISTRY_PREFIX}/frappe-worker:${FRAPPE_VERSION}
