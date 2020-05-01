#!/bin/bash

case "$1" in
  "modes" ) #anchor
    grep '#anchor' $BASH_SOURCE  
  ;;
  "test" ) #anchor
    ./test/test-plot-files.sh && mv ./test/test.png .
  ;;
  "dockerfile") #anchor
  echo "\
FROM alpine:3.9.6

RUN apk update \
  && apk upgrade \
  && apk add --no-cache gnuplot git bash

WORKDIR /plot-files

RUN git clone https://github.com/jgte/plot-files.git . && rm -fr .git/

ENTRYPOINT [\"./$(basename $BASH_SOURCE)\"]

CMD [\"help\"]
"
  ;;
  "build") #anchor
    VERSION=$(git log --pretty=format:"%as" | head -n1)
    $BASH_SOURCE dockerfile \
      | docker build -t spacegravimetry/plot-files:$VERSION . -
  ;;
  *)
    ./plot-files.sh "$@"
  ;;
esac