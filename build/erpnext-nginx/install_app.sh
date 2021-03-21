#!/bin/bash

APP_NAME=${1}
APP_REPO=${2}
APP_BRANCH=${3}

[ "${APP_BRANCH}" ] && BRANCH="-b ${APP_BRANCH}"

if [ "${FRAPPE_VERSION}" ]; then
    FRAPPE_BRANCH="-b ${FRAPPE_VERSION}"
else
    echo "FRAPPE_VERSION not specified"; exit 1
fi

mkdir -p /home/frappe/frappe-bench/sites/assets
cd /home/frappe/frappe-bench
echo -e "frappe\n${APP_NAME}" > /home/frappe/frappe-bench/sites/apps.txt

mkdir -p apps
cd apps
git clone --depth 1 https://github.com/frappe/frappe ${FRAPPE_BRANCH} && env FRAPPE_VERSION="${FRAPPE_VERSION}" bash -c 'cd frappe; { [ ! $(git rev-parse --symbolic-full-name HEAD) == "HEAD" ] || git checkout -b ${FRAPPE_VERSION}; }'
git clone --depth 1 ${APP_REPO} ${BRANCH} ${APP_NAME} && env APP_NAME="${APP_NAME}" APP_BRANCH=${APP_BRANCH} bash -c 'cd ${APP_NAME}; { [ ! $(git rev-parse --symbolic-full-name HEAD) == "HEAD" ] || git checkout -b ${APP_BRANCH}; }'

echo "Install frappe NodeJS dependencies . . ."
cd /home/frappe/frappe-bench/apps/frappe
yarn
echo "Install ${APP_NAME} NodeJS dependencies . . ."
cd /home/frappe/frappe-bench/apps/${APP_NAME}
yarn
echo "Build browser assets . . ."
cd /home/frappe/frappe-bench/apps/frappe
yarn production --app ${APP_NAME}
echo "Install frappe NodeJS production dependencies . . ."
cd /home/frappe/frappe-bench/apps/frappe
yarn install --production=true
echo "Install ${APP_NAME} NodeJS production dependencies . . ."
cd /home/frappe/frappe-bench/apps/${APP_NAME}
yarn install --production=true

mkdir -p /home/frappe/frappe-bench/sites/assets/${APP_NAME}
cp -R /home/frappe/frappe-bench/apps/${APP_NAME}/${APP_NAME}/public/* /home/frappe/frappe-bench/sites/assets/${APP_NAME}

# Add frappe and all the apps available under in frappe-bench here
echo "rsync -a --delete /var/www/html/assets/frappe /assets" > /rsync
echo "rsync -a --delete /var/www/html/assets/${APP_NAME} /assets" >> /rsync
chmod +x /rsync

rm /home/frappe/frappe-bench/sites/apps.txt
