extends RefCounted
## Explicit old/new boundary. 26 inherited modules stay discoverable for stage endings, partings,
## enemies, kills and carcasses. No new reactions there; contact/threat/gift/help use only the new chooser.
const RETIRED_STATES := ["puzzled","startled","protest","flee","call_help","fight_back","plead","down",
	"intervene","shout","back_away","watch"]
const MIGRATED := ["contact","threat","gift","strike","shove","square_up","help","fire","burn",
	"fall","burning","cry","death","doused","aftermath","extinguish","carry","set_down"]
static var rejected := 0
static func handles(kind: String) -> bool:
	if MIGRATED.has(kind):
		rejected += 1
		return false
	return true
