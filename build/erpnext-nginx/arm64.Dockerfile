# syntax=docker/dockerfile:1.2
ARG NODE_IMAGE_TAG=12-buster-slim
ARG FRAPPE_VERSION=develop
ARG DOCKER_REGISTRY_PREFIX=frappe
FROM node:${NODE_IMAGE_TAG}

RUN apt-get update -y \
  && apt-get install build-essential git python2 -y && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

COPY build/erpnext-nginx/install_app.sh /install_app
RUN chmod +x /install_app

ARG ERPNEXT_VERSION=develop
ARG FRAPPE_VERSION
RUN [ -n "$ERPNEXT_VERSION" ] || exit 1
RUN /install_app erpnext https://github.com/frappe/erpnext ${ERPNEXT_VERSION}

FROM "${DOCKER_REGISTRY_PREFIX}/frappe-nginx:${FRAPPE_VERSION}"

COPY --from=0 /home/frappe/frappe-bench/sites/ /var/www/html/
COPY --from=0 /rsync /rsync
RUN echo "erpnext" >> /var/www/html/apps.txt

VOLUME [ "/assets" ]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
