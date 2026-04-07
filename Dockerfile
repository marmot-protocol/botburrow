# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t botburrow .
# docker run -d -p 80:80 -e SECRET_KEY_BASE=$(openssl rand -hex 64) --name botburrow botburrow

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2


# Stage 1: Compile wnd (WhiteNoise daemon) from source
FROM rust:slim AS wnd-build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libssl-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /src
COPY vendor/whitenoise-rs .
RUN cargo build --release --features cli --bin wnd


# Stage 2: Ruby base image shared by build and runtime
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"


# Stage 3: Build gems and precompile assets
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .
# Rust source already compiled in wnd-build stage; drop from the app tree
RUN rm -rf vendor/whitenoise-rs

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Stage 4: Final runtime image
FROM base

# wnd data and socket default paths (inside the persisted storage volume)
ENV WND_DATA_DIR="/rails/storage/wnd" \
    WND_SOCKET_PATH="/rails/storage/wnd/release/wnd.sock"

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy wnd binary from Rust build stage
COPY --from=wnd-build /src/target/release/wnd /usr/local/bin/wnd

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database and starts background services.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost/up || exit 1

# Start server via Thruster by default, this can be overwritten at runtime
CMD ["./bin/thrust", "./bin/rails", "server"]
