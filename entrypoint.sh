#!/bin/bash

APPDIR=/plot-files

case "$1" in
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  test) #test plot-files.sh
    $APPDIR/test/test-plot-files.sh && mv -v $APPDIR/test/test.png $APPDIR/
  ;;
  cat-test|example) #shows the test script
    exec cat $APPDIR/test/test-plot-files.sh 
  ;;
  sh) #run the shell instead of plot-files.sh
    exec /bin/bash -i
  ;;
  *) #transparently pass all other arguments to ./plot-files.sh
    echo "Calling plot-files.sh $@:"
    #plot it
    $APPDIR/plot-files.sh "$@" || exit $?
  ;;
esac