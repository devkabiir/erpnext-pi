
## Setup mDNS using avahi on pi
- `sudo apt install avahi-daemon`
- Provide unique hostnames for all rpi, they can be accessed by  
  `ssh user@rpi-hostname.local`
- Install apple bonjour service for windows clients  
  `choco install -y bonjour`  
  Make sure the service has started

## Setup docker on pi
- Install docker `sudo apt install docker.io docker-compose`
- Enable dockerd on boot  
  `sudo systemctl enable docker.service`  
  `sudo systemctl enable containerd.service`  
- Add current user to docker usergroup
http://stackoverflow.com/questions/46202475/ddg#46225471  
  `sudo usermod -aG docker $USER`  
  `exit`  
- Reboot `sudo reboot`

## Build images
    https://github.com/frappe/frappe_docker/issues/380#issuecomment-767201476

- `export DOCKER_BUILDKIT=1`
- `export COMPOSE_DOCKER_CLI_BUILD=1`
- `export DOCKER_CLI_EXPERIMENTAL=enabled`
- `export GIT_BRANCH=version-12`
- `export VERSION=<exact-version>` (Not being used currently, although used for tagging images)
- Build `frappe-nginx:version-12`  
  `export HTTP_TIMEOUT=600`  
  ```
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/frappe-nginx:${GIT_BRANCH} \
            --no-cache -f build/frappe-nginx/arm64.Dockerfile .
  ```

- [Because of the abomination that is docker](https://github.com/moby/buildkit/issues/1142)
  ```
  docker push ${DOCKER_REGISTRY_PREFIX}/frappe-nginx:${GIT_BRANCH}
  ```

- Build `erpnext-nginx:version-12`  
  ```
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/erpnext-nginx:${GIT_BRANCH} \
            --no-cache -f build/erpnext-nginx/arm64.Dockerfile .
  ```

- Build `frappe-worker:version-12`
  ```
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/frappe-worker:${GIT_BRANCH} \
            --no-cache -f build/frappe-worker/arm64.Dockerfile .
  ```

- [Because of the abomination that is docker](https://github.com/moby/buildkit/issues/1142)
  ```
  docker push ${DOCKER_REGISTRY_PREFIX}/frappe-worker:${GIT_BRANCH}
  ```

- Build `erpnext-worker:version-12`
  ```
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/erpnext-worker:${GIT_BRANCH} \
            --no-cache -f build/erpnext-worker/arm64.Dockerfile .
  ```

- Build `frappe-socketio:version-12`
  ```
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/frappe-socketio:${GIT_BRANCH} \
            --no-cache -f build/frappe-socketio/arm64.Dockerfile .
  ```


## Create site
- copy `env-local .env`
- Change site name in `.env`


## Set defaults
- Load custom modules

## Run sites
- `docker-compose up -d`
