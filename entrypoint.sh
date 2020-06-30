#!/bin/bash

DIR=$(cd $(dirname $BASH_SOURCE);pwd)
APPDIR=$($DIR/dockerize.sh app-dir)
IODIR=$($DIR/dockerize.sh io-dir)

case "$1" in
  sh) #run the shell instead of an app
    exec /bin/bash -i
  ;;
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  apps) #slows all avalable apps
    for i in $(ls $APPDIR/plot-*); do basename $i; done
  ;;
  test-*) #tests an app; some may not yet have a test
    exec $APPDIR/test/$1 --outdir $IODIR ${@:2}
  ;;
  example-*) #shows the test script of an app
    exec cat $APPDIR/test/test-${1/example-}
  ;;
  help)
    echo "\
Possible arguments:
- mode
- app-name app-args

mode is one of:
$($BASH_SOURCE modes)

app-name is one of:
$($BASH_SOURCE apps)
"
  ;;
  *) #transparently pass all other arguments to ./plot-files.sh
    exec $APPDIR/$i "$@" --outdir $IODIR
  ;;
esac