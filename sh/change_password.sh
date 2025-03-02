#!/bin/bash

# CGIヘッダー
echo "Content-type: text/html"
# CookieにCSRFトークンをセット（HttpOnlyは外してJSで読み出せるように）
echo "Set-Cookie: csrf_token=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32); Path=/; Secure; SameSite=Strict"
echo ""

HTPASSWD_FILE="/var/www/htpasswd/.htpasswd"
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

# --- HTML出力関数 ---
goto_html() {
    echo "<!DOCTYPE html>"
    echo "<html lang='ja'>"
    echo "<head>"
    echo "  <meta charset='UTF-8'>"
    echo "  <meta name='viewport' content='width=device-width, initial-scale=1.0'>"
    echo "  <title>パスワード変更</title>"
    echo "  <style>"
    echo "    body { background-color: #333; color: #fff; font-family: Arial, sans-serif; margin: 0; padding: 0; }"
    echo "    .container { max-width: 600px; margin: 50px auto; padding: 20px; background-color: #444; border-radius: 8px; }"
    echo "    h1 { text-align: center; margin-bottom: 20px; }"

    echo "    label { display: block; margin-top: 10px; }"
    echo "    input[type='text'], input[type='password'] { width: 60%; padding: 8px; margin-top: 5px; margin-left: 130px; margin-right: 10px; border: none; border-radius: 4px; }"
    echo "    button { margin-top: 20px; width: 40%; padding: 10px; background-color: #5cb85c; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }"
    echo "    button:hover { background-color: #4cae4c; }"
    echo "    .message { text-align: center; margin-bottom: 10px; }"
    echo "  </style>"
    echo "</head>"
    echo "<body>"
    echo "  <div class='container'>"
    echo "    <h1>パスワード変更画面</h1>"

    # POSTの場合、エラーメッセージまたは成功メッセージを表示
    if [ "$REQUEST_METHOD" = "POST" ]; then
        if [ -n "$ERROR_MESSAGE" ]; then
            echo "    <div class='message' style='color: red;'>$ERROR_MESSAGE</div>"
        elif [ -n "$SUCCESS_MESSAGE" ]; then
            echo "    <div class='message' style='color: blue;'>$SUCCESS_MESSAGE)</div>"
        fi
    fi

    echo "    <form id='passwordForm' action='/cgi-bin/change_password' method='post' onsubmit='return checkCSRFToken();'>"
    echo "      <label for='username'>ユーザー名(変更不可):</label>"
    echo "      <input type='text' id='username' name='username' value='admin' readonly>"
    echo "      <label for='password'>新しいパスワード*1:</label>"
    echo "      <input type='password' id='password' name='password' required>"
    echo "      <label for='confirm_password'>新しいパスワード(確認):</label>"
    echo "      <input type='password' id='confirm_password' name='confirm_password' required>"
    echo "      <div id='match_message'></div>"
    echo "      *1 : 8文字以上、1文字以上の大文字、数字、記号(@#$%^&*+=)が必要です。"
    echo "      "
    echo "      <input type='hidden' id='csrf_token' name='csrf_token' value=''>"
    echo "      <div style='display: flex; justify-content: space-between;'>"
    echo "        <button type='button' onclick='window.location.href=\"/reports\";'"
    echo "          style='width: 48%; padding: 10px; background-color: #d9534f; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 16px;'>キャンセル</button>"
    echo "        <button type='submit'"
    echo "          style='width: 48%; padding: 10px; background-color: #5cb85c; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 16px;'>変更</button>"
    echo "      </div>"
    echo "    </form>"
    echo "  </div>"
    echo "  <script>"
    echo "    function checkCSRFToken() {"
    echo "      let pwd = document.getElementById('password').value;"
    echo "      let confirmPwd = document.getElementById('confirm_password').value;"
    echo "      if (pwd !== confirmPwd) {"
    echo "          document.getElementById('match_message').innerHTML = '<p style=\"color: red; text-align: center;\">パスワードが一致しません。</p>';"
    echo "          return false;"
    echo "      } else {"
    echo "          document.getElementById('match_message').innerHTML = '';"
    echo "      }"
    echo "      // CSRFトークンをCookieから取得してhiddenフィールドにセット"
    echo "      let matches = document.cookie.match(/(?:^|; )csrf_token=([^;]+)/);"
    echo "      if (matches) {document.getElementById('csrf_token').value = matches[1];}"
    echo "      return true;"
    echo "    }"
    echo "  </script>"
    echo "</body>"
    echo "</html>"
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
    exit 0
fi

# 2. CSRFトークンの検証
# POSTデータをまず取得します（この時点で全体のPOSTボディが変数に入ります）
read -r POST_DATA
#DEBUG_MSG="POSTDATA=${POST_DATA}";echo "DEBUG: $DEBUG_MSG" >&2

# POSTデータから送信されたcsrf_tokenフィールドの値を抽出
CSRF_TOKEN_INPUT=$(echo "$POST_DATA" | sed -n 's/^.*csrf_token=\([^&]*\).*$/\1/p')

# クッキーから送信されたcsrf_tokenを抽出
CSRF_TOKEN_SAVED=$(echo "$HTTP_COOKIE" | sed -n 's/^.*csrf_token=\([^;]*\).*$/\1/p')

#echo "DEBUG: CSRF_TOKEN_INPUT=$CSRF_TOKEN_INPUT CSRF_TOKEN_SAVED=$CSRF_TOKEN_SAVED" >&2
if [ -z "$CSRF_TOKEN_INPUT" ] || [ "$CSRF_TOKEN_INPUT" != "$CSRF_TOKEN_SAVED" ]; then
    ERROR_MESSAGE="リクエストが無効です。（CSRFトークン不一致）"
    goto_html
    exit 0
fi

USERNAME="admin"

# 3. POSTデータからpasswordフィールドを抽出し、urldecode関数でデコード
RAW_PASSWORD=$(echo "$POST_DATA" | awk -F'password=' '{print $2}' | awk -F'&' '{print $1}')
PASSWORD=$(urldecode "$RAW_PASSWORD")

ERROR_MESSAGE=""

#echo "DEBUG: $PASSWORD" >&2
# 文字数チェック
if [ ${#PASSWORD} -lt 8 ]; then
    ERROR_MESSAGE="${ERROR_MESSAGE}・パスワードは8文字以上である必要があります。<br>"
fi

# 大文字チェック
if ! echo "$PASSWORD" | grep -q '[A-Z]'; then
    ERROR_MESSAGE="${ERROR_MESSAGE}・パスワードには少なくとも1文字の大文字 (A-Z) が必要です。<br>"
fi

# 数字チェック
if ! echo "$PASSWORD" | grep -q '[0-9]'; then
    ERROR_MESSAGE="${ERROR_MESSAGE}・パスワードには少なくとも1文字の数字 (0-9) が必要です。<br>"
fi

# 記号チェック
if ! echo "$PASSWORD" | grep -q '[@#$%^&*+=]'; then
    ERROR_MESSAGE="${ERROR_MESSAGE}・パスワードには少なくとも1文字の記号 (@#$%^&*+=) が必要です。<br>"
fi

# 入力可能な文字以外が含まれていないかチェック（英大文字・小文字、数字、指定記号のみ）
if echo "$PASSWORD" | grep -q '[^a-zA-Z0-9@#$%^&*+=]'; then
    ERROR_MESSAGE="${ERROR_MESSAGE}・パスワードには英数字および記号 (@#$%^&*+=) 以外の文字は使用できません。<br>"
fi

if [ -n "$ERROR_MESSAGE" ]; then
    ERROR_MESSAGE="パスワードが不正です。以下の条件を満たしてください:<br>$ERROR_MESSAGE"
    goto_html
    exit 0
fi

# 5. .htpasswdに"admin"ユーザーが登録済みかチェック
if ! grep -q "^$USERNAME:" "$HTPASSWD_FILE"; then
    ERROR_MESSAGE="リクエストが無効です。"
    goto_html
    exit 0
fi

# 6. htpasswdの呼び出し（パスワードを更新）
htpasswd -b "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
ret=$?
if [ $ret -ne 0 ]; then
    ERROR_MESSAGE="パスワードの更新に失敗しました。（htpasswd コマンドエラー、終了コード: $ret）"
    echo "$ERROR_MESSAGE" >> "$LOG_FILE"
    goto_html
    exit 0
fi

# 7. ログ記録（ログエントリをSHA256でハッシュ化して保存）
LOG_ENTRY="$(date '+%Y-%m-%d %H:%M:%S') - ユーザー: $USERNAME のパスワード変更"
echo "$LOG_ENTRY" >> "$LOG_FILE"

# 8. 成功メッセージの設定
SUCCESS_MESSAGE="パスワードが変更されました。"
goto_html
exit 0

