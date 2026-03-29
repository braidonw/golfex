# Build stage
ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20250317-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets
COPY rel rel

RUN cd assets && npm install
RUN mix assets.deploy
RUN mix compile

RUN mix release

# Runtime stage
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV="prod"

WORKDIR /app

RUN chown nobody /app

# Create persistent data directory
RUN mkdir -p /app/data && chown nobody /app/data

COPY --from=builder --chown=nobody:root /app/_build/prod/rel/golfex ./

USER nobody

# Run migrations then start the server
CMD ["/app/bin/start"]
