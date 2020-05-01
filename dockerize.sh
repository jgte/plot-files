#!/bin/bash

case "$1" in
  modes) #shows all available modes
    grep ') #' $BASH_SOURCE \
      | grep -v grep \
      | sed 's:)::g' \
      | column -t -s\#
  ;;
  test) #test plot-files.sh
    exec ./test/test-plot-files.sh && mv ./test/test.png .
  ;;
  cat-test|example) #shows the test script
    exec cat ./test/test-plot-files.sh 
  ;;
  dockerfile) #show the dockerfile
  echo "\
FROM alpine:3.9.6

RUN apk add --no-cache gnuplot git bash

WORKDIR /plot-files

RUN git clone https://github.com/jgte/plot-files.git . && rm -fr .git/

ENTRYPOINT [\"./$(basename $BASH_SOURCE)\"]

CMD [\"help\"]
"
  ;;
  build) #build the docker image
    VERSION=$(git log --pretty=format:"%as" | head -n1)
    $BASH_SOURCE dockerfile \
      | docker build -t spacegravimetry/plot-files:$VERSION -
  ;;
  *) #transparently pass all other arguments to ./plot-files.sh
    exec ./plot-files.sh "$@"
  ;;
esac