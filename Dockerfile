FROM alpine:3.9.6

RUN apk update && apk upgrade && apk add gnuplot git bash

RUN cd $HOME && git clone https://github.com/jgte/plot-files.git

ENV PATH "$HOME/plot-files:$PATH"