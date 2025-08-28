#!/bin/bash

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed or not in PATH"
    exit 1
fi

# Check if directory argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory_name>"
    exit 1
fi

# Get the directory name from argument
DIR_NAME="$1"

# Check if directory exists
if [ ! -d "$DIR_NAME" ]; then
    echo "Error: Directory '$DIR_NAME' does not exist"
    exit 1
fi

# Change to the specified directory
cd "$DIR_NAME" || exit 1

# Check if there are any images in the directory
IMAGE_COUNT=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" \) | wc -l)

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "No images found in directory '$DIR_NAME'"
    exit 1
fi

# Create output filename based on directory name
OUTPUT_NAME="${DIR_NAME}.png"

echo "Found $IMAGE_COUNT images. Concatenating..."

# Use ImageMagick to concatenate images horizontally
# Try magick command first (ImageMagick 7+), fallback to convert (ImageMagick 6)
if command -v magick &> /dev/null; then
    magick montage *.jpg *.jpeg *.png *.gif *.bmp *.tiff *.webp -tile x1 -geometry +0+0 -background none "$OUTPUT_NAME" 2>/dev/null || \
    magick montage * -tile x1 -geometry +0+0 -background none "$OUTPUT_NAME"
else
    montage *.jpg *.jpeg *.png *.gif *.bmp *.tiff *.webp -tile x1 -geometry +0+0 -background none "$OUTPUT_NAME" 2>/dev/null || \
    montage * -tile x1 -geometry +0+0 -background none "$OUTPUT_NAME"
fi

# Check if the output file was created successfully
if [ -f "$OUTPUT_NAME" ]; then
    echo "Successfully created $OUTPUT_NAME"
    echo "Output file size: $(du -h "$OUTPUT_NAME" | cut -f1)"
else
    echo "Error: Failed to create concatenated image"
    exit 1
fi
