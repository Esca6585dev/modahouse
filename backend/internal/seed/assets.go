package seed

import "embed"

// reelFS holds the generated demo reel clips (VP9 WebM, 360x640, ~6 s) and
// their JPEG posters, see assets/reels/README.md.
//
//go:embed assets/reels/*.webm assets/reels/*.jpg
var reelFS embed.FS
