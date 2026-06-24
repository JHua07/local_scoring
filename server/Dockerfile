# === 本地预编译后上传，服务器无需 Go 编译环境 ===
# Windows: $env:GOOS="linux"; $env:GOARCH="amd64"; $env:CGO_ENABLED="0"; go build -ldflags="-s -w" -o server .

FROM alpine:3.21
RUN apk add --no-cache ca-certificates
COPY server /server
RUN chmod +x /server
VOLUME ["/data"]
EXPOSE 10257
CMD ["/server", "--data", "/data", "--port", "10257"]
