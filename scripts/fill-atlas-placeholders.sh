#!/bin/bash
# Fill empty positions in atlasdeck.png with placeholder tiles
# This prevents crashes when a deck references an empty atlas position

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/../assets"

# Tile sizes
TILE_1X_W=71
TILE_1X_H=95
TILE_2X_W=142
TILE_2X_H=190

# Grid size (9 columns x 7 rows)
COLS=9
ROWS=7

# Create placeholder tiles (magenta/black checkerboard - classic "missing texture")
create_placeholders() {
    magick -size ${TILE_1X_W}x${TILE_1X_H} pattern:checkerboard \
        -fill '#FF00FF' -opaque white -fill '#000000' -opaque black \
        /tmp/placeholder_1x.png

    magick -size ${TILE_2X_W}x${TILE_2X_H} pattern:checkerboard \
        -fill '#FF00FF' -opaque white -fill '#000000' -opaque black \
        /tmp/placeholder_2x.png

    echo "Created placeholder tiles"
}

# Create a full grid of placeholders
create_placeholder_grid() {
    local tile=$1
    local tile_w=$2
    local tile_h=$3
    local output=$4

    local grid_w=$((COLS * tile_w))
    local grid_h=$((ROWS * tile_h))

    # Create base grid by tiling the placeholder
    magick -size ${grid_w}x${grid_h} tile:$tile $output
    echo "Created placeholder grid: $output (${grid_w}x${grid_h})"
}

# Composite existing atlas on top of placeholder grid
fill_atlas() {
    local atlas=$1
    local placeholder_grid=$2
    local output=$3

    if [ -f "$atlas" ]; then
        # Composite existing atlas on top of placeholder grid
        magick "$placeholder_grid" "$atlas" -composite "$output"
        echo "Filled empty positions in: $output"
    else
        # No existing atlas, just use the placeholder grid
        cp "$placeholder_grid" "$output"
        echo "Created new atlas with placeholders: $output"
    fi
}

# Main
echo "Filling atlas placeholders..."

create_placeholders

# Process 1x atlas
create_placeholder_grid /tmp/placeholder_1x.png $TILE_1X_W $TILE_1X_H /tmp/grid_1x.png
fill_atlas "$ASSETS_DIR/1x/atlasdeck.png" /tmp/grid_1x.png "$ASSETS_DIR/1x/atlasdeck.png"

# Process 2x atlas
create_placeholder_grid /tmp/placeholder_2x.png $TILE_2X_W $TILE_2X_H /tmp/grid_2x.png
fill_atlas "$ASSETS_DIR/2x/atlasdeck.png" /tmp/grid_2x.png "$ASSETS_DIR/2x/atlasdeck.png"

# Cleanup
rm -f /tmp/placeholder_1x.png /tmp/placeholder_2x.png /tmp/grid_1x.png /tmp/grid_2x.png

echo "Done! Empty atlas positions now have placeholder tiles."
