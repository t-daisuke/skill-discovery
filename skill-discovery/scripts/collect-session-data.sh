#!/bin/bash
# セッションログから「指示→操作」ペアを収集するスクリプト
# 引数: 日付 (YYYY-MM-DD) または "yesterday" または "week" または 空（今日）
#
# - subagentsは除外（メインセッションのみ）
# - ユーザーメッセージ（指示）とその直後のツール使用（操作）を抽出
# - 更新日時で事前フィルタリングして高速化

set -e

# OS判定
is_macos() { [[ "$(uname)" == "Darwin" ]]; }

# 日付計算のラッパー
date_calc() {
  local base_date="$1" offset="$2" # offset: -1, +1 など
  if is_macos; then
    date -j -v"${offset}d" -f "%Y-%m-%d" "$base_date" +%Y-%m-%d 2>/dev/null || echo "$base_date"
  else
    date -d "$base_date ${offset} day" +%Y-%m-%d 2>/dev/null || echo "$base_date"
  fi
}

# ファイルの更新日時を取得
file_mtime() {
  if is_macos; then
    stat -f "%Sm" -t "%Y-%m-%d" "$1" 2>/dev/null
  else
    stat -c "%Y" "$1" 2>/dev/null | cut -c1-10 | xargs -I{} date -d "@{}" +%Y-%m-%d 2>/dev/null
  fi
}

# UTCタイムスタンプをローカル日付に変換
timestamp_to_date() {
  local ts="$1"
  if is_macos; then
    local utc_datetime="${ts%.*}+0000"
    date -j -f "%Y-%m-%dT%H:%M:%S%z" "$utc_datetime" "+%Y-%m-%d" 2>/dev/null
  else
    date -d "$ts" "+%Y-%m-%d" 2>/dev/null
  fi
}

# 機密情報をフィルタリング
filter_sensitive() {
  sed -E \
    -e 's/(password|passwd|pwd|secret|token|api[_-]?key|auth|credential)[=:][^ ]+/\1=***REDACTED***/gi' \
    -e 's/Bearer [a-zA-Z0-9._-]+/Bearer ***REDACTED***/g' \
    -e 's/ghp_[a-zA-Z0-9]+/ghp_***REDACTED***/g' \
    -e 's/gho_[a-zA-Z0-9]+/gho_***REDACTED***/g' \
    -e 's/sk-[a-zA-Z0-9]+/sk-***REDACTED***/g'
}

