#!/bin/bash

APPDIR=/plot-files
IODIR=/iodir

case "$1" in
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  test) #test plot-files.sh
    exec $APPDIR/test/test-plot-files.sh -outdir=$IODIR
  ;;
  cat-test|example) #shows the test script
    exec cat $APPDIR/test/test-plot-files.sh 
  ;;
  sh) #run the shell instead of plot-files.sh
    exec /bin/bash -i
  ;;
  *) #transparently pass all other arguments to ./plot-files.sh
    exec $APPDIR/plot-files.sh "$@" -outdir=$IODIR
  ;;
esac