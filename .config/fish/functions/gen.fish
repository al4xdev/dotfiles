function gen
    if not set -q argv[1]; or contains -- $argv[1] "-h" "--help"
        echo "Usage: gen [method]"
        echo ""
        echo "Available Methods:"
        echo "  image    Launch ComfyUI for image generation"
        echo "  video    Launch ComfyUI for video generation"
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        return 0
    end

    set -l method $argv[1]

    switch $method
        case 'image'
            echo "🚀 Launching ComfyUI for Images..."
            ~/.config/comfyui-scripts/start.sh

        case 'video'
            echo "🎬 Launching ComfyUI for Videos..."
            ~/.config/comfyui-scripts/start_video.sh

        case '*'
            echo "❌ Unknown method: '$method'"
            echo "Run 'gen --help' for available options."
            return 1
    end
end
