#!/bin/bash -uex

DIR=$(cd $(dirname $BASH_SOURCE);pwd)
MODE="$(echo "$1"| tr '[:upper:]' '[:lower:]')"
case "$MODE" in
  modes|help|-h) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  author|dockerhub-user|github|app-name|apk-list|base-image|run-more) #get app parameters from dockerize.par
    awk '/^'$MODE' / {for (i=2; i<=NF; i++) printf("%s ",$i)}' $DIR/dockerize.par
  ;;
  app-dir) #shows the directory where the app will be sitting inside the container
    echo /$($BASH_SOURCE app-name)
  ;;
  io-dir) #shows the directory where the files will be save to inside the container
    echo /iodir
  ;;
  version) #shows the latest version of the image
    git -C $DIR log --pretty=format:%ad --date=short | head -n1
  ;;
  is-docker-running) #checks if the docker deamon is running
    docker ps -a > /dev/null && exit 0 || exit 1
  ;;
  base-image) #shows the name if the base image
    echo $($BASH_SOURCE dockerhub-user)/gnuplot:latest
  ;;
  base-rebuild) #build the base image (slow, should not change significantly)
    $BASH_SOURCE is-docker-running || exit 1
    IDs=$($BASH_SOURCE base-image | awk '{print $3}')
    [ -z "$IDs" ] || docker rmi -f $IDs
  echo "\
FROM alpine:3.9.6
RUN apk add --no-cache --update \
$($BASH_SOURCE apk-list)
" | docker build -t $($BASH_SOURCE base-image) -
    docker push $($BASH_SOURCE base-image)
  ;;
  image|tag) #shows the image tag
    echo $($BASH_SOURCE dockerhub-user)/$($BASH_SOURCE app-name):$($BASH_SOURCE version)
  ;;
  url) #shows the docker image URL
    echo docker://$($BASH_SOURCE image)
  ;;
  dockerfile) #show the dockerfile
  echo "\
FROM $($BASH_SOURCE base-image)
$(for i in Author GitHub; do echo "LABEL $i \"$($BASH_SOURCE $i)\""; done)
VOLUME $($BASH_SOURCE io-dir)
WORKDIR $($BASH_SOURCE app-dir)
ENTRYPOINT [\"./entrypoint.sh\"]
RUN git clone $($BASH_SOURCE github) . && rm -fr .git $($BASH_SOURCE run-more)"
  ;;
  ps-a) #shows all containers IDs for the latest version of the image
    $BASH_SOURCE is-docker-running || exit 1
    docker ps -a | grep $($BASH_SOURCE image) | awk '{print $1}'
  ;;
  ps-exited) #shows all containers IDs for the latest version of the image that have exited
    $BASH_SOURCE is-docker-running || exit 1
    docker ps -a | grep $($BASH_SOURCE image) | awk '/Exited \(/ {print $1}'
  ;;
  images) #shows all images relevant to this app
    $BASH_SOURCE is-docker-running || exit 1
    docker images | grep $($BASH_SOURCE dockerhub-user)/$($BASH_SOURCE app-name)
  ;;
  clean-none|clear-none) #removes all images with tag '<none>' as well as the corresponding containers
    $BASH_SOURCE is-docker-running || exit 1
    for i in $(docker images | awk '/<none>/ {print $3}')
    do
      IDs=$(docker ps -a |awk '/'$i'/ {print $1}')
      [ -z "$IDs" ] || docker rm $IDs
      docker rmi $i
    done
  ;;
  clean-exited|clear-exited) #removes all exited containers for the latest version of the image
    $BASH_SOURCE is-docker-running || exit 1
    IDs=$($BASH_SOURCE ps-exited)
    [ -z "$IDs" ] || docker rm $IDs
  ;;
  clean-images) #removes all images relevant to this app
    $BASH_SOURCE is-docker-running || exit 1
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
    $BASH_SOURCE is-docker-running || exit 1
    docker push $($BASH_SOURCE image)
  ;;
  build) #build the docker image
    $BASH_SOURCE is-docker-running || exit 1
    $BASH_SOURCE git-push
    $BASH_SOURCE dockerfile \
      | docker build -t $($BASH_SOURCE image) -
  ;;
  rebuild) #same as clean-exited clean-images build
    for i in clean-all build push
    do
      $BASH_SOURCE $i || exit $?
    done
  ;;
  sh) #spins up a new container and starts an interactive shell in it
    $BASH_SOURCE is-docker-running || exit 1
    [ -z "$($BASH_SOURCE images)" ] && $BASH_SOURCE build
    docker run -it --rm --volume=$PWD:$($BASH_SOURCE io-dir) $($BASH_SOURCE image) sh
  ;;
  run) #spins up a new container and passes all aditional arguments to it
    $BASH_SOURCE is-docker-running || exit 1
    [ -z "$($BASH_SOURCE images)" ] && $BASH_SOURCE build
    docker run --rm --volume=$PWD:$($BASH_SOURCE io-dir) $($BASH_SOURCE image) ${@:2}
  ;;
  # ---------- TACC stuff ---------
  s-module) #load singularity module in tacc
    if which module
    then
      module load tacc-singularity
    else
      echo "WARNING: cannot load module, possibly this is not a TACC machine?"
      exit 3
    fi
  ;;
  s-image) #return the name of the singularity image file
    echo $DIR/$($BASH_SOURCE app-name)_$($BASH_SOURCE version).sif
  ;;
  s-pull) #pulls the singularity image from docker hub
    $BASH_SOURCE s-module || true
    singularity pull --name $($BASH_SOURCE s-image) docker://$($BASH_SOURCE image)
  ;;
  s-sh) #spins up a new singularity container and starts an interactive shell in it
    $BASH_SOURCE s-module || true
    [ -e $($BASH_SOURCE s-image) ] || $BASH_SOURCE s-pull
    singularity shell -B $PWD:$($BASH_SOURCE io-dir) --cleanenv $($BASH_SOURCE s-image)
  ;;
  s-shw) #spins up a new writable singularity container and starts an interactive shell in it
    $BASH_SOURCE s-module || true
    [ -e $($BASH_SOURCE s-image)w ] || singularity build --sandbox $($BASH_SOURCE s-image)w docker://$($BASH_SOURCE image)
    singularity shell -B $PWD:$($BASH_SOURCE io-dir) --cleanenv $($BASH_SOURCE s-image)w
  ;;
  s-com) #shows the command used to run the app it the singularity container
   echo singularity exec -B $PWD:/$($BASH_SOURCE io-dir) --cleanenv $($BASH_SOURCE s-image) $($BASH_SOURCE app-dir)/entrypoint.sh ${@:2}
  ;; 
  s-run) #spins up a new singularity container and passes all aditional arguments to it
    $BASH_SOURCE s-module || true
    [ -e $($BASH_SOURCE s-image) ] || $BASH_SOURCE s-pull
    $($BASH_SOURCE s-com) ${@:2}
  ;;
  s-slurm-script) #shows the slurm script used to commit an instance of the app to the grace-serial queue
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

$($BASH_SOURCE s-com) $(for i in "${@:2}"; do echo -n "\"$i\" "; done)
"
  ;;
  s-submit) #submits a job with a call to the app to the grace-queue
    $BASH_SOURCE s-slurm-script "${@:2}" > $PWD/$($BASH_SOURCE app-name).slurm
    sbatch $PWD/$($BASH_SOURCE app-name).slurm
  ;;
  *)
    echo "ERROR: cannot handle input argument '$1'"
    exit 3
  ;;
esac