FROM golang:1.23-alpine AS builder
ENV GOPROXY=https://goproxy.cn,direct
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o server .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/server /server
VOLUME ["/data"]
EXPOSE 10257
CMD ["/server", "--data", "/data", "--port", "10257"]
