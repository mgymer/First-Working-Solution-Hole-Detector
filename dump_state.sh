#!/bin/zsh
# -------------------------
# dump_state.sh
# Saves all .swift files from GolfAIApp into a single timestamped text file.
# Opens the file in TextEdit automatically.
# -------------------------

# 1. Set the source and destination folders
SOURCE_DIR="$HOME/Documents/GolfAIApp"
DEST_DIR="$SOURCE_DIR/SwiftTextDownload"

# 2. Create the destination folder if it doesn’t exist
mkdir -p "$DEST_DIR"

# 3. Create a timestamped output file
timestamp=$(date +"%Y-%m-%d_%H%M")
OUTPUT_FILE="$DEST_DIR/GolfAIAppSwiftText_${timestamp}.txt"

# 4. Remove any file with the same name (just in case)
rm -f "$OUTPUT_FILE"

# 5. Find, sort, and append all .swift file contents into one file
find "$SOURCE_DIR" -type f -name "*.swift" | sort | while read -r file; do
  filename=$(basename "$file")
  echo "$filename" >> "$OUTPUT_FILE"
  echo "FILE: $file" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  cat "$file" >> "$OUTPUT_FILE"
  echo "\n\n" >> "$OUTPUT_FILE"
done

# 6. Open the resulting file in TextEdit automatically
open -a TextEdit "$OUTPUT_FILE"

# 7. Confirm in terminal
echo "✅ Swift files saved to: $OUTPUT_FILE and opened in TextEdit."

