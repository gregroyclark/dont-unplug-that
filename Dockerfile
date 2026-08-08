# syntax=docker/dockerfile:1
FROM swift:6.1-jammy AS build

WORKDIR /src
COPY Shared ./Shared
COPY Server ./Server
RUN swift build --configuration release --package-path Server

FROM swift:6.1-jammy-slim

RUN useradd --create-home --shell /usr/sbin/nologin vapor
WORKDIR /app
COPY --from=build /src/Server/.build/release/DontUnplugThatServer ./DontUnplugThatServer
USER vapor
EXPOSE 8080
CMD ["./DontUnplugThatServer", "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
