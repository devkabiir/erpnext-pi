# syntax=docker/dockerfile:1.2
# This image uses nvm and same base image as the worker image.
# This is done to ensures that node-sass binary remains common.
# node-sass is required to enable website theme feature used
# by Website Manager role in Frappe Framework
FROM python:3.7-slim-buster

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -y \
    && apt-get install wget python2 git build-essential -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=12.20.0
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

RUN wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh \
    && chmod +x install.sh
RUN ./install.sh \
    && . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION} \
    && nvm use v${NODE_VERSION}

# https://stackoverflow.com/a/52196681/6552940
# https://github.com/nodejs/docker-node/issues/813#issuecomment-407339011
RUN npm config set unsafe-perm true
RUN npm install -g yarn

RUN node --version \
    && npm --version \
    && yarn --version

WORKDIR /home/frappe/frappe-bench
RUN mkdir -p /home/frappe/frappe-bench/sites \
    && echo "frappe" > /home/frappe/frappe-bench/sites/apps.txt

ARG FRAPPE_VERSION=develop
RUN mkdir -p apps sites/assets/css  \
    && cd apps \
    && git clone --depth 1 https://github.com/frappe/frappe --branch $FRAPPE_VERSION \
    && [ ! $(git rev-parse --symbolic-full-name HEAD) == "HEAD" ] || git branch $FRAPPE_VERSION

RUN yarn config set cache-folder /var/cache/yarn

RUN --mount=type=cache,target=/var/cache/yarn \
    --mount=type=cache,target=/home/frappe/frappe-bench/apps/frappe/node_modules \
    cd /home/frappe/frappe-bench/apps/frappe \
    && yarn --verbose --prefer-offline --frozen-lockfile

# We don't cache mount here because yarn will delete dev-dependencies in the resulting cache
# dev-dependencies should only be deleted inside the final image and not the resulting cache
RUN cd /home/frappe/frappe-bench/apps/frappe \
    && yarn run production \
    && yarn --verbose install --prefer-offline --frozen-lockfile --production=true

RUN git clone --depth 1 https://github.com/frappe/bench /tmp/bench \
    && mkdir -p /var/www/error_pages \
    && cp -r /tmp/bench/bench/config/templates /var/www/error_pages

RUN mkdir -p /home/frappe/frappe-bench/sites/assets/frappe/ \
    && cp -R /home/frappe/frappe-bench/apps/frappe/frappe/public/* /home/frappe/frappe-bench/sites/assets/frappe \
    && cp -R /home/frappe/frappe-bench/apps/frappe/node_modules /home/frappe/frappe-bench/sites/assets/frappe/

FROM nginx:latest

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -y \
    && apt-get install -y rsync && apt-get clean \
    && echo "#!/bin/bash" > /rsync \
    && chmod +x /rsync

COPY --from=0 /home/frappe/frappe-bench/sites /var/www/html/
COPY --from=0 /var/www/error_pages /var/www/
COPY build/common/nginx-default.conf.template /etc/nginx/conf.d/default.conf.template
COPY build/frappe-nginx/docker-entrypoint.sh /


VOLUME [ "/assets" ]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
