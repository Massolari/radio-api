FROM alpine:edge
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    erlang gleam rebar3
COPY . /app
WORKDIR /app
RUN gleam build
ENTRYPOINT ["gleam"]
CMD ["run"]
EXPOSE 8000
