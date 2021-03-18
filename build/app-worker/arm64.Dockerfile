# syntax=docker/dockerfile:1.2
ARG FRAPPE_VERSION=develop
ARG DOCKER_REGISTRY_PREFIX=frappe
FROM ${DOCKER_REGISTRY_PREFIX}/frappe-worker:${FRAPPE_VERSION}

ONBUILD WORKDIR /home/frappe/frappe-bench/apps
ONBUILD ARG APP_NAME
ONBUILD ARG APP_REPO
ONBUILD ARG APP_BRANCH
ONBUILD RUN git clone --depth 1 -o upstream ${APP_REPO} -b ${APP_BRANCH} ${APP_NAME}

ONBUILD ENV VIRTUAL_ENV=/home/frappe/frappe-bench/env
ONBUILD ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ONBUILD ENV XDG_CACHE_HOME=/home/frappe/.cache
ONBUILD ENV PIP_WHEEL_CACHE="build/${APP_NAME}-worker/wheels/*.whl"
ONBUILD COPY ${PIP_WHEEL_CACHE} /tmp/cache/wheels/
ONBUILD RUN \
    --mount=type=cache,target=${VIRTUAL_ENV} \
    --mount=type=cache,target=${XDG_CACHE_HOME} \
    pip3 install --find-links /tmp/cache/wheels -e /home/frappe/frappe-bench/apps/${APP_NAME}
