FROM mattermost/mattermost-build-server:1.24.13

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN mkdir /work

WORKDIR /work

RUN git clone -b v11.4.2 https://github.com/mattermost/mattermost && \
    sed -i 's/200/2000/' ./mattermost/server/channels/app/limits.go && \
    sed -i 's/250/2500/' ./mattermost/server/channels/app/limits.go

ENV NVM_DIR=/root/.nvm

RUN source $NVM_DIR/nvm.sh && \
    cd ./mattermost/webapp && \
    nvm install && \
    cd ../server && \
    make build-linux-amd64 && \
    make package-linux-amd64
