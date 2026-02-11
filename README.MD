mkdir /work && \
  cd $_

git clone https://github.com/mattermost/mattermost && \
  sed -i 's/200/2000/' ./mattermost/server/channels/app/limits.go && \
  sed -i 's/250/2500/' ./mattermost/server/channels/app/limits.go

cd ./mattermost/webapp && \
  nvm install && \
  cd ../server && \
  make build && \
  make package
