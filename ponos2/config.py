BROKER = "192.168.1.21"
PORT = 1883
ID = "02" 
USER = "5 уровень"

# конфигурация режима «Купол»
DOME_ROLE = "display"             # либо "terminal"
DOME_ID = "DOME_1"                # ID купола для отображения
DOME_TERMINAL_ID = "term_01"      # ID терминала выбора
DOME_DEFAULT_CHOICE = "keep_ammo" # keep_ammo или super_shots
DOME_TIMEOUT_SEC = 45
DOME_HP_MAX = 1000
DOME_HIT_DAMAGE = 120
DOME_TEAM_NAMES = {
    "red": "Красные",
    "blue": "Синие",
}
DOME_TEAM_COLORS = {
    "red": "#ff4d6b",
    "blue": "#4df0ff",
    "default": "#8bdfff",
}
