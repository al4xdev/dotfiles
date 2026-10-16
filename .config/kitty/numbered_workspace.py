"""Abas do Kitty como workspaces 1–9, criados somente quando solicitados."""

from kittens.tui.handler import result_handler
from kitty.window import CwdRequest

NUMBERS = tuple(str(number) for number in range(1, 10))


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    if len(args) != 2 or args[1] not in NUMBERS:
        return
    manager = boss.active_tab_manager
    if manager is None:
        return

    # Usa o nome explícito, não o índice nem o título enviado pelo shell:
    # fechar uma aba não renumera as outras e mudar de diretório não muda o número.
    used = {tab.name for tab in manager.tabs if tab.name in NUMBERS}
    available = iter(number for number in NUMBERS if number not in used)
    for tab in manager.tabs:
        if tab.name not in NUMBERS:
            number = next(available, None)
            if number is None:
                break
            tab.set_title(number)

    requested = args[1]
    for tab in manager.tabs:
        if tab.name == requested:
            manager.set_active_tab(tab)
            return

    window = boss.window_id_map.get(target_window_id)
    tab = manager.new_tab(cwd_from=CwdRequest(window) if window is not None else None)
    tab.set_title(requested)

    # Mantém a barra em ordem numérica mesmo ao abrir 9 antes de 2.
    position = sum(other.name in NUMBERS and int(other.name) < int(requested)
                   for other in manager.tabs if other is not tab)
    delta = position - manager.tabs.index(tab)
    if delta:
        manager.move_tab(delta)
