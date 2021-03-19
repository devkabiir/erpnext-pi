FROM python:3.7-slim-buster

# Add non root user without password
RUN useradd -ms /bin/bash frappe

ARG ARCH=amd64
ENV PYTHONUNBUFFERED 1
ENV NVM_DIR=/home/frappe/.nvm
ENV NODE_VERSION=12.20.0
ENV PATH="/home/frappe/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

ENV FRAPPE_BENCH_DIR=/home/frappe/frappe-bench

# Install dependencies
WORKDIR ${FRAPPE_BENCH_DIR}

# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md#example-cache-apt-packages
# https://github.com/moby/buildkit/issues/1662
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -y \
    && apt-get install \
    # for frappe framework
    git \
    mariadb-client \
    postgresql-client \
    gettext-base \
    wget \
    wait-for-it \
    # for PDF
    libjpeg62-turbo \
    libx11-6 \
    libxcb1 \
    libxext6 \
    libxrender1 \
    libssl-dev \
    fonts-cantarell \
    xfonts-75dpi \
    xfonts-base \
    libxml2 \
    libffi-dev \
    libjpeg-dev \
    zlib1g-dev \
    # For psycopg2
    libpq-dev \
    # For arm64 python wheel builds
    gcc \
    g++ -y \
    # Detect arch, download and install wkhtmltox
    && if [ `uname -m` = 'aarch64' ]; then export ARCH=arm64; fi \
    && if [ `uname -m` = 'x86_64' ]; then export ARCH=amd64; fi \
    && wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_${ARCH}.deb \
    && dpkg -i wkhtmltox_0.12.6-1.buster_${ARCH}.deb && rm wkhtmltox_0.12.6-1.buster_${ARCH}.deb \
    && wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh \
    && chown -R frappe:frappe /home/frappe

# Setup docker-entrypoint
COPY build/common/worker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
#backwards compat
RUN ln -s /usr/local/bin/docker-entrypoint.sh /

USER frappe
# Install nvm with node
RUN bash install.sh \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install ${NODE_VERSION} \
    && nvm use v${NODE_VERSION} \
    && nvm alias default v${NODE_VERSION}

# Create frappe-bench directories
RUN mkdir -p apps logs commands sites /home/frappe/backups

# Create env
RUN python -m venv env

ARG FRAPPE_VERSION=develop
RUN [ -n "$FRAPPE_VERSION" ] || exit 1
ENV VIRTUAL_ENV="${FRAPPE_BENCH_DIR}/env"
ENV XDG_CACHE_HOME=/home/frappe/.cache
ENV PIP_WHEEL_CACHE="build/frappe-worker/wheels/*.whl"
COPY ${PIP_WHEEL_CACHE} /tmp/cache/wheels/

# This is to make sure given wheel cache is used and not overridden by subsequent pip installs
RUN \
    . env/bin/activate \
    && find /tmp/cache/wheels/ -name "*.whl" -type f -print0 | xargs -0 pip3 install

# Setup python environment
RUN \
    --mount=type=cache,target=/home/frappe/.cache \
    . env/bin/activate \
    && cd apps \
    && git clone --depth 1 -o upstream https://github.com/frappe/frappe --branch ${FRAPPE_VERSION} \
    && pip3 install --find-links /tmp/cache/wheels -e ${FRAPPE_BENCH_DIR}/apps/frappe

# Copy scripts and templates
COPY build/common/commands/* ${FRAPPE_BENCH_DIR}/commands/
COPY build/common/common_site_config.json.template /opt/frappe/common_site_config.json.template
COPY build/common/worker/install_app.sh /usr/local/bin/install_app
COPY build/common/worker/bench /usr/local/bin/bench
COPY build/common/worker/healthcheck.sh /usr/local/bin/healthcheck.sh

# Use sites volume as working directory
WORKDIR "${FRAPPE_BENCH_DIR}/sites"

VOLUME [ "${FRAPPE_BENCH_DIR}/sites", "/home/frappe/backups", "${FRAPPE_BENCH_DIR}/logs" ]

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]

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

# This is to make sure given wheel cache is used and not overridden by subsequent pip installs
ONBUILD RUN \
    find /tmp/cache/wheels/ -name "*.whl" -type f -print0 | xargs -0 pip3 install
ONBUILD RUN \
    --mount=type=cache,target=/home/frappe/.cache \
    pip3 install --find-links /tmp/cache/wheels -e /home/frappe/frappe-bench/apps/${APP_NAME}

# Use sites volume as working directory
ONBUILD WORKDIR "${FRAPPE_BENCH_DIR}/sites"

ONBUILD VOLUME [ "${FRAPPE_BENCH_DIR}/sites", "/home/frappe/backups", "${FRAPPE_BENCH_DIR}/logs" ]

ONBUILD ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
ONBUILD CMD ["start"]
