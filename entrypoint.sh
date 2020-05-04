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
    $APPDIR/test/test-plot-files.sh \
      && mv -v $APPDIR/test/test.png /iodir/ \
      || echo "ERROR..."
  ;;
  cat-test|example) #shows the test script
    exec cat $APPDIR/test/test-plot-files.sh 
  ;;
  sh) #run the shell instead of plot-files.sh
    exec /bin/bash -i
  ;;
  *) #transparently pass all other arguments to ./plot-files.sh
    echo "Calling plot-files.sh $@:"
    #save current dir contents
    ls -1 > /tmp/ls.$$
    #plot it
    $APPDIR/plot-files.sh "$@" || exit $?
    #diff current dir contents relative to records to get the resulting plot
    OUT=$(ls -t $(diff  <(ls -1) /tmp/ls.$$ | grep -e '^<'| sed 's:<::g' | head -n1))
    [ -z "$OUT" ] && exit 3
    mv -v $OUT /iodir/
    rm -f /tmp/ls.$$
  ;;
esac