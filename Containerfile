FROM nexus.almaz-rpe.ru/mattermost/mattermost-build-server:1.24.11

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN mkdir /work

WORKDIR /work

RUN git clone https://github.com/mattermost/mattermost && \
    sed -i 's/200/2000/' ./mattermost/server/channels/app/limits.go && \
    sed -i 's/250/2500/' ./mattermost/server/channels/app/limits.go

ENV NVM_DIR=/root/.nvm

RUN source $NVM_DIR/nvm.sh && \
    cd ./mattermost/webapp && \
    nvm install && \
    cd ../server && \
    make build && \
    make package
