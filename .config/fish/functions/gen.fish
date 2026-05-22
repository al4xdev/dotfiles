function gen
    function _gen_setup_completions
        echo "🔧 Configuring tab completions for 'gen'..."
            complete -c gen -f
            complete -c gen -a image -d 'Launch ComfyUI for image generation'
            complete -c gen -a video -d 'Launch ComfyUI for video generation'
            complete -c gen -s h -l help -d 'Show help message'
        
            funcsave gen
    end

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

    if not test -e ~/.config/fish/completions/gen.fish
        _gen_setup_completions
    end

    set -l metodo $argv[1]

    switch $metodo
        case 'image'
            echo "🚀 Launching ComfyUI for Images..."
            /home/alex/ComfyUI/start.sh
            
        case 'video'
            echo "🎬 Launching ComfyUI for Videos..."
            /home/alex/ComfyUI/start_video.sh

        case '*'
            echo "❌ Unknown method: '$metodo'"
            echo "Run 'gen --help' for available options."
            return 1
    end
end
