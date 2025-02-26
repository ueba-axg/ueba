# Dockerfile (AlmaLinux + SSH + HTTP + HTTPS + Java 17 + inotify-tools)
# (1) ビルド用のステージ
#FROM almalinux:9.2-minimal AS builder

#RUN microdnf -y install dnf \
#    && dnf -y install epel-release \
#    && dnf -y update \
#    && dnf -y install java-17-openjdk \
#    && dnf clean all \
#    && rm -rf /var/cache/dnf

# (2) 最終的なランタイム環境 (最小化)
FROM almalinux:9.2-minimal

# システムのタイムゾーンをJST（日本時間）に設定
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    echo "Asia/Tokyo" > /etc/timezone

# ビルドした成果物だけをコピー
#COPY --from=builder /usr/lib/jvm /usr/lib/jvm
#COPY --from=builder /usr/bin/java /usr/bin/java
# 環境変数を設定（必要なら）
#ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-17.0.14.0.7-2.el9.alma.1.x86_64
#ENV PATH="$JAVA_HOME/bin:$PATH"

# システム更新 & 必要パッケージのインストール
# - httpd (Webサーバ) + mod_ssl (HTTPSサポート)
# - openssl (自己署名証明書生成)
# - openssh-server (SSHサーバ)
# - inotify-tools (ファイル監視コマンド)
# - cronie (crond)
# - findutils (findコマンド)
# - msmtp (シンプルメール送信コマンド)
# - upgrade-minimal --security (セキュリティパッチ)
RUN microdnf -y install dnf \
    && dnf -y install epel-release \
    && dnf -y update \
    && dnf -y install \
         java-21-openjdk \
         httpd \
         mod_ssl \
         openssl \
         openssh-server \
         inotify-tools \
         cronie \
         findutils \
         msmtp \
    && dnf upgrade-minimal --security -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# 各監視対象エンティティからscpするためのユーザを作成
RUN useradd -m -s /bin/bash ueba && \
    echo 'ueba:ueba@axg' | chpasswd && \
    mkdir -p /home/ueba/.ssh && \
    chown ueba:ueba /home/ueba/.ssh && \
    chmod 700 /home/ueba/.ssh

# SSH用ディレクトリ準備
RUN mkdir -p /var/run/sshd

# - パスワード認証、公開鍵認証のどちらかで認証したい場合
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# httpd.confにServernameを指定
RUN sed -i 's/^#\?ServerName .*/ServerName ueba.axg.com/' /etc/httpd/conf/httpd.conf
# httpd.confに追加設定
RUN echo '<Directory "/var/www/html/reports">' >> /etc/httpd/conf/httpd.conf
RUN echo '    AllowOverride All' >> /etc/httpd/conf/httpd.conf
RUN echo '    Require all granted' >> /etc/httpd/conf/httpd.conf
RUN echo '    Header set Content-Type "text/html; charset=UTF-8"' >> /etc/httpd/conf.d/autoindex.conf
RUN echo '</Directory>' >> /etc/httpd/conf/httpd.conf

# AIエンジンのコピー
RUN mkdir -p /opt/uebaeng
COPY ./uebaeng/* /opt/uebaeng

# EXPOSE: コンテナ内部のSSH(22), HTTP(80), HTTPS(443)
EXPOSE 22
EXPOSE 80
EXPOSE 443

# スクリプトのコピー
COPY ./sh/start.sh /home/ueba/start.sh
COPY ./sh/monitor.sh /home/ueba/monitor.sh
COPY ./sh/cleanup.sh /home/ueba/cleanup.sh
COPY ./sh/sendmail.sh /home/ueba/sendmail.sh
COPY ./sh/ff2.txt /home/ueba/ff2.txt
COPY ./html/HEADER.html /var/www/html/HEADER.html
COPY ./html/README.html /var/www/html/README.html
COPY ./html/style.css /var/www/html/style.css
COPY ./html/.htaccess /var/www/html/.htaccess
RUN  ln -s /home/ueba/cleanup.sh /etc/cron.daily/cleanup
RUN chmod +x /home/ueba/start.sh /home/ueba/monitor.sh /home/ueba/cleanup.sh /home/ueba/sendmail.sh

# コンテナ起動時のエントリーポイント
ENTRYPOINT ["/home/ueba/start.sh"]

