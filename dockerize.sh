#!/bin/bash

DIR=$(cd $(dirname $BASH_SOURCE);pwd)

case "$1" in
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  dockerhub-user) #shows all available modes
    echo spacegravimetry
  ;;
  github-repo) #shows all available modes
    echo https://github.com/jgte/plot-files.git
  ;;
  app-name) #shows all available modes
    echo plot-files
  ;;
  version) #shows the latest version of the image
    git log --pretty=format:"%as" | head -n1
  ;;
  image) #shows all available modes
    echo $($BASH_SOURCE dockerhub-user)/$($BASH_SOURCE app-name):$($BASH_SOURCE version)
  ;;
  dockerfile) #show the dockerfile
  echo "\
FROM alpine:3.9.6

RUN apk add --no-cache gnuplot git bash

WORKDIR /$($BASH_SOURCE app-name)

RUN git clone $($BASH_SOURCE github-repo) .

ENTRYPOINT [\"./entrypoint.sh\"]

CMD [\"help\"]
"
  ;;
  ps-a) #shows all containers IDs for the latest version of the image
    docker ps -a | grep $($BASH_SOURCE image) | awk '{print $1}'
  ;;
  ps-exited) #shows all containers IDs for the latest version of the image that have exited
    docker ps -a | grep $($BASH_SOURCE image) | awk '/Exited \(/ {print $1}'
  ;;
  clean-exited) #removes all exited containers for the latest version of the image
    IDs=$($BASH_SOURCE ps-exited)
    [ -z "$IDs" ] && echo "No exited containers found" || docker rm $IDs
  ;;
  images) #shows all images relevant to this app
    docker images | grep $($BASH_SOURCE dockerhub-user)/$($BASH_SOURCE app-name)
  ;;
  clean-images) #removes all images relevant to this app
    IDs=$($BASH_SOURCE images | awk '{print $3}')
    [ -z "$IDs" ] && echo "No relevant images found" || docker rmi $IDs
  ;;
  push) #git adds, commits and pushes all new changes
    $DIR/git.sh
  ;;
  build) #build the docker image
    $BASH_SOURCE push
    $BASH_SOURCE dockerfile \
      | docker build -t $($BASH_SOURCE image) -
  ;;
  rebuild) #
    for i in clean-exited clean-images build
    do
      $BASH_SOURCE $i || exit $?
    done
  ;;
  run) #spins up a new container and passes all aditional arguments to it
    [ -z "$($BASH_SOURCE images)" ] && $BASH_SOURCE build
    docker run $($BASH_SOURCE image) ${@:2}
  ;;
  *)
    echo "ERROR: cannot handle input argument '$1'"
    exit 3
  ;;
esac