# Build stage
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.3.1
ARG DEBIAN_VERSION=trixie-20260202-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN useradd -m -s /bin/bash builder

USER builder
WORKDIR /home/builder/app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

COPY --chown=builder:builder mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

COPY --chown=builder:builder config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY --chown=builder:builder priv priv
COPY --chown=builder:builder lib lib
COPY --chown=builder:builder assets assets
COPY --chown=builder:builder rel rel

RUN cd assets && npm install
RUN cd assets && npx sugarcube generate --force --silent
RUN mix compile
RUN mix assets.deploy

RUN mix release

# Runtime stage
FROM debian:trixie-20260202-slim

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates \
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

COPY --from=builder --chown=nobody:root /home/builder/app/_build/prod/rel/golfex ./
RUN chmod +x /app/bin/start /app/bin/migrate /app/bin/server

USER nobody

# Run migrations then start the server
CMD ["/app/bin/start"]
