#!/bin/bash

# CGIヘッダー
echo "Content-type: text/html"
# CookieにCSRFトークンをセット（HttpOnlyは外してJSで読み出せるように）
echo "Set-Cookie: csrf_token=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32); Path=/; Secure; SameSite=Strict"
echo ""

HTPASSWD_FILE="/var/www/.htpasswd"
LOG_FILE="/var/log/ueba/password_change.log"

export PATH="/usr/sbin:/usr/bin:/bin"
unset IFS
unset CDPATH
unset ENV
unset BASH_ENV

# --- urldecode関数（指定の通り） ---
urldecode() {
    local data="${1//+/ }"
    printf '%b' "${data//%/\\x}"
}

# --- HTMLエスケープ関数（XSS対策） ---
html_escape() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'\''/\&apos;/g'
}

# --- GETリクエストの場合はフォーム表示のみ ---
if [ "$REQUEST_METHOD" != "POST" ]; then
    goto_html
    exit 0
fi

# --- POSTリクエスト時の処理 ---

# 1. Refererヘッダー検証
if [ "$HTTPS" = "on" ]; then
    SCHEME="https"
else
    SCHEME="http"
fi
VALID_ORIGIN="${SCHEME}://${HTTP_HOST}"
if [ -n "$HTTP_REFERER" ] && [[ ! "$HTTP_REFERER" =~ ^$VALID_ORIGIN ]]; then
    ERROR_MESSAGE="リクエストが不正です。（Referer不一致）"
    goto_html
    exit 1
fi

# 2. CSRFトークンの検証
# クライアント側から送信されたX-CSRF-Tokenヘッダー（fetch APIで送信）を取得
CSRF_TOKEN_INPUT="$HTTP_X_CSRF_TOKEN"
# クッキーから送信されたcsrf_tokenを抽出
CSRF_TOKEN_SAVED=$(echo "$HTTP_COOKIE" | sed -n 's/^.*csrf_token=\([^;]*\).*$/\1/p')
if [ -z "$CSRF_TOKEN_INPUT" ] || [ "$CSRF_TOKEN_INPUT" != "$CSRF_TOKEN_SAVED" ]; then
    ERROR_MESSAGE="リクエストが無効です。（CSRFトークン不一致）"
    goto_html
    exit 1
fi

# 3. POSTデータの取得
read -r POST_DATA
USERNAME="admin"  # ユーザー名は固定
PASSWORD=$(echo "$POST_DATA" | sed -n 's/^.*password=\([^&]*\).*$/\1/p' | urldecode)

# 4. パスワードの強度チェック（8文字以上、大文字、数字、記号[@#$%^&*+=]を含む）
if ! echo "$PASSWORD" | grep -qE '^(?=.*[A-Z])(?=.*[0-9])(?=.*[@#\$%^&*+=]).{8,}$'; then
    ERROR_MESSAGE="パスワードは次の条件を満たす必要があります。"
    goto_html
    exit 1
fi

# 5. .htpasswdに"admin"ユーザーが登録済みかチェック
if ! grep -q "^$USERNAME:" "$HTPASSWD_FILE"; then
    ERROR_MESSAGE="リクエストが無効です。"
    goto_html
    exit 1
fi

# 6. htpasswdの呼び出し（パスワードを更新）
echo "$PASSWORD" | htpasswd -b --stdin "$HTPASSWD_FILE" "$USERNAME"

# 7. ログ記録（ログエントリをSHA256でハッシュ化して保存）
LOG_ENTRY="$(date) - ユーザー: $USERNAME のパスワード変更"
echo "$LOG_ENTRY" | sha256sum >> "$LOG_FILE"

# 8. 成功メッセージの設定
SUCCESS_MESSAGE="パスワードが変更されました。"
goto_html
exit 0

