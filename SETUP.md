
## Setup mDNS using avahi on pi
- `sudo apt install avahi-daemon`
- `sudo apt install avahi-utils`
- Provide unique hostnames for all rpi, they can be accessed by  
  `ssh user@rpi-hostname.local`
- Install apple bonjour service for windows clients  
  `choco install -y bonjour`  
  Make sure the service has started

## Build docker-compose for arm64


## Setup docker on pi
- For ubuntu server `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg`
- Add repo
  ```sh
  echo \
  "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  ```
- Install docker `sudo apt install docker-ce docker-ce-cli containerd.io`
- Enable dockerd on boot  
  `sudo systemctl enable docker.service`  
  `sudo systemctl enable containerd.service`  
- Add current user to docker usergroup
http://stackoverflow.com/questions/46202475/ddg#46225471  
  `sudo usermod -aG docker $USER`  
- `sudo reboot`
- `docker pull --platform linux/arm64 linuxserver/docker-compose:version-1.28.5`
- `docker tag linuxserver/docker-compose:version-1.28.5 docker/compose:1.28.5`
- `sudo curl -L --fail https://github.com/docker/compose/releases/download/1.28.5/run.sh -o /usr/local/bin/docker-compose`
- `sudo chmod +x /usr/local/bin/docker-compose`
- Reboot `sudo reboot`

## Running
- `cp env-local-arm64 .env`
- `cp avahi-alias@.service /etc/systemd/system/avahi-alias@.service`
- `systemctl enable --now avahi-alias@site-name.local.service`
  > This only works if the site name also ends with `.local` instead of `.localhost`
- `. __docker-compose__/bin/activate`
- `docker-compose --project-name <project-name> up -d

## Build using docker-compose
- `cp env-local-arm64 .env`
- Update frappe/erpnext versions in `.env` if required
- `export COMPOSE_FILE=docker-compose.arm64-build.yml`
- `docker-compose build frappe-socketio frappe-nginx frappe-worker`
- `docker-compose build erpnext-nginx erpnext-python`

## Build images
https://github.com/frappe/frappe_docker/issues/380#issuecomment-767201476

- `cp env-local-arm64 .env`
- `export DOCKER_BUILDKIT=1`
- `export COMPOSE_DOCKER_CLI_BUILD=1`
- `export DOCKER_CLI_EXPERIMENTAL=enabled`
- `export DOCKER_REGISTRY_PREFIX=devkabiir`
- `export FRAPPE_VERSION=version-12`
- `export ERPNEXT_VERSION=version-12`

- Build `frappe-socketio`
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg FRAPPE_VERSION=${FRAPPE_VERSION} \
            -t ${DOCKER_REGISTRY_PREFIX}/frappe-socketio:${FRAPPE_VERSION} \
            --no-cache -f build/frappe-socketio/arm64.Dockerfile .
  ```

- Build `frappe-nginx`  
  `export HTTP_TIMEOUT=600`  
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg FRAPPE_VERSION=${FRAPPE_VERSION} \
            -t ${DOCKER_REGISTRY_PREFIX}/frappe-nginx:${FRAPPE_VERSION} \
            --no-cache -f build/frappe-nginx/arm64.Dockerfile .
  ```

- [Because of the abomination that is docker](https://github.com/moby/buildkit/issues/1142)
  ```
  docker push ${DOCKER_REGISTRY_PREFIX}/frappe-nginx:${FRAPPE_VERSION}
  ```

- Build `erpnext-nginx`  
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg FRAPPE_VERSION=${FRAPPE_VERSION} \
            --build-arg ERPNEXT_VERSION=${ERPNEXT_VERSION} \
            -t ${DOCKER_REGISTRY_PREFIX}/erpnext-nginx:${FRAPPE_VERSION} \
            --no-cache -f build/erpnext-nginx/arm64.Dockerfile .
  ```

- Build `frappe-worker`
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg FRAPPE_VERSION=${FRAPPE_VERSION} \
            -t ${DOCKER_REGISTRY_PREFIX}/frappe-worker:${FRAPPE_VERSION} \
            --no-cache -f build/frappe-worker/arm64.Dockerfile .
  ```

- [Because of the abomination that is docker](https://github.com/moby/buildkit/issues/1142)
  ```
  docker push ${DOCKER_REGISTRY_PREFIX}/frappe-worker:${FRAPPE_VERSION}
  ```

- Build `app-worker`
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg FRAPPE_VERSION=${FRAPPE_VERSION} \
            -t ${DOCKER_REGISTRY_PREFIX}/app-worker:${FRAPPE_VERSION} \
            --no-cache -f build/app-worker/arm64.Dockerfile .
  ```

- [Because of the abomination that is docker](https://github.com/moby/buildkit/issues/1142)
  ```
  docker push ${DOCKER_REGISTRY_PREFIX}/app-worker:${FRAPPE_VERSION}
  ```

- Build/Pull `numpy:1.18.5` && `pandas:0.24.2` for erpnext
  - https://github.com/pandas-dev/pandas/issues/34969
  - https://github.com/frappe/erpnext/issues/22424
  - Run `frappe-worker` container and start bash shell
  - Activate venv, install and build wheels
    ```sh
    . env/bin/activate
    pip install wheel
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


- Build `erpnext-worker`
  ```sh
  docker buildx build \
            --load \
            --platform linux/arm64 \
            --build-arg DOCKER_REGISTRY_PREFIX=${DOCKER_REGISTRY_PREFIX} \
            --build-arg FRAPPE_VERSION=${FRAPPE_VERSION} \
            --build-arg APP_NAME=erpnext \
            --build-arg APP_REPO=https://github.com/frappe/erpnext \
            --build-arg APP_BRANCH=${ERPNEXT_VERSION} \
            -t ${DOCKER_REGISTRY_PREFIX}/erpnext-worker:${ERPNEXT_VERSION} \
            --no-cache -f build/erpnext-worker/arm64.Dockerfile .
  ```

## Create site
- copy `env-local .env`
- Change site name in `.env`


## Set defaults
- Load custom modules

## Run sites
- `docker-compose up -d`

## Wheels
If you already have an image with all python deps installed, you can cache/build wheels and then keep the built wheels locally on your host.
- Exec into your container
- `pip install wheel`
- `pip wheel --wheel-dir <easy-to-find-path> -e <path-to-app>`
- Or you can use `pip wheel --wheel-dir <easy-to-find-path> -r <requirements.txt>`
- After pip finishes building wheels, keep the container running
- On your host, use the method described above (numpy/pandas) to find the correct fs layer and cd into it.
- Copy the built wheels from `$fslayer/diff/<easy-to-find-path>` to `<this-project>`/build/you-app-worker/wheels
