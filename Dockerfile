# Dockerfile (AlmaLinux + SSH + HTTP + HTTPS + Java 17 + inotify-tools)
# (1) ビルド用のステージ
FROM almalinux:9.2-minimal AS builder

RUN microdnf -y install dnf \
    && dnf -y install epel-release \
    && dnf -y update \
    && dnf -y install java-17-openjdk-headless \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# (2) 最終的なランタイム環境 (最小化)
FROM almalinux:9.2-minimal

# システムのタイムゾーンをJST（日本時間）に設定
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone

# ビルドした成果物だけをコピー
COPY --from=builder /usr/lib/jvm /usr/lib/jvm

# システム更新 & 必要パッケージのインストール
# - httpd (Webサーバ) + mod_ssl (HTTPSサポート)
# - openssl (自己署名証明書生成)
# - openssh-server (SSHサーバ)
# - java-17-openjdk (Java 17 ランタイム/JDK)
# - inotify-tools (ファイル監視コマンド)
RUN microdnf -y install dnf \
    && dnf -y install epel-release \
    && dnf -y update \
    && dnf -y install \
         httpd \
         mod_ssl \
         openssl \
         openssh-server \
         inotify-tools \
         cronie \
         findutils \
    && dnf upgrade-minimal --security -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# 各監視対象エンティティからscpするためのユーザを作成
RUN useradd -m -s /bin/bash ueba && \
    # echo 'ueba:ueba@axg' | chpasswd
    # 必要に応じて ueba のホームに SSH 公開鍵を設置する場合:
    echo 'ueba:ueba@axg' | chpasswd && \
    mkdir -p /home/ueba/.ssh && \
    chown ueba:ueba /home/ueba/.ssh && \
    chmod 700 /home/ueba/.ssh

# SSH用ディレクトリ準備
RUN mkdir -p /var/run/sshd

# - PasswordAuthentication no など、公開鍵認証のみ許可したい場合は記述
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# 以下はrootユーザのログインを許可する場合のみ
# RUN mkdir -p /var/run/sshd \
    # && sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    # && echo 'root:ueba@axg' | chpasswd

# httpd.confにServernameを指定
RUN sed -i 's/^#\?ServerName .*/ServerName ueba.axg.com/' /etc/httpd/conf/httpd.conf

# EXPOSE: コンテナ内部のSSH(22), HTTP(80), HTTPS(443)
EXPOSE 22
EXPOSE 80
EXPOSE 443

# スクリプトのコピー
COPY ./sh/start.sh /home/ueba/start.sh
COPY ./sh/monitor.sh /home/ueba/monitor.sh
COPY ./sh/cleanup.sh /home/ueba/cleanup.sh
RUN  ln -s /home/ueba/cleanup.sh /etc/cron.daily/cleanup
RUN chmod +x /home/ueba/start.sh /home/ueba/monitor.sh /home/ueba/cleanup.sh

# コンテナ起動時のエントリーポイント
ENTRYPOINT ["/home/ueba/start.sh"]