# --- HTML出力関数 ---
goto_html() {
    # クッキーからCSRFトークンを抽出（GETの場合やPOST後のレスポンス用）
    if [ -n "$HTTP_COOKIE" ]; then
        CSRF_TOKEN=$(echo "$HTTP_COOKIE" | sed -n 's/^.*csrf_token=\([^;]*\).*$/\1/p')
    else
        CSRF_TOKEN=""
    fi

    echo "<!DOCTYPE html>"
    echo "<html lang='ja'>"
    echo "<head>"
    echo "  <meta charset='UTF-8'>"
    echo "  <meta name='viewport' content='width=device-width, initial-scale=1.0'>"
    echo "  <title>パスワード変更</title>"
    echo "  <style>"
    echo "    body { background-color: #333; color: #fff; font-family: Arial, sans-serif; margin: 0; padding: 0; }"
    echo "    .container { max-width: 400px; margin: 50px auto; padding: 20px; background-color: #444; border-radius: 8px; }"
    echo "    h1 { text-align: center; margin-bottom: 20px; }"
    echo "    label { display: block; margin-top: 10px; }"
    echo "    input[type='text'], input[type='password'] { width: 100%; padding: 8px; margin-top: 5px; border: none; border-radius: 4px; }"
    echo "    button { margin-top: 20px; width: 100%; padding: 10px; background-color: #5cb85c; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }"
    echo "    button:hover { background-color: #4cae4c; }"
    echo "    .message { text-align: center; margin-bottom: 10px; }"
    echo "  </style>"
    echo "  <script>"
    echo "    document.addEventListener('DOMContentLoaded', function() {"
    echo "      // CSRFトークンをCookieから取得してhiddenフィールドにセット"
    echo "      let matches = document.cookie.match(/(?:^|; )csrf_token=([^;]+)/);"
    echo "      if (matches) {"
    echo "         document.getElementById('csrf_token').value = matches[1];"
    echo "      }"
    echo "    });"
    echo "  </script>"
    echo "</head>"
    echo "<body>"
    echo "  <div class='container'>"
    echo "    <h1>パスワード変更画面</h1>"

    # POSTの場合、エラーメッセージまたは成功メッセージを表示
    if [ "$REQUEST_METHOD" = "POST" ]; then
        if [ -n "$ERROR_MESSAGE" ]; then
            echo "    <div class='message' style='color: red;'>$(html_escape "$ERROR_MESSAGE")</div>"
        elif [ -n "$SUCCESS_MESSAGE" ]; then
            echo "    <div class='message' style='color: lightgreen;'>$(html_escape "$SUCCESS_MESSAGE")</div>"
        fi
    fi

    echo "    <form id='passwordForm'>"
    echo "      <label for='username'>ユーザー名:</label>"
    echo "      <input type='text' id='username' name='username' value='admin' readonly>"
    echo "      <label for='password'>新しいパスワード:</label>"
    echo "      <input type='password' id='password' name='password' required>"
    echo "      <label for='confirm_password'>新しいパスワード(確認):</label>"
    echo "      <input type='password' id='confirm_password' name='confirm_password' required>"
    echo "      <div id='match_message'></div>"
    echo "      <input type='hidden' id='csrf_token' name='csrf_token' value=''>"
    echo "      <button type='submit'>変更</button>"
    echo "    </form>"
    echo "  </div>"
    echo "  <script>"
    echo "    document.getElementById('passwordForm').addEventListener('submit', function(event) {"
    echo "      event.preventDefault();"
    echo "      let pwd = document.getElementById('password').value;"
    echo "      let confirmPwd = document.getElementById('confirm_password').value;"
    echo "      if (pwd !== confirmPwd) {"
    echo "          document.getElementById('match_message').innerHTML = '<p style=\"color: red; text-align: center;\">パスワードが一致しません。</p>';"
    echo "          return;"
    echo "      } else {"
    echo "          document.getElementById('match_message').innerHTML = '';"
    echo "      }"
    echo "      const formData = new FormData(this);"
    echo "      fetch('/cgi-bin/change_password', {"
    echo "          method: 'POST',"
    echo "          headers: { 'X-CSRF-Token': formData.get('csrf_token') },"
    echo "          body: formData"
    echo "      }).then(response => response.text())"
    echo "        .then(data => document.body.innerHTML = data);"
    echo "    });"
    echo "  </script>"
    echo "</body>"
    echo "</html>"
}

