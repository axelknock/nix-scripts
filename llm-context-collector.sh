#!/usr/bin/env bash
set -euo pipefail

# Default values
file_types=("txt" "md" "py" "js" "html" "css" "java" "cpp" "h" "c" "sh" "rb" "json" "xml" "yaml" "yml" "tsx" "ts" "msx" "jsx" "sql")
max_depth=-1  # -1 means infinite depth
output_dir=".llm_context"
ignore_patterns=()
refresh=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [-t file_types] [-d max_depth] [-o output_dir] [-i ignore_patterns] [--refresh]"
    echo "  -t: Comma-separated list of file extensions (default: ${file_types[*]})"
    echo "  -d: Maximum recursion depth (default: infinite)"
    echo "  -o: Output directory (default: $output_dir)"
    echo "  -i: Comma-separated list of patterns to ignore (e.g., 'node_modules,build,dist')"
    echo "  --refresh: Force rewrite of entire context"
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t) IFS=',' read -ra file_types <<< "$2"; shift 2 ;;
        -d) max_depth=$2; shift 2 ;;
        -o) output_dir=$2; shift 2 ;;
        -i) IFS=',' read -ra ignore_patterns <<< "$2"; shift 2 ;;
        --refresh) refresh=true; shift ;;
        -h|--help) print_usage ;;
        *) echo "Unknown option: $1"; print_usage ;;
    esac
done

# Ensure we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

# Handle output directory
if [ "$refresh" = true ] && [ -d "$output_dir" ]; then
    echo "Refreshing context. Removing existing output directory."
    rm -rf "$output_dir"
fi

mkdir -p "$output_dir"

# Build find command
find_cmd="git ls-files"

# Add ignore patterns
for pattern in "${ignore_patterns[@]}"; do
    find_cmd+=" | grep -v '$pattern'"
done

pattern=$(printf "\\.(%s)$" "$(IFS=\|; echo "${file_types[*]}")")
find_cmd+=" | grep -E '$pattern'"

# Add depth limitation if specified
if [ "$max_depth" -ge 0 ]; then
    find_cmd+=" | grep -vE '^([^/]+/){$((max_depth+1))}'"
fi

echo "Debug: Find command: $find_cmd" >&2
echo "Debug: File types: ${file_types[*]}" >&2
echo "Debug: Ignore patterns: ${ignore_patterns[*]}" >&2

# Function to get last modification time of a file
get_mod_time() {
    git log -1 --format=%ct "$1" 2>/dev/null || echo 0
}

# Execute find command and process files
files_found=0
files_processed=0
while IFS= read -r file; do
    # Check if the file extension is in the file_types array
    extension="${file##*.}"
    if ! printf '%s\n' "${file_types[@]}" | grep -qx "$extension"; then
        echo "Debug: Skipping file with unsupported extension: $file" >&2
        continue
    fi
    
    files_found=$((files_found + 1))
    
    # Create new file name
    new_file_name=$(printf "%03d_%s" "$files_found" "${file//\//_}")
    output_file="$output_dir/$new_file_name"
    
    # Check if file has changed or is new
    if [ "$refresh" = false ] && [ -f "$output_file" ]; then
        file_mod_time=$(get_mod_time "$file")
        output_mod_time=$(stat -c %Y "$output_file" 2>/dev/null || echo 0)
        if [ "$file_mod_time" -le "$output_mod_time" ]; then
            echo "Debug: Skipping unchanged file: $file" >&2
            continue
        fi
    fi
    
    echo "Debug: Processing file: $file" >&2
    files_processed=$((files_processed + 1))
    
    # Copy file content with original filename as the first line
    {
        echo "Original filename: $file"
        echo "----------------------------------------"
        cat "$file"
    } > "$output_file" || echo "Error: Failed to process $file" >&2
done < <(eval "$find_cmd")

echo "Debug: Files found: $files_found" >&2
echo "Debug: Files processed: $files_processed" >&2
if [ $files_processed -eq 0 ]; then
    if [ $files_found -eq 0 ]; then
        echo "Warning: No files were found matching the specified criteria." >&2
    else
        echo "Info: No files needed updating." >&2
    fi
else
    echo "Context collection complete. Output in $output_dir"
fi

echo "Debug: Contents of output directory:" >&2
ls -1 "$output_dir" >&2
