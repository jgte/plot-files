#!/bin/bash

DIR=$(cd $(dirname $BASH_SOURCE);pwd)

case "$1" in
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  author|Author)
    echo teixeira@csr.utexas.edu
  ;;
  dockerhub-user) #shows dockerhub usename
    echo spacegravimetry
  ;;
  github|GitHub) #shows github repo URL
    echo https://github.com/jgte/plot-files.git
  ;;
  app-name) #shows current app's name
    echo plot-files
  ;;
  version) #shows the latest version of the image
    git log --pretty=format:"%as" | head -n1
  ;;
  image|tag) #shows the image tag
    echo $($BASH_SOURCE dockerhub-user)/$($BASH_SOURCE app-name):$($BASH_SOURCE version)
  ;;
  dockerfile) #show the dockerfile
  echo "\
FROM alpine:3.9.6
$(for i in Author GitHub; do echo "LABEL $i \"$($BASH_SOURCE $i)\""; done)
RUN apk add --no-cache gnuplot git bash util-linux
WORKDIR /$($BASH_SOURCE app-name)
VOLUME /iodir
RUN git clone $($BASH_SOURCE github) . && rm -fr .git
ENTRYPOINT [\"./entrypoint.sh\"]
CMD [\"help\"]"
  ;;
  ps-a) #shows all containers IDs for the latest version of the image
    docker ps -a | grep $($BASH_SOURCE image) | awk '{print $1}'
  ;;
  ps-exited) #shows all containers IDs for the latest version of the image that have exited
    docker ps -a | grep $($BASH_SOURCE image) | awk '/Exited \(/ {print $1}'
  ;;
  clean-exited|clear-exited) #removes all exited containers for the latest version of the image
    IDs=$($BASH_SOURCE ps-exited)
    [ -z "$IDs" ] || docker rm $IDs
  ;;
  clean-none|clear-none) #removes all images with tag '<none>' as well as the corresponding containers
    for i in $(docker images | awk '/<none>/ {print $3}')
    do
      IDs=$(docker ps -a |awk '/'$i'/ {print $1}')
      [ -z "$IDs" ] || docker rm $IDs
      docker rmi $i
    done
  ;;
  images) #shows all images relevant to this app
    docker images | grep $($BASH_SOURCE dockerhub-user)/$($BASH_SOURCE app-name)
  ;;
  clean-images) #removes all images relevant to this app
    IDs=$($BASH_SOURCE images | awk '{print $3}')
    [ -z "$IDs" ] || docker rmi $IDs
  ;;
  clean-all|clear-all) #removes all relevant images and containers
    for i in clean-exited clean-images clean-none
    do
      $BASH_SOURCE $i
    done
  ;;
  push) #git adds, commits and pushes all new changes
    $DIR/git.sh
  ;;
  build) #build the docker image
    $BASH_SOURCE push
    $BASH_SOURCE dockerfile \
      | docker build -t $($BASH_SOURCE image) -
  ;;
  rebuild) #same as clean-exited clean-images build
    for i in clean-all build
    do
      $BASH_SOURCE $i || exit $?
    done
  ;;
  sh) #spins up a new container and starts an interactive shell
    [ -z "$($BASH_SOURCE images)" ] && $BASH_SOURCE build
    docker run -it --rm --volume=$PWD:/iodir $($BASH_SOURCE image) sh
  ;;
  run) #spins up a new container and passes all aditional arguments to it
    [ -z "$($BASH_SOURCE images)" ] && $BASH_SOURCE build
    docker run --rm --volume=$PWD:/iodir $($BASH_SOURCE image) ${@:2}
  ;;
  *)
    echo "ERROR: cannot handle input argument '$1'"
    exit 3
  ;;
esac