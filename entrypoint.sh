#!/bin/bash

case "$1" in
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  test) #test plot-files.sh
    ./test/test-plot-files.sh \
      && mv -v ./test/test.png /iodir/
  ;;
  cat-test|example) #shows the test script
    exec cat ./test/test-plot-files.sh 
  ;;
  sh) #run the shell instead of plot-files.sh
    exec /bin/bash -i
  ;;
  *) #transparently pass all other arguments to ./plot-files.sh
    echo "Calling plot-files.sh $@:"
    ./plot-files.sh "$@" \
      && mv -v $(ls -t | head -n1) /iodir/
  ;;
esac