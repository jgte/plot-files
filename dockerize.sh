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
    git -C $DIR log --pretty=format:%ad --date=short | head -n1
  ;;
  image|tag) #shows the image tag
    echo $($BASH_SOURCE dockerhub-user)/$($BASH_SOURCE app-name):$($BASH_SOURCE version)
  ;;
  dockerfile) #show the dockerfile
  echo "\
FROM alpine:3.9.6
$(for i in Author GitHub; do echo "LABEL $i \"$($BASH_SOURCE $i)\""; done)
# https://github.com/pavlov99/docker-gnuplot/blob/master/Dockerfile
RUN apk add --no-cache --update \
    git \
    bash \
    util-linux \
    gnuplot \
    fontconfig \
    ttf-ubuntu-font-family \
    msttcorefonts-installer \
    && update-ms-fonts \
    && fc-cache -f 
WORKDIR /$($BASH_SOURCE app-name)
VOLUME /iodir
ENTRYPOINT [\"./entrypoint.sh\"]
CMD [\"help\"]
RUN git clone $($BASH_SOURCE github) . && rm -fr .git"
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
    [ -z "$IDs" ] || docker rmi -f $IDs
  ;;
  clean-all|clear-all) #removes all relevant images and containers
    for i in clean-exited clean-images clean-none
    do
      $BASH_SOURCE $i
    done
  ;;
  git-push) #git adds, commits and pushes all new changes
    $DIR/git.sh
  ;;
  push) #pushes images to dockerhub
    docker push $($BASH_SOURCE image)
  ;;
  build) #build the docker image
    $BASH_SOURCE git-push
    $BASH_SOURCE dockerfile \
      | docker build -t $($BASH_SOURCE image) -
  ;;
  rebuild) #same as clean-exited clean-images build
    for i in clean-all build
    do
      $BASH_SOURCE $i || exit $?
    done
  ;;
  sh) #spins up a new container and starts an interactive shell in it
    [ -z "$($BASH_SOURCE images)" ] && $BASH_SOURCE build
    docker run -it --rm --volume=$PWD:/iodir $($BASH_SOURCE image) sh
  ;;
  run) #spins up a new container and passes all aditional arguments to it
    [ -z "$($BASH_SOURCE images)" ] && $BASH_SOURCE build
    docker run --rm --volume=$PWD:/iodir $($BASH_SOURCE image) ${@:2}
  ;;
  # ---------- TACC stuff ---------
  s-image)
    echo $DIR/$($BASH_SOURCE app-name)_$($BASH_SOURCE version).sif
  ;;
  s-pull)
    module load tacc-singularity
    singularity pull docker://$($BASH_SOURCE image)
  ;;
  s-sh)
    module load tacc-singularity
    [ -e $($BASH_SOURCE s-image) ] || $BASH_SOURCE s-pull
    singularity shell $($BASH_SOURCE s-image)
  ;;
  s-run)
    module load tacc-singularity
    [ -e $($BASH_SOURCE s-image) ] || $BASH_SOURCE s-pull
    singularity exec --cleanenv $($BASH_SOURCE s-image) $DIR/plot-files.sh ${@:2}
  ;;
  s-test)
    module load tacc-singularity
    [ -e $($BASH_SOURCE s-image) ] || $BASH_SOURCE s-pull
    singularity exec --cleanenv $($BASH_SOURCE s-image) $DIR/test/test-plot-files.sh ${@:2}
  ;;
  s-slurm-script)
    echo "\
#!/bin/bash

#SBATCH -J $($BASH_SOURCE app-name)
#SBATCH -o $($BASH_SOURCE app-name).o.%j
#SBATCH -e $($BASH_SOURCE app-name).e.%j
#SBATCH -p grace-serial
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 00:01:00
#SBATCH -A A-byab

module load tacc-singularity

singularity exec --cleanenv $($BASH_SOURCE s-image) $DIR/plot-files.sh ${@:2}
"
  ;;
  s-submit)
    $($BASH_SOURCE s-slurm-script) > $PWD/$($BASH_SOURCE app-name).slurm
    sbatch $PWD/$($BASH_SOURCE app-name).slurm
  ;;
  *)
    echo "ERROR: cannot handle input argument '$1'"
    exit 3
  ;;
esac