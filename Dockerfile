# 构建阶段：编译 Go 程序
FROM golang:1.23-alpine AS builder

# 安装 ca-certificates 和 curl（用于下载 IP 列表）
RUN apk add --no-cache ca-certificates curl

WORKDIR /app

RUN go mod init github.com/Liyouran-center/ech-wk
RUN go mod tidy

COPY . .

RUN curl -L -o chn_ip.txt https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chn_ip.txt || true && \
    curl -L -o chn_ip_v6.txt https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chn_ip_v6.txt || true

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o ech-workers ./ech-workers.go


# 最终阶段：极简运行镜像
FROM scratch

# 从构建阶段复制必要文件
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/ech-workers /ech-workers
COPY --from=builder /app/chn_ip.txt /chn_ip.txt
COPY --from=builder /app/chn_ip_v6.txt /chn_ip_v6.txt

# 使用非 root 用户（UID 65532 = nobody）
USER 65532

WORKDIR /

ENTRYPOINT ["/ech-workers"]
CMD ["--help"]