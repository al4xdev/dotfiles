#!/usr/bin/env fish

set -l base_url "http://192.168.0.150:8123"
if set -q home_assistant_url
    set base_url (string trim -r -c / -- $home_assistant_url)
end

if not set -q home_assistant
    echo "Missing Fish universal variable: home_assistant" >&2
    exit 2
end

if test (count $argv) -lt 1
    echo "Usage: ha.fish ping|search|state|service|snapshot ..." >&2
    exit 2
end

set -l auth "Authorization: Bearer $home_assistant"

switch $argv[1]
    case ping
        curl -fsS --connect-timeout 5 --max-time 10 \
            -H "$auth" "$base_url/api/"
        echo

    case search
        if test (count $argv) -lt 2
            echo "Usage: ha.fish search <regex>" >&2
            exit 2
        end
        set -l query (string join " " $argv[2..-1])
        curl -fsS --connect-timeout 5 --max-time 10 \
            -H "$auth" "$base_url/api/states" |
            jq -r --arg query "$query" \
                '.[] | select((.entity_id + " " + (.attributes.friendly_name // "")) | test($query; "i")) | [.entity_id, (.attributes.friendly_name // ""), .state] | @tsv'

    case state
        if test (count $argv) -ne 2
            echo "Usage: ha.fish state <entity_id>" >&2
            exit 2
        end
        curl -fsS --connect-timeout 5 --max-time 10 \
            -H "$auth" "$base_url/api/states/$argv[2]" |
            jq '{entity_id, state, attributes}'

    case service
        if test (count $argv) -ne 4
            echo "Usage: ha.fish service <domain> <service> <entity_id>" >&2
            exit 2
        end
        set -l payload (jq -nc --arg entity_id "$argv[4]" '{entity_id: $entity_id}')
        curl -fsS --connect-timeout 5 --max-time 10 -X POST \
            -H "$auth" -H "Content-Type: application/json" \
            -d "$payload" "$base_url/api/services/$argv[2]/$argv[3]" >/dev/null
        sleep 1
        curl -fsS --connect-timeout 5 --max-time 10 \
            -H "$auth" "$base_url/api/states/$argv[4]" |
            jq '{entity_id, state, name: (.attributes.friendly_name // "")}'

    case snapshot
        if test (count $argv) -ne 3
            echo "Usage: ha.fish snapshot <camera_entity_id> <output.jpg>" >&2
            exit 2
        end
        curl -fsS --connect-timeout 5 --max-time 20 \
            -H "$auth" -o "$argv[3]" "$base_url/api/camera_proxy/$argv[2]"
        file "$argv[3]"

    case '*'
        echo "Unknown command: $argv[1]" >&2
        exit 2
end