# セッションファイルを処理して指示→操作ペアを出力
process_session() {
  local filepath="$1"
  local project="$2"

  # メタ情報を最初のuserメッセージから取得
  local first_user_line=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null)
  local cwd=$(echo "$first_user_line" | jq -r '.cwd // "unknown"')
  local branch=$(echo "$first_user_line" | jq -r '.gitBranch // ""')

  echo "## セッション: $project"
  echo "- 作業ディレクトリ: $cwd"
  [ -n "$branch" ] && echo "- ブランチ: $branch"
  echo ""

  # jqで指示→操作ペアを抽出
  # 1. userメッセージ（指示）を取得
  # 2. その直後のassistantメッセージからtool_useを抽出

  local instruction_count=0
  local current_instruction=""
  local in_instruction=false

  while IFS= read -r line; do
    local msg_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

    if [ "$msg_type" = "user" ]; then
      # 前の指示があれば出力
      if [ "$in_instruction" = true ] && [ -n "$current_instruction" ]; then
        echo ""
      fi

      # 新しい指示を開始
      instruction_count=$((instruction_count + 1))

      # ユーザーメッセージの内容を取得
      local content=$(echo "$line" | jq -r '
        if .message.content | type == "string" then
          .message.content | split("\n")[0][:200]
        else
          ((.message.content[] | select(.type == "text") | .text | split("\n")[0][:200]) // "")
        end
      ' 2>/dev/null)

      # system-reminderタグや空の指示をスキップ
      if [ -n "$content" ] && [[ ! "$content" =~ ^[[:space:]]*$ ]] && [[ ! "$content" =~ "<system-reminder>" ]]; then
        current_instruction="$content"
        in_instruction=true
        echo "### 指示$instruction_count: $current_instruction"
        echo "操作:"
      else
        in_instruction=false
        current_instruction=""
      fi

    elif [ "$msg_type" = "assistant" ] && [ "$in_instruction" = true ]; then
      # assistantメッセージからtool_useを抽出
      echo "$line" | jq -r '
        .message.content[]? | select(.type == "tool_use") |
        if .name == "Bash" then
          "- Bash: " + (.input.command // "" | split("\n")[0][:150])
        elif .name == "Read" then
          "- Read: " + (.input.file_path // "")
        elif .name == "Write" then
          "- Write: " + (.input.file_path // "")
        elif .name == "Edit" then
          "- Edit: " + (.input.file_path // "")
        elif .name == "Grep" then
          "- Grep: " + (.input.pattern // "") + " (path: " + (.input.path // ".") + ")"
        elif .name == "Glob" then
          "- Glob: " + (.input.pattern // "")
        elif .name == "Task" then
          "- Task: " + (.input.description // "")
        else
          empty
        end
      ' 2>/dev/null | filter_sensitive
    fi
  done < "$filepath"

  echo ""
}

# 対象日付を決定
MODE="single"
if [ -n "$1" ]; then
  case "$1" in
    yesterday)
      TARGET_DATE=$(date_calc "$(date +%Y-%m-%d)" -1)
      ;;
    week)
      MODE="week"
      END_DATE=$(date +%Y-%m-%d)
      START_DATE=$(date_calc "$END_DATE" -6)
      ;;
    *)
      TARGET_DATE="$1"
      ;;
  esac
else
  TARGET_DATE=$(date +%Y-%m-%d)
fi

# 日付範囲内かチェックする関数
is_in_range() {
  local check_date="$1"
  if [ "$MODE" = "week" ]; then
    [ "$check_date" \> "$START_DATE" ] || [ "$check_date" = "$START_DATE" ]
    local gte_start=$?
    [ "$check_date" \< "$END_DATE" ] || [ "$check_date" = "$END_DATE" ]
    local lte_end=$?
    [ $gte_start -eq 0 ] && [ $lte_end -eq 0 ]
  else
    [ "$check_date" = "$TARGET_DATE" ]
  fi
}

# ヘッダー出力
if [ "$MODE" = "week" ]; then
  echo "# セッションデータ - $START_DATE 〜 $END_DATE"
else
  echo "# セッションデータ - $TARGET_DATE"
fi
echo ""

# 更新日時フィルタ用の日付範囲を計算
if [ "$MODE" = "week" ]; then
  DATE_PREV=$(date_calc "$START_DATE" -1)
  DATE_NEXT=$(date_calc "$END_DATE" +1)
else
  DATE_PREV=$(date_calc "$TARGET_DATE" -1)
  DATE_NEXT=$(date_calc "$TARGET_DATE" +1)
fi

# セッションログを走査（subagentsは除外）
find ~/.claude/projects -name "*.jsonl" -type f -not -path "*/subagents/*" 2>/dev/null | while read -r filepath; do
  # 1. 更新日時で事前フィルタリング（高速）
  file_mtime=$(file_mtime "$filepath") || continue

  # weekモードの場合は範囲チェック
  if [ "$MODE" = "week" ]; then
    if [ "$file_mtime" \< "$DATE_PREV" ] || [ "$file_mtime" \> "$DATE_NEXT" ]; then
      continue
    fi
  else
    if [ "$file_mtime" != "$TARGET_DATE" ] && [ "$file_mtime" != "$DATE_PREV" ] && [ "$file_mtime" != "$DATE_NEXT" ]; then
      continue
    fi
  fi

  # 2. タイムスタンプで正確にフィルタリング（最初のuserメッセージから取得）
  first_timestamp=$(grep -m1 '"type":"user"' "$filepath" 2>/dev/null | jq -r '.timestamp // empty' 2>/dev/null)

  if [ -z "$first_timestamp" ] || [ "$first_timestamp" = "null" ]; then
    continue
  fi

  session_date=$(timestamp_to_date "$first_timestamp") || continue

  if is_in_range "$session_date"; then
    # プロジェクト名を抽出
    project=$(echo "$filepath" | sed 's|.*projects/||' | cut -d'/' -f1)

    process_session "$filepath" "$project"
  fi
done
