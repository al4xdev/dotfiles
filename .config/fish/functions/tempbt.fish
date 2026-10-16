function tempbt --description 'Testar driver Bluetooth temporário; --restore volta ao original'
    uv run --no-project python /home/alex/git/my/8bitdo/tools/btusb_trial.py $argv
end
