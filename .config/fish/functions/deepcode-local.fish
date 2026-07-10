function deepcode-local --description "Deep Code com modelo local (Unsloth)"
    set -gx DEEPCODE_MODEL "unsloth/Qwen-AgentWorld-35B-A3B-GGUF"
    set -gx DEEPCODE_BASE_URL "http://localhost:8888/v1"
    set -gx DEEPCODE_API_KEY "sk-unsloth-828bbc10b07eb9f75f6d9d645bdd5d94"
    deepcode $argv
end
