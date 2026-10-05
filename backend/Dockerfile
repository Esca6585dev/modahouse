FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata && adduser -D -H app
WORKDIR /app
COPY --from=build /out/server /app/server
RUN mkdir -p /app/uploads && chown app /app/uploads
USER app
ENV PORT=8080 UPLOAD_DIR=/app/uploads
EXPOSE 8080
CMD ["/app/server"]
