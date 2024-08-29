#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}

trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 --exclude .git --exclude vendor .

log "Launching ssh agent."
eval `ssh-agent -s`

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { if $REMOVE_PROJECT_DIRECTORY ; then log 'Removing workspace...'; rm -rf \"\$HOME/$PROJECT_DIRECTORY\" ; fi } ; log 'Removing old workspace if exist...'; rm -rf \"\$HOME/$PROJECT_DIRECTORY\" ; log 'Creating workspace directory $PROJECT_DIRECTORY...' ; mkdir -p \"\$HOME/$PROJECT_DIRECTORY\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/$PROJECT_DIRECTORY\" -xjv ; log 'Launching docker compose...' ; cd \"\$HOME/$PROJECT_DIRECTORY\" ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" pull ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --remove-orphans --build"
if $USE_DOCKER_STACK ; then
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { if $REMOVE_PROJECT_DIRECTORY ; then log 'Removing workspace...'; rm -rf \"\$HOME/$PROJECT_DIRECTORY\" ; fi } ; log 'Removing old workspace if exist...'; rm -rf \"\$HOME/$PROJECT_DIRECTORY\" ; log 'Creating workspace directory $PROJECT_DIRECTORY...' ; mkdir -p \"\$HOME/$PROJECT_DIRECTORY/$DOCKER_COMPOSE_PREFIX\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/workspace/$DOCKER_COMPOSE_PREFIX\" -xjv ; log 'Launching docker stack deploy...' ; cd \"\$HOME/workspace/$DOCKER_COMPOSE_PREFIX\" ; docker stack deploy -c \"$DOCKER_COMPOSE_FILENAME\" --prune \"$DOCKER_COMPOSE_PREFIX\""
fi
if $DOCKER_COMPOSE_DOWN ; then
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { if $REMOVE_PROJECT_DIRECTORY ; then log 'Removing workspace...'; rm -rf \"\$HOME/$PROJECT_DIRECTORY\" ; } fi ; log 'Removing old workspace if exist...'; rm -rf \"\$HOME/$PROJECT_DIRECTORY\" ; log 'Creating workspace directory $PROJECT_DIRECTORY...' ; mkdir -p \"\$HOME/$PROJECT_DIRECTORY\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/$PROJECT_DIRECTORY\" -xjv ; log 'Launching docker compose...' ; cd \"\$HOME/$PROJECT_DIRECTORY\" ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" down"
fi

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
