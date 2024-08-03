#!/usr/bin/env bash

set -euo pipefail

# Default values
file_types=("txt" "md" "py" "js" "html" "css" "java" "cpp" "h" "c" "sh" "rb" "json" "xml" "yaml" "yml")
max_depth=-1  # -1 means infinite depth
output_dir="git_context_output"

# Function to print usage
print_usage() {
    echo "Usage: $0 [-t file_types] [-d max_depth] [-o output_dir]"
    echo "  -t: Comma-separated list of file extensions (default: ${file_types[*]})"
    echo "  -d: Maximum recursion depth (default: infinite)"
    echo "  -o: Output directory (default: $output_dir)"
    exit 1
}

# Parse command-line arguments
while getopts "t:d:o:h" opt; do
    case $opt in
        t) IFS=',' read -ra file_types <<< "$OPTARG" ;;
        d) max_depth=$OPTARG ;;
        o) output_dir=$OPTARG ;;
        h) print_usage ;;
        *) print_usage ;;
    esac
done

# Ensure we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

# Create output directory
mkdir -p "$output_dir"

# Build find command
find_cmd="git ls-files"
pattern=$(printf "\\.\(%s\)$" "$(IFS=\|; echo "${file_types[*]}")")
find_cmd+=" | grep -E '$pattern'"

# Add depth limitation if specified
if [ "$max_depth" -ge 0 ]; then
    find_cmd+=" | grep -vE '^([^/]+/){$((max_depth+1))}'"
fi

echo "Debug: Find command: $find_cmd" >&2
echo "Debug: File types: ${file_types[*]}" >&2

# Execute find command and process files
files_found=0
while IFS= read -r file; do
    # Check if the file extension is in the file_types array
    extension="${file##*.}"
    if ! printf '%s\n' "${file_types[@]}" | grep -qx "$extension"; then
        echo "Debug: Skipping file with unsupported extension: $file" >&2
        continue
    fi

    echo "Debug: Processing file: $file" >&2
    files_found=$((files_found + 1))
    
    # Create new file name
    new_file_name=$(printf "%04d.txt" "$files_found")
    
    # Copy file content with original filename as the first line
    {
        echo "Original filename: $file"
        echo "----------------------------------------"
        cat "$file"
    } > "$output_dir/$new_file_name" || echo "Error: Failed to process $file" >&2
done < <(eval "$find_cmd")

echo "Debug: Files found and processed: $files_found" >&2

if [ $files_found -eq 0 ]; then
    echo "Warning: No files were found matching the specified criteria." >&2
else
    echo "Context collection complete. Output in $output_dir"
fi

echo "Debug: Contents of output directory:" >&2
ls -1 "$output_dir" >&2
