extends Node
class_name AudioManager

# Audio Buses
var music_bus_index: int
var sfx_bus_index: int

# Music Players (Dual players for crossfading)
var music_player_1: AudioStreamPlayer
var music_player_2: AudioStreamPlayer
var active_music_player: int = 1

# SFX Pool
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_pool_size: int = 16
var next_sfx_index: int = 0

# Playlist Logic
# Playlist Logic (Hardcoded for Web Export Reliability)
var music_playlists = {
	"Theme_Base": [
		"res://assets/audio/music/Base/Midnight on 3rd and Vine.ogg",
		"res://assets/audio/music/Base/Safe Haven (Press Start).ogg",
		"res://assets/audio/music/Base/Steam on the Window.ogg",
		"res://assets/audio/music/Base/Vintage Dream Loop.ogg"
	],
	"Theme_Mission": [
		"res://assets/audio/music/Mission/mission_theme.ogg"
	]
}

# SFX Library
var sfx_tracks = {
	"SFX_Footstep": "res://assets/audio/sfx/footstep.wav",
	"SFX_Bark": "res://assets/audio/sfx/bark.mp3",
	"SFX_Hit": "res://assets/audio/sfx/hit.ogg",
	"SFX_Miss": "res://assets/audio/sfx/miss.wav",
	"SFX_Grenade": "res://assets/audio/sfx/grenade.wav",
	"SFX_Menu": "res://assets/audio/sfx/menu_click.wav"
}

var current_playlist_key: String = ""
var _has_user_interacted: bool = false

func _input(event):
	if not _has_user_interacted:
		if event is InputEventMouseButton and event.pressed:
			_has_user_interacted = true
			# Force AudioServer wake-up for Web Autoplay Policy
			AudioServer.set_bus_mute(0, false)
			print("AudioManager: User Interaction Detected. Forcing Audio Wake-up.")
			# Diagnostic: Play small SFX to test Engine
			play_sfx("SFX_Menu")


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Buses are now defined in default_bus_layout.tres
	music_bus_index = AudioServer.get_bus_index("Music")
	sfx_bus_index = AudioServer.get_bus_index("SFX")

	_setup_music_players()
	_setup_sfx_pool()


# Removed _setup_buses as it relies on runtime creation which can be flaky on Web



func set_music_volume(linear_val: float):
	# linear_val 0.0 to 1.0
	var db = linear_to_db(linear_val)
	AudioServer.set_bus_volume_db(music_bus_index, db)
	# Mute if 0 to avoid artifacts
	AudioServer.set_bus_mute(music_bus_index, linear_val <= 0.01)


func set_sfx_volume(linear_val: float):
	var db = linear_to_db(linear_val)
	AudioServer.set_bus_volume_db(sfx_bus_index, db)
	AudioServer.set_bus_mute(sfx_bus_index, linear_val <= 0.01)


func _on_music_finished():
	# Loop: Play another random track from current playlist
	if current_playlist_key != "":
		_play_random_track_from_playlist(current_playlist_key, true)


func _setup_music_players():
	music_player_1 = AudioStreamPlayer.new()
	music_player_1.bus = "Music"
	add_child(music_player_1)
	music_player_1.finished.connect(_on_music_finished)

	music_player_2 = AudioStreamPlayer.new()
	music_player_2.bus = "Music"
	add_child(music_player_2)
	music_player_2.finished.connect(_on_music_finished)


func _setup_sfx_pool():
	for i in range(sfx_pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)


func play_music(playlist_key: String, fade_duration: float = 2.0):
	if current_playlist_key == playlist_key and (music_player_1.playing or music_player_2.playing):
		return  # Already playing this playlist

	# print("AudioManager: Request to switch playlist -> ", playlist_key)
	if not music_playlists.has(playlist_key):
		print("AudioManager: ERR - Playlist key not found!")
		return

	current_playlist_key = playlist_key
	_play_random_track_from_playlist(playlist_key, false, fade_duration)


func _play_random_track_from_playlist(
	key: String, is_continuation: bool = false, fade_duration: float = 2.0
):
	var files = music_playlists[key]

	if files.size() == 0:
		print("AudioManager: ERR - No music files found for key: ", key)
		return

	var random_file = files.pick_random()
	print("AudioManager: Attempting to load track -> ", random_file)

	var stream = load(random_file)
	if not stream:
		print("AudioManager: ERR - Load Failed for: ", random_file)
		return
	print("AudioManager: Load Success. Stream: ", stream)

	var new_player = music_player_2 if active_music_player == 1 else music_player_1
	var old_player = music_player_1 if active_music_player == 1 else music_player_2

	# print("AudioManager: Starting playback on player ", new_player.name)

	# Crossfade Logic
	if is_continuation:
		# Immediate switch for gapless-ish feel, or quick fade?
		# Usually just play.
		new_player.stream = stream
		new_player.volume_db = 0.0
		new_player.play()
		active_music_player = 2 if active_music_player == 1 else 1
		return

	# Full Crossfade Removed for Reliability
	# Just Play.
	new_player.stream = stream
	new_player.volume_db = 0.0 # Full Volume
	new_player.play()
	
	if old_player.playing:
		old_player.stop()

	active_music_player = 2 if active_music_player == 1 else 1


func play_sfx(track_key: String, pitch_variance: float = 0.1, base_pitch: float = 1.0):
	if not sfx_tracks.has(track_key):
		print("AudioManager: SFX Key missing: ", track_key)
		return

	var path = sfx_tracks[track_key]
	var stream = load(path)
	if not stream:
		print("AudioManager: SFX Load Failed: ", path)
		print("AudioManager: Attempting fallback to SFX_Miss...")
		stream = load(sfx_tracks["SFX_Miss"])

	if not stream:
		return

	# Get next available player
	var player = sfx_players[next_sfx_index]
	next_sfx_index = (next_sfx_index + 1) % sfx_pool_size

	player.stream = stream
	player.pitch_scale = randf_range(base_pitch - pitch_variance, base_pitch + pitch_variance)
	player.play()
	# print("AudioManager: SFX Played -> ", track_key)
