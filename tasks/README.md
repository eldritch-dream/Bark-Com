# Bark-Com Tasks

Imported from `TODO.txt` on 2026-05-16. Each task is a markdown file in `active/`, `review/`, `completed/`, or `post-release/`, numbered in import order (`NNN-slug.md`).

- **active/** — concrete polish/bug/balance work for the current release push
- **review/** — needs a decision before action (design question, possibly already fixed, ambiguous scope)
- **completed/** — finished work (move files here as they ship)
- **post-release/** — deferred features and larger reworks; see [post-release/README.md](post-release/README.md)

Focus right now is polishing the main game before release. New features and large reworks have been moved to `post-release/` to avoid scope creep. When closing a task, move the file to `completed/` rather than deleting it, so the history stays.

Active tasks are in **priority order** — the first item is the highest priority. Category tags are for reference only; they do not group or gate priority.

---

## Index

### Active

- [001 — Action cam ignores camera rotation (q/e)](active/001-action-cam-camera-rotation.md) *(Bug)*
- [012 — Some fonts ignore the font-size slider](active/012-fonts-font-slider.md) *(Bug)*
- [014 — Map chunk has multiple orphaned ladders](active/014-orphaned-ladders-map-chunk.md) *(Bug)*
- [017 — Enemy turn starts before ally finishes moving or grenade animates](active/017-enemy-turn-starts-too-early.md) *(Bug)*
- [025 — Action cam and floating text conflict](active/025-action-cam-floating-text-bug.md) *(Bug)*
- [029 — Auto-end turn does not trigger when out of AP](active/029-auto-end-turn-at-0-ap.md) *(Bug)*
- [041 — Invasion level does not increase after mission complete](active/041-invasion-not-increasing.md) *(Bug)*
- [044 — Loot box light makes nearby enemies look yellow](active/044-loot-box-light-enemies-yellow.md) *(Bug)*
- [065 — Shot VFX is broken](active/065-fix-shot-vfx.md) *(Bug)*
- [088 — Grenadier charges do not affect ammo for item grenades](active/088-grenadier-charges-vs-item-grenades.md) *(Bug)*
- [105 — Hit chance bug: heavy adjacent to enemy cannot see it](active/105-hit-chance-adjacent-enemy.md) *(Bug)*
- [107 — Rescue action at 0 AP / does not end turn / goes to -1 AP](active/107-rescue-action-ap-bugs.md) *(Bug)*
- [108 — Cannot attack some crate objects (since biome refactor)](active/108-crate-objects-not-attackable.md) *(Bug)*
- [109 — Movement helper squares lie about valid squares](active/109-movement-helper-square-lies.md) *(Bug)*
- [111 — Move-through-ally is broken](active/111-move-through-ally-broken.md) *(Bug)*
- [112 — Mission "Kitchen" biome name does not match biome](active/112-mission-name-biome-mismatch.md) *(Bug)*
- [113 — Barrel turn timing and burning duration are off](active/113-barrel-turn-timing.md) *(Bug)*
- [114 — Clicking does not clear line hit chance indicator](active/114-click-doesnt-clear-line-hit-indicator.md) *(Bug)*
- [116 — Player turn occasionally skipped, cause unclear](active/116-player-turn-skipped.md) *(Bug)*
- [117 — Deploy screen loses selection on leave and return](active/117-deploy-screen-selection-lost.md) *(Bug)*
- [119 — Missions not persisted in user save](active/119-missions-not-persisted.md) *(Bug)*
- [121 — Win screen gets skipped easily](active/121-win-screen-skipped.md) *(Bug)*
- [122 — Action cam does not show all important events](active/122-action-cam-missing-events.md) *(Bug)*
- [124 — Ghost "?" image on revealed-but-out-of-sight tile](active/124-ghost-out-of-sight-marker.md) *(Bug)*
- [125 — High font size obscures numbers on bottom unit screen](active/125-font-size-obscures-numbers.md) *(Bug)*
- [126 — Cover helper does not update after cover is destroyed](active/126-cover-helper-stale-after-destroy.md) *(Bug)*
- [128 — Abilities not greyed out when out of AP](active/128-abilities-not-greyed-at-0-ap.md) *(Bug)*
- [131 — Double poison damage floating text](active/131-double-poison-damage-text.md) *(Bug)*
- [132 — Paramedic sanity scaling broken (444 in mission)](active/132-paramedic-sanity-444.md) *(Bug)*
- [134 — Enemies spawn on low wall tiles with nowhere to go](active/134-enemies-spawn-on-low-wall.md) *(Bug)*
- [135 — Low wall tile does not provide cover](active/135-low-wall-no-cover.md) *(Bug)*
- [137 — Player units spawn on a ladder tile incorrectly](active/137-player-spawn-on-ladder.md) *(Bug)*
- [011 — Actions should stay clicked to allow multi-action chains](active/011-actions-stay-clicked.md) *(UX)*
- [016 — Remove AI pathfinding / walkability debug overlays during mission](active/016-remove-debug-overlays-in-mission.md) *(UX)*
- [018 — Camera follows squad panel selection but not direct model selection](active/018-camera-follow-selection-rule.md) *(UX)*
- [022 — Make nerd stat box more visually intuitive](active/022-nerd-stat-box-clarity.md) *(UX)*
- [024 — Add icons to skill tree](active/024-skill-tree-icons.md) *(UX)*
- [042 — Hover effect on units (glow)](active/042-unit-hover-glow.md) *(UX)*
- [045 — Skill tree shows binary choice, paths not forced](active/045-skill-tree-binary-choice.md) *(UX)*
- [048 — Rescue-mission spawn pulse on turn 2 and auto-end on cleared](active/048-rescue-mission-flow.md) *(UX)*
- [049 — Document 2x damage on headshot in-game](active/049-headshot-2x-doc.md) *(UX)*
- [050 — Better cloaking effect and action cam](active/050-cloaking-effect.md) *(UX)*
- [052 — Click to unequip items/weapons in barracks](active/052-click-to-unequip.md) *(UX)*
- [058 — Reset camera button](active/058-reset-camera-button.md) *(UX)*
- [061 — Show mission count and kills on nerd stats screen](active/061-nerd-stats-show-counts.md) *(UX)*
- [066 — Middle mouse click and hold to rotate camera (OSRS style)](active/066-mmb-rotate-camera.md) *(UX)*
- [068 — Destructible objects clickable for description](active/068-destructible-clickable-info.md) *(UX)*
- [070 — Mission card redesign](active/070-mission-card-redesign.md) *(UX)*
- [071 — Weapon animations](active/071-weapon-animations.md) *(UX)*
- [075 — Select actions from action bar via number keys](active/075-action-bar-number-keys.md) *(UX)*
- [076 — Right mouse click to move map (controls redesign)](active/076-rmb-move-map.md) *(UX)*
- [080 — Unchosen skill points not obvious](active/080-unchosen-skill-points-visibility.md) *(UX)*
- [086 — Show bond hearts above allies in range on selection](active/086-bond-hearts-on-selection.md) *(UX)*
- [094 — Add icon helper to field manual](active/094-field-manual-icons.md) *(UX)*
- [095 — Ankle biter animation and sound effect](active/095-ankle-biter-anim-sfx.md) *(UX)*
- [096 — Dismiss unit button](active/096-dismiss-unit-button.md) *(UX)*
- [097 — Map tiles need expanded textures for visual variety](active/097-map-tile-textures.md) *(UX)*
- [100 — User feedback button in options](active/100-feedback-button.md) *(UX)*
- [110 — Sanity break statuses are not explained anywhere](active/110-sanity-break-not-explained.md) *(UX)*
- [118 — Always display Player/Environment/Enemy phase on screen](active/118-phase-indicator-always.md) *(UX)*
- [133 — Fleeing tween looks janky, should use movement](active/133-fleeing-tween-janky.md) *(UX)*
- [136 — Unit detail panel name location is unclear to users](active/136-unit-detail-name-clarity.md) *(UX)*
- [151 — Proper win screen and credits](active/151-win-screen-and-credits.md) *(UX)*
- [013 — Class power review (heavy base hit too low)](active/013-class-power-review.md) *(Balance)*
- [033 — More sanity loss across the game](active/033-more-sanity-loss.md) *(Balance)*
- [067 — Stunned target should grant easy-to-hit bonus](active/067-stunned-easy-hit-bonus.md) *(Balance)*
- [077 — XP scaling, more XP-granting actions](active/077-xp-scaling.md) *(Balance)*
- [079 — Heal gun rebalance (restrictions, hit chance, per-mission ammo)](active/079-heal-gun-rebalance.md) *(Balance)*
- [081 — Percent-based heal](active/081-percent-based-heal.md) *(Balance)*
- [082 — Enemy damage scaling with party level](active/082-enemy-damage-scaling.md) *(Balance)*
- [102 — Ammo for acid spitter's spit attack](active/102-acid-spit-ammo.md) *(Balance)*
- [103 — Increase triage range (drone animation)](active/103-triage-range.md) *(Balance)*
- [115 — Bump up default grenade ability / item range](active/115-grenade-default-range.md) *(Balance)*
- [130 — Destructible cover should not be vulnerable to acid/poison](active/130-destructible-cover-acid-immune.md) *(Balance)*
- [138 — Recruiting higher-level dogs is too powerful](active/138-recruit-level-balance.md) *(Balance)*
- [036 — Refactor weapon system negative range multiplier to accuracy](active/036-weapon-range-accuracy-refactor.md) *(Refactor)*
- [090 — Rename `recruit` → `officer`](active/090-rename-recruit-officer.md) *(Refactor)*
- [015 — Optimize browser experience (occasional massive lag spikes)](active/015-browser-perf.md) *(Performance)*
- [104 — Better build process](active/104-better-build-process.md) *(Tooling)*

### Review (decide first)

- [002 — Better understand the rest system](review/002-rest-system-explainer.md)
- [004 — Better understand the smell system](review/004-smell-system-explainer.md)
- [019 — Better understand the height system](review/019-height-system-explainer.md)
- [031 — Should we remove sanity heal?](review/031-remove-sanity-heal-question.md)
- [051 — Max HP wrong in mission (marked "fixed?")](review/051-max-hp-wrong-fixed-question.md)
- [056 — Scaling difficulty completeness (some shipped already)](review/056-scaling-difficulty-completeness.md)
- [085 — "Address all scaling" — too broad, needs scoping](review/085-address-all-scaling.md)
- [106 — Enemy AI: exploder using normal attack (possibly fixed)](review/106-exploder-normal-attack-fixed.md)
- [120 — Exploder still using ranged attack in some pathfinding cases](review/120-exploder-ranged-attack-pathfind.md)
- [123 — Revealed units become invisible when out of squad sight](review/123-revealed-units-fade-design.md)
- [127 — Sanity floating text delayed / appears multiple times](review/127-sanity-floating-text-delay.md)
