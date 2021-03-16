# syntax=docker/dockerfile:1.2
ARG NODE_IMAGE_TAG=12-buster-slim
ARG GIT_BRANCH=develop
ARG DOCKER_REGISTRY_PREFIX=frappe
FROM node:${NODE_IMAGE_TAG}

ARG GIT_BRANCH

# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md#example-cache-apt-packages
# https://github.com/moby/buildkit/issues/1662
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update -y \
  && apt-get install build-essential git python2 -y && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN yarn config set cache-folder /var/cache/yarn
COPY build/erpnext-nginx/install_app.sh /install_app
RUN chmod +x /install_app
RUN --mount=type=cache,target=/var/cache/yarn /install_app erpnext https://github.com/frappe/erpnext ${GIT_BRANCH}

FROM ${DOCKER_REGISTRY_PREFIX}/frappe-nginx:${GIT_BRANCH}

COPY --from=0 /home/frappe/frappe-bench/sites/ /var/www/html/
COPY --from=0 /rsync /rsync
RUN echo "erpnext" >> /var/www/html/apps.txt

VOLUME [ "/assets" ]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
