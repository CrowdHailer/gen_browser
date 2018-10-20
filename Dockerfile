FROM elixir:1.7.3

# TODO can use this to have local changes reflected in server
RUN apt-get update && apt-get install -y inotify-tools

WORKDIR "/opt/app"

RUN mix local.hex --force && mix local.rebar --force

COPY config/* config/
COPY mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

COPY . ./

RUN mix compile

EXPOSE 8080

CMD mix run --no-halt examples/bff.exs
