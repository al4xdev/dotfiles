function temptrace --description 'Capturar um scan Bluetooth por até 20s, sem parear nem trocar driver'
    uv run --no-project python /home/alex/git/my/8bitdo/tools/btusb_trace.py $argv
end
