#!/usr/bin/env fish

set -l project casa-de-tequila-push
set -l samba_auth /tmp/ha-samba-auth
set -l host 192.168.0.150

if not type -q gcloud; or not type -q jq; or not type -q smbclient
    echo "Ferramentas obrigatórias ausentes (gcloud, jq ou smbclient)." >&2
    exit 1
end

echo "Firebase billing"
gcloud billing projects describe $project \
    --format='json(projectId,billingEnabled,billingAccountName)' | jq .
or exit 1

set -l adc_token (gcloud auth application-default print-access-token 2>/dev/null)
if test -z "$adc_token"
    echo "ADC do Google Cloud indisponível." >&2
    exit 1
end

echo "Firebase project"
curl -fsS -H "Authorization: Bearer $adc_token" \
    "https://firebase.googleapis.com/v1beta1/projects/$project" |
    jq '{projectId,projectNumber,resources}'
or exit 1

echo "Firebase Analytics association"
set -l analytics_response (mktemp /tmp/alex-app-analytics-XXXXXX)
set -l analytics_status (curl -sS -o $analytics_response -w '%{http_code}' \
    -H "Authorization: Bearer $adc_token" \
    "https://firebase.googleapis.com/v1beta1/projects/$project/analyticsDetails")
if test "$analytics_status" = 404
    echo "none"
else if test "$analytics_status" = 200
    jq '{analyticsProperty}' $analytics_response
else
    echo "Falha ao consultar Analytics: HTTP $analytics_status" >&2
    mv $analytics_response "$analytics_response.bak"
    exit 1
end
mv $analytics_response "$analytics_response.bak"
set -e adc_token

echo "Samba config"
if not test -f $samba_auth
    echo "$samba_auth ausente; prepare a credencial conforme SKILL.md." >&2
    exit 1
end
set -l mode (stat -c '%a' $samba_auth)
if test "$mode" != 600
    echo "$samba_auth precisa ter modo 600; encontrado $mode." >&2
    exit 1
end
smbclient -A $samba_auth "//$host/config" -c 'ls configuration.yaml; ls automations.yaml'
