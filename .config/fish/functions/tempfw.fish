function tempfw --description 'Consultar versão USB do 8BitDo 64, sem atualizar firmware'
    uv run --no-project python /home/alex/git/my/8bitdo/tools/usb_version.py --grant $argv
end
