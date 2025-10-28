#!/usr/bin/env bash
set -e

FILE="$1"
FOLDER_ID="$2"
API_TOKEN="$3"

if [[ -z "$FILE" ]]; then
  echo "Usage: $0 <file_path> [folder_id] [api_token]"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "Error: File \"$FILE\" not found."
  exit 1
fi

UPLOAD_URL="https://upload.gofile.io/uploadfile"

# Optional authorization header
AUTH_HEADER=()
if [[ -n "$API_TOKEN" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer $API_TOKEN")
fi

# Form data
FORM=(-F "file=@${FILE}")
if [[ -n "$FOLDER_ID" ]]; then
  FORM+=(-F "folderId=${FOLDER_ID}")
fi

# File info
if command -v du >/dev/null 2>&1; then
  FILE_SIZE=$(du -h "$FILE" | cut -f1)
else
  FILE_SIZE=$(stat -c%s "$FILE" 2>/dev/null || echo "unknown size")
fi

START_TIME=$(date +%s)

echo "Uploading \"$FILE\" ($FILE_SIZE) to GoFile..."
echo "----------------------------------------------"

# Upload with progress bar
if ! RESPONSE=$(curl --progress-bar "${AUTH_HEADER[@]}" "${FORM[@]}" "$UPLOAD_URL"); then
  echo
  echo "Upload failed due to a network or server error."
  exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo
echo "Upload completed in ${ELAPSED}s"

# If jq is available, parse and extract link
if command -v jq >/dev/null 2>&1; then
  STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')

  if [[ "$STATUS" != "ok" && "$STATUS" != "success" ]]; then
    echo "Upload failed or unexpected response."
    echo "$RESPONSE" | jq .
    exit 1
  fi

  LINK=$(echo "$RESPONSE" | jq -r '.data.directLink // .data.downloadPage // empty')

  if [[ -n "$LINK" ]]; then
    echo "Upload successful!"
    echo -e "Download link: \e]8;;${LINK}\e\\${LINK}\e]8;;\e\\"

    # Auto-copy to clipboard if supported
    if command -v xclip >/dev/null 2>&1; then
      echo -n "$LINK" | xclip -selection clipboard
      echo "(Copied to clipboard)"
    elif command -v pbcopy >/dev/null 2>&1; then
      echo -n "$LINK" | pbcopy
      echo "(Copied to clipboard)"
    elif command -v clip.exe >/dev/null 2>&1; then
      echo -n "$LINK" | clip.exe
      echo "(Copied to clipboard)"
    fi

    # Save last link to file
    echo "$LINK" > last_upload.txt
    echo "(Saved link to last_upload.txt)"
  else
    echo "Upload complete but no link found in response."
  fi
else
  echo "jq not found — showing raw response:"
  echo "$RESPONSE"
fi
