# 构建阶段：编译 Go 程序
FROM golang:1.23-alpine AS builder

# 安装 ca-certificates 以便下载 IP 列表（如果需要）
RUN apk add --no-cache ca-certificates curl

WORKDIR /app

# 复制 go mod 相关文件（启用 Go module 缓存）
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 下载中国 IP 列表（可选：也可在运行时下载）
RUN curl -L -o chn_ip.txt https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chn_ip.txt || true && \
    curl -L -o chn_ip_v6.txt https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chn_ip_v6.txt || true

# 编译静态链接的二进制（CGO_ENABLED=0）
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o ech-workers ./ech-workers.go


# 最终阶段：极简运行镜像
FROM scratch

# 从构建阶段复制证书和二进制
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/ech-workers /ech-workers
COPY --from=builder /app/chn_ip.txt /chn_ip.txt
COPY --from=builder /app/chn_ip_v6.txt /chn_ip_v6.txt

# 创建非 root 用户（UID 65532 是 nobody/nogroup 在 Alpine 中的常见值，也兼容 distroless）
USER 65532

# 默认工作目录
WORKDIR /

# 默认命令（用户可通过 CMD 覆盖）
ENTRYPOINT ["/ech-workers"]
CMD ["--help"]
