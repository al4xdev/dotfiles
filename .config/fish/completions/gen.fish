complete -c gen -f
complete -c gen -n '__fish_use_subcommand' -l headless -d 'Pure JSON for agents; before the command'
complete -c gen -n '__fish_use_subcommand' -a 'image video' -d 'Start an original model profile'
complete -c gen -n '__fish_use_subcommand' -a 'gm' -d 'Gemma 4 26B-A4B MoE through NInfer (262144, experts in RAM)'
complete -c gen -n '__fish_use_subcommand' -a 'qw' -d 'Bonsai 27B ternary through NInfer (262144, MTP2)'
complete -c gen -n '__fish_use_subcommand' -a stop -d 'Stop only the owned gen service'
complete -c gen -n '__fish_use_subcommand' -a status -d 'Read service state without starting models'
complete -c gen -n '__fish_use_subcommand' -a logs -d 'Read log lines: gen logs 100 200'
complete -c gen -n '__fish_seen_subcommand_from status' -l json -d 'Pure JSON service state'
complete -c gen -n '__fish_seen_subcommand_from logs' -l run -d 'Previous run ID' -r
complete -c gen -n '__fish_seen_subcommand_from logs' -l follow -d 'Stream messages; Ctrl+C leaves the model running'
complete -c gen -n '__fish_seen_subcommand_from gm qw' -l vision -d 'Load the vision tower (overlay, +1 GiB media cache)'
complete -c gen -n '__fish_seen_subcommand_from gm qw' -l no-vision -d 'Skip the vision tower (default for both)'
complete -c gen -s h -l help -d 'Show help'
