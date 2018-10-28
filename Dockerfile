FROM elixir:1.7.3

RUN apt-get update && apt-get install -y inotify-tools

WORKDIR "/opt/app"

RUN mix local.hex --force && mix local.rebar --force

# COPY config/* config/
COPY mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

COPY . ./

RUN mix compile

EXPOSE 8080

# Need to include this command in mix run otherwise you don't get a shell
CMD iex -S mix run --no-halt examples/playground.exs
