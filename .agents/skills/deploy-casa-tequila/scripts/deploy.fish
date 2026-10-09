#!/usr/bin/env fish

# The shared skill root is outside the repository, so anchor the release at the ha_app checkout directly.
set -l repo_root /home/alex/git/my/ha_app
set -g deploy_ha_base "http://192.168.0.150:8123"
if set -q home_assistant_url
    set -g deploy_ha_base (string trim -r -c / -- $home_assistant_url)
end

if test (count $argv) -ne 1
    echo "Uso: deploy.fish <versão-semver>; exemplo: deploy.fish 1.6.0" >&2
    exit 2
end
if not set -q home_assistant
    echo "Variável universal Fish ausente: home_assistant" >&2
    exit 2
end

set -l version_name $argv[1]
if not string match -rq '^[0-9]+\.[0-9]+\.[0-9]+$' -- $version_name
    echo "Versão inválida: use MAJOR.MINOR.PATCH sem sufixos." >&2
    exit 2
end

set -l parts (string split . -- $version_name)
for part in $parts
    if test (string length -- $part) -gt 1; and string match -rq '^0' -- $part
        echo "Versão inválida: não use zeros à esquerda." >&2
        exit 2
    end
end
set -l major $parts[1]
set -l minor $parts[2]
set -l patch $parts[3]
if test $minor -gt 999; or test $patch -gt 999
    echo "Versão inválida: MINOR e PATCH devem ser menores que 1000." >&2
    exit 2
end
set -l version_code (math "$major * 1000000 + $minor * 1000 + $patch")
if test $version_code -le 0; or test $version_code -gt 2100000000
    echo "versionCode calculado fora do intervalo Android." >&2
    exit 2
end

set -lx CASA_TEQUILA_VERSION_NAME $version_name
set -lx CASA_TEQUILA_VERSION_CODE $version_code
set -g deploy_auth "Authorization: Bearer $home_assistant"
set -g deploy_version_entity input_text.alex_app_apk_versao_atual
set -g deploy_media_entity input_text.alex_app_apk_media_id
set -l media_folder media-source://media_source/local/alex_app
set -l media_name "casa-de-tequila-$version_name.mp4"
set -l apk "$repo_root/.ci-cd/android/app/build/outputs/apk/debug/app-debug.apk"
set -g deploy_roundtrip (mktemp --suffix=.apk)
set -g deploy_committed 0
set -g deploy_helpers_changed 0
set -g deploy_old_version ""
set -g deploy_old_media ""

function ha_state --argument-names entity_id
    curl -fsS --connect-timeout 5 --max-time 15 \
        -H "$deploy_auth" "$deploy_ha_base/api/states/$entity_id"
end

function set_text --argument-names entity_id value
    set -l payload (jq -nc --arg entity_id "$entity_id" --arg value "$value" \
        '{entity_id: $entity_id, value: $value}')
    curl -fsS --connect-timeout 5 --max-time 15 -X POST \
        -H "$deploy_auth" -H "Content-Type: application/json" -d "$payload" \
        "$deploy_ha_base/api/services/input_text/set_value" >/dev/null
end

function deploy_rollback --on-event fish_exit
    if test $deploy_committed -eq 1; or test $deploy_helpers_changed -eq 0
        return
    end
    echo "Deploy incompleto; restaurando contrato anterior do Home Assistant…" >&2
    set_text "$deploy_media_entity" "$deploy_old_media" 2>/dev/null
    set_text "$deploy_version_entity" "$deploy_old_version" 2>/dev/null
end

cd "$repo_root"; or exit 1
set -g deploy_old_version (ha_state "$deploy_version_entity" | jq -er .state); or exit 1
set -g deploy_old_media (ha_state "$deploy_media_entity" | jq -er .state); or exit 1
if string match -rq '^[0-9]+\.[0-9]+\.[0-9]+$' -- $deploy_old_version
    set -l old_parts (string split . -- $deploy_old_version)
    set -l old_code (math "$old_parts[1] * 1000000 + $old_parts[2] * 1000 + $old_parts[3]")
    if test $version_code -le $old_code
        echo "A versão $version_name deve ser maior que a publicada ($deploy_old_version)." >&2
        exit 2
    end
end

echo "[1/5] Testando o aplicativo…"
npm test -- --reporter=line; or exit 1

echo "[2/5] Gerando versão $version_name ($version_code)…"
.ci-cd/android/scripts/build-debug-apk.sh; or exit 1
test -f "$apk"; or begin; echo "O pacote Android não foi gerado." >&2; exit 1; end

echo "[3/5] Publicando arquivo versionado no Home Assistant…"
set -l upload (curl -fsS --connect-timeout 5 --max-time 120 -X POST \
    -H "$deploy_auth" \
    -F "media_content_id=$media_folder" \
    -F "file=@$apk;filename=$media_name;type=video/mp4" \
    "$deploy_ha_base/api/media_source/local_source/upload"); or exit 1
set -l media_id (printf '%s' "$upload" | jq -er .media_content_id); or exit 1
test "$media_id" = "$media_folder/$media_name"; or begin
    echo "Home Assistant retornou um media ID inesperado." >&2
    exit 1
end

echo "[4/5] Verificando o arquivo publicado por SHA-256…"
curl -fsS --connect-timeout 5 --max-time 120 -H "$deploy_auth" \
    "$deploy_ha_base/media/local/alex_app/$media_name" -o "$deploy_roundtrip"; or exit 1
set -l local_sha (sha256sum "$apk" | string split ' ' | head -1)
set -l remote_sha (sha256sum "$deploy_roundtrip" | string split ' ' | head -1)
test "$local_sha" = "$remote_sha"; or begin
    echo "O arquivo retornado pelo Home Assistant não confere com o build." >&2
    exit 1
end

echo "[5/5] Publicando contrato obrigatório…"
set -g deploy_helpers_changed 1
set_text "$deploy_media_entity" "$media_id"; or exit 1
set_text "$deploy_version_entity" "$version_name"; or exit 1
test (ha_state "$deploy_media_entity" | jq -r .state) = "$media_id"; or exit 1
test (ha_state "$deploy_version_entity" | jq -r .state) = "$version_name"; or exit 1
set -g deploy_committed 1

jq -n \
    --arg version "$version_name" \
    --argjson version_code "$version_code" \
    --arg media_id "$media_id" \
    --arg sha256 "$local_sha" \
    --arg apk "$apk" \
    '{status:"published", version:$version, versionCode:$version_code, mediaId:$media_id, sha256:$sha256, apk:$apk}'
