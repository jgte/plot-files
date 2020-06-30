#!/bin/bash

DIR=$(cd $(dirname $BASH_SOURCE);pwd)
APPDIR=$($DIR/dockerize.sh app-dir)
IODIR=$($DIR/dockerize.sh io-dir)

case "$1" in
  sh) #run the shell instead of plot-files.sh
    exec /bin/bash -i
  ;;
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  apps) #slows all avalable apps
    exec for i in $(ls $APPDIR/plot-*); do basename $i; done
  ;;
  test-*) #tests an app (some may not yet have a test)
    exec $APPDIR/test/$1 -outdir=$IODIR
  ;;
  example-*) #shows the test script of an app
    exec cat $APPDIR/test/test-${i/example-}
  ;;
  *) #transparently pass all other arguments to ./plot-files.sh
    exec $APPDIR/$i "$@" -outdir=$IODIR
  ;;
esac