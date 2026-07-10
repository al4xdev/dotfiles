function deepcode-cloud --description "Deep Code com DeepSeek V4 Pro (cloud)"
    set -gx DEEPCODE_MODEL "deepseek-v4-pro"
    set -gx DEEPCODE_BASE_URL "https://api.deepseek.com"
    deepcode $argv
end
