
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
- `export DOCKER_REGISTRY_PREFIX=devkabiir`
- `export GIT_BRANCH=version-12`
- `export VERSION=<exact-version>` (Not being used currently, although used for tagging images)

- Build `frappe-socketio:version-12`
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/frappe-socketio:${GIT_BRANCH} \
            --no-cache -f build/frappe-socketio/arm64.Dockerfile .
  ```

- Build `frappe-nginx:version-12`  
  `export HTTP_TIMEOUT=600`  
  ```sh
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
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/erpnext-nginx:${GIT_BRANCH} \
            --no-cache -f build/erpnext-nginx/arm64.Dockerfile .
  ```

- Build `frappe-worker:version-12`
  ```sh
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

- Build `app-worker:version-12`
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/app-worker:${GIT_BRANCH} \
            --no-cache -f build/app-worker/arm64.Dockerfile .
  ```

- [Because of the abomination that is docker](https://github.com/moby/buildkit/issues/1142)
  ```
  docker push ${DOCKER_REGISTRY_PREFIX}/app-worker:${GIT_BRANCH}
  ```

- Build/Pull `erpnext-pandas:0.24.2`
  - https://github.com/pandas-dev/pandas/issues/34969
  - https://github.com/frappe/erpnext/issues/22424
  - Run `frappe-worker:verion-12` container and start bash shell
  - Activate venv, install and build wheels
    ```sh
    . env/bin/activate
    pip install numpy==1.18.5
    touch ~/running-container-canary.txt
    pip install pandas==0.24.2
    ```
  - Keep the container running so as to prevent docker from deleting and diff produced in the container
  - Copy the built wheels out of the container from host
  - `cd /var/lib/docker/overlay2` or aufs
  - ```sh
    for layer in $(ls .);  do 
      if [ -f ${layer}/diff/home/frappe/running-container-canary.txt ]; then 
          echo $layer; 
      fi; 
    done
    ```
  - After installing `numpy` and `pandas` pip will have output similar to
    ```output
    Building wheels for collected packages: numpy
    Building wheel for numpy (PEP 517) ... done
    Created wheel for numpy: filename=numpy-1.18.5-cp37-cp37m-linux_aarch64.whl size=5701535 sha256=fb72f...005cd3537
    Stored in directory: /home/frappe/.cache/pip/wheels/32/f0/3a/ebd0777...25fa572878b2a1bd8
    Successfully built numpy
    ```
    Pip will print the output directory for the built wheels
  - After figuring out the names of docker fs layers currently being used by your wheels builder container and the path inside the container, copy them out _from the host_ by using 
    ```sh
    cp $layer/diff/home/frappe/.cache/pip/wheels/../numpy-1.18.5-cp37-cp37m-linux_aarch64.whl \
    <path-to-this-project>/build/${APP_NAME}-worker/wheels
    ```
    > Pay attention to the `/diff` prefix, this is where docker keeps file changes during container runtime


- Build `erpnext-worker:version-12`
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg GIT_BRANCH=${GIT_BRANCH} \
            --build-arg APP_NAME=erpnext \
            --build-arg APP_REPO=https://github.com/frappe/erpnext \
            --build-arg APP_BRANCH=${GIT_BRANCH} \
            -t ${DOCKER_REGISTRY_PREFIX}/erpnext-worker:${GIT_BRANCH} \
            --no-cache -f build/erpnext-worker/arm64.Dockerfile .
  ```

## Create site
- copy `env-local .env`
- Change site name in `.env`


## Set defaults
- Load custom modules

## Run sites
- `docker-compose up -d`
