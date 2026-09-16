function dsh --description "Abre o DeepSeek Harness como um WebApp sem barras"
    zen-browser --profile ~/.config/dsh-webapp-profile --new-instance "http://localhost:3080" >/dev/null 2>&1 &
    disown
end
