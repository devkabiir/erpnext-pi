# syntax=docker/dockerfile:1.2
FROM alpine:3.10 as socketio-source
ARG FRAPPE_VERSION
RUN [ -n "$FRAPPE_VERSION" ] || exit 1
RUN apk --no-cache add curl \
    && curl "https://raw.githubusercontent.com/frappe/frappe/$FRAPPE_VERSION/socketio.js" \
    --output socketio.js \
    && curl "https://raw.githubusercontent.com/frappe/frappe/$FRAPPE_VERSION/node_utils.js" \
    --output node_utils.js

FROM node:buster-slim

# Add frappe user
RUN useradd -ms /bin/bash frappe

# Create bench directories and set ownership
RUN mkdir -p /home/frappe/frappe-bench/sites /home/frappe/frappe-bench/apps/frappe \
    && chown -R frappe:frappe /home/frappe

# Install socketio dependencies
COPY build/frappe-socketio/package.json /home/frappe/frappe-bench/apps/frappe

RUN --mount=type=cache,target=/home/frappe/frappe-bench/apps/frappe/node_modules cd /home/frappe/frappe-bench/apps/frappe \
    && npm install --only=production \
    && node --version \
    && npm --version

# Setup docker-entrypoint
COPY build/frappe-socketio/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN ln -s /usr/local/bin/docker-entrypoint.sh / # backwards compat

COPY --from=socketio-source socketio.js node_utils.js /home/frappe/frappe-bench/apps/frappe/

USER frappe

WORKDIR /home/frappe/frappe-bench/sites

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]
