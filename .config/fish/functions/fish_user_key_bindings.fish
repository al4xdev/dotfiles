function fish_user_key_bindings
    bind \cw ''
    bind \cl backward-kill-path-component
    bind \t forward-word

    if test "$fish_key_bindings" = fish_vi_key_bindings
        bind -Minsert ! __history_previous_command
        bind -Minsert '$' __history_previous_command_arguments
    else
        bind ! __history_previous_command
        bind '$' __history_previous_command_arguments
    end
end
