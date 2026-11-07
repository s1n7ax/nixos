"""Constants for the security alerts integration."""

from __future__ import annotations

DOMAIN = "security_alerts"

CONF_NOTIFY_SERVICE = "notify_service"
CONF_MODES = "modes"
CONF_NAME = "name"
CONF_ENTITY = "entity"
CONF_HOME = "home"
CONF_DETECTION = "detection"
CONF_DETECTION_ASLEEP_OR_NIGHT = "detection_asleep_or_night"
CONF_SOUND = "sound"
CONF_DOOR_TOP = "door_top"
CONF_DOOR_OTHER = "door_other"
CONF_MOTION_TOP = "motion_top"
CONF_MOTION_OTHER = "motion_other"
CONF_TOP_FLOORS = "top_floors"
CONF_SLEEP_ENTITY = "sleep_entity"
CONF_SLEEP_THRESHOLD = "sleep_threshold"
CONF_NIGHT_START = "night_start"
CONF_NIGHT_END = "night_end"
CONF_MOTION_MIN_SECONDS = "motion_min_seconds"
CONF_BURST_MINUTES = "burst_minutes"
CONF_LOG_DAYS = "log_days"
CONF_FIRST_REVIEW_HOURS = "first_review_hours"
CONF_DURATIONS_HOURS = "durations_hours"
CONF_QUIET_AFTER_RESTART_ENTITY = "quiet_after_restart_entity"
CONF_SIREN_ENTITY = "siren_entity"

DEFAULT_SLEEP_THRESHOLD = 90
DEFAULT_NIGHT_START = "00:00"
DEFAULT_NIGHT_END = "05:00"
DEFAULT_MOTION_MIN_SECONDS = 5
DEFAULT_BURST_MINUTES = 10
DEFAULT_LOG_DAYS = 30
DEFAULT_FIRST_REVIEW_HOURS = 24
DEFAULT_DURATIONS_HOURS = [1, 2, 5, 10, 24]

# Files under the HA config directory.
DATA_DIR = "security_alerts"
DB_FILE = "alerts.db"
MEDIA_DIR = "media"

STORAGE_KEY = DOMAIN
STORAGE_VERSION = 1

# Clip timing. Recordings lag 10-25 s, so a clip counts as ready 30 s after it ends.
CLIP_PRE_SECONDS = 5
CLIP_POST_SECONDS = 5
CLIP_READY_DELAY_SECONDS = 30
# An end or OFF that never arrives (an HA restart, say) gives a 60 s clip.
CLIP_MISSING_END_SECONDS = 30 * 60
CLIP_FALLBACK_LENGTH_SECONDS = 60

# How long a detection waits for the MQTT snapshot matching Frigate's image.
SNAPSHOT_MATCH_TIMEOUT_SECONDS = 2.0
# Matching Frigate's X-Frame-Time header to a snapshot frame time.
FRAME_TIME_TOLERANCE = 1e-3
# The review image is the recording frame that matches the detection snapshot,
# looked for this long either side of the snapshot's frame time.
MATCH_WINDOW_SECONDS = 3
# Clip fetches and decodes for that match running at once, across the integration.
MATCH_CONCURRENCY = 1
# Bumped when cached review images must be rendered again; older ones are deleted.
FULL_IMAGE_VERSION = 3

SIGNED_URL_HOURS = 24
FRIGATE_CONFIG_REFRESH_SECONDS = 3600
FRIGATE_CONFIG_RETRY_SECONDS = 60

REVIEW_PATH = "/security-review"
FRONTEND_URL = "/security_alerts_frontend"
PANEL_COMPONENT = "security-review-panel"
PANEL_FILE = "security-review-panel.js"
CARD_FILE = "security-alerts-card.js"
IMAGE_URL = "/api/security_alerts/image/{alert_id}/{variant}.jpg"
AUDIO_URL = "/api/security_alerts/audio/{alert_id}.m4a"
# Media variants: the notification image, the review image, a sound's audio clip.
THUMB = "thumb"
FULL = "full"
AUDIO = "audio"
# ffmpeg copies a sound's audio out of Frigate's clip; it is killed after this long.
FFMPEG_TIMEOUT_SECONDS = 60

ACTION_SIREN = "SECURITY_ALERTS_SIREN"
ACTION_SNOOZE_PREFIX = "SECURITY_ALERTS_SNOOZE_"
SNOOZE_ACTION_HOURS = 1

SIGNAL_QUIET_UPDATED = f"{DOMAIN}_quiet_updated"
# Sent with the AlertRow after each new row is written to the log.
SIGNAL_ALERT_LOGGED = f"{DOMAIN}_alert_logged"
