"""Recolhe janelas destacadas sem desmontar os workspaces numerados."""

from kittens.tui.handler import result_handler

WORKSPACES = frozenset(str(number) for number in range(1, 10))


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    destination = window.tabref() if window is not None else None
    if destination is None:
        return

    destination_os_id = destination.os_window_id
    destination_manager = boss.os_window_map[destination_os_id]

    # Captura os IDs antes de mover: cada aba vazia fecha sua janela de origem.
    for os_id, manager in tuple(boss.os_window_map.items()):
        if os_id == destination_os_id:
            continue
        for tab in tuple(manager.tabs):
            if tab.name in WORKSPACES:
                # Abas 1–9 continuam independentes e acessíveis por Super+n.
                boss._move_tab_to(tab=tab, target_os_window_id=destination_os_id)
                continue

            # Um grupo pode conter overlays; movê-lo pela janela principal preserva
            # as demais janelas do grupo e os processos que já estão rodando.
            group_ids = tuple(group.main_window_id for group in tab.windows.iter_all_layoutable_groups())
            for window_id in group_ids:
                source = boss.window_id_map.get(window_id)
                if source is not None and source.tabref() is tab:
                    boss._move_window_to(window=source, target_tab_id=destination.id)

    if destination.current_layout.name != 'splits':
        destination.goto_layout('splits')
    destination.current_layout.equalize_biases()
    destination.relayout()
    destination_manager.set_active_tab(destination)
    boss.focus_os_window(destination_os_id)
