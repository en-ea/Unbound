---
title: "Research - what makes simulated villages feel alive (crime, justice, rumour, crowds, pacing)"
created: 2026-09-29
type: research
voice: agent research (a research subagent, 29 Sep 2026); recorded verbatim in substance, lightly condensed
author: research agent, commissioned by Claude, lead agent in Hilmi's studio
status: evidence for docs/studio/VILLAGE-PLAN.md
next_step: none of its own; the village plan acts on it (sections 5-8)
---

# What makes simulated villages feel alive

**Labels.** Facts about each source are `[web]`. The agent notes that WebFetch was broken, so it read four primary texts in full and took the rest from search excerpts:
- the Talk of the Town chapter;
- the Versu architecture paper;
- the Shadows of Doubt devblog 8;
- Sylvester's "The Simulation Dream".

Every "steal" or "avoid", and the whole synthesis, is `[design]`. `[inference]` marks the agent's own reasoning.

**Verdict.** The games whose villages feel alive run a few rules the player can see working, not a big simulation. Five patterns recur:
- per-culture norm tables that make the same act mean different things;
- places that advertise actions;
- knowledge limited to witnesses;
- crowds as threshold cascades;
- a pacing director that rations the big moments.

The failures fall into four groups: killing as the cheapest route to any goal, "procedural oatmeal" sameness, invisible causes, and people reduced to meters.

## Per-source findings

**Dwarf Fortress: personality.**
- Facets are inborn integers from 0 to 100, with a median per species (goblin altruism has a median of 25 and a cap of 50).
- Values between 40 and 60 are never reported to the player.
- About 30 values (law, family, tradition, sacrifice...); a villager whose value deviates from their civilisation's is highlighted.
- Needs come from facets and values, with fulfilment intervals from every 2 years (level 1) to every 3 months (level 10). Unmet needs cut focus by up to 50% of skill, separately from stress. Memories can shift values.
- **Failed:** most facet effects are small or undocumented, and all of it is read on text screens.
- **Steal:** integers with a silent middle band, so only the extremes become visible mannerisms.
- Source: https://dwarffortresswiki.org/index.php/Personality_facet

**Dwarf Fortress: justice.**
- A crime opens a case listing its witnesses; if nobody saw the act, only the loss is known.
- Interrogation succeeds or fails on both sides' social skills; questioning an innocent costs only work time.
- Punishments queue (beating, jail, hammering) and are downgraded if there is no jail.
- **Failed, the tantrum spiral:** one death stresses a whole family, punishment deaths add more grief, and a hammerer punishing earlier tantrums can restart it. In the "loyalty cascade", friends always defended the aggressor. Burials and memorials are the documented damper.
- **Steal:** cases exist only if someone witnessed the crime. **Avoid:** grief with no damper.
- Sources: https://dwarffortresswiki.org/index.php/Justice and https://dwarffortresswiki.org/index.php/v0.34:Tantrum

**Dwarf Fortress: villains.**
- Villains corrupt office-holders by intimidation, rank, blackmail, flattery, religious appeal, promised revenge or bribes, choosing by an estimate of what will work that is deliberately wrong when the agent is unskilled.
- Framing someone needs influence over law enforcement; agents arrive in disguise under false names.
- **Failed:** most of it is invisible in fortress mode, and the player can't stop it.
- **Steal:** manipulation built on fallible estimates, so bribes can misfire. **Avoid:** plots with no visible trace.
- Source: https://dwarffortresswiki.org/index.php/Intrigue

**RimWorld: storyteller.**
- Cassandra alternates "on" cycles (4.6 days, 1-2 major threats at least 1.9 days apart) with 6-day "off" cycles: about 8.5 major threats a year, identical after reloading a save.
- "Population intent" makes recruits likelier while the colony is small. An adaptation factor eases threats after colonists die. Threat size scales with wealth.
- **Loved:** guaranteed breathers. **Failed:** wealth scaling taught players to live in squalor to shrink raids.
- **Steal:** a keyed on/off cycle. **Avoid:** scaling threats on a number the player can game.
- Sources: https://rimworldwiki.com/wiki/Cassandra_Classic and https://rimworldwiki.com/wiki/Raid_points

**RimWorld: mood, breakdowns, fights, rituals.**
- The minor-breakdown line sits at the threshold stat (35% by default); major is 4/7 of it and extreme 1/7. Each tier has a mean time between breakdowns, and the kind is chosen at random.
- Each insult has a 4% chance of starting a fight, and each slight 0.5%; an "insulting spree" can stack -33 mood.
- Ideology's precepts rate execution from "abhorrent" to "required". Rituals score higher with more spectators, and a gladiator duel's crowd gets more excited if a fighter dies.
- **Steal:** a precept for each act, per culture; breakdown timing rolled with keyed randomness.
- Sources: https://rimworldwiki.com/wiki/Mental_break and https://rimworldwiki.com/wiki/Rituals

**Sylvester, "The Simulation Dream".**
- A game's value lives in the model of it that forms in the player's head.
- "Story-richness" is the share of interactions that matter; "hair complexity" is flavour that feeds nothing back.
- His worked example: a 100-villager simulation becomes an unreadable hairball.
- **Steal:** use these rules to filter every variable we add.
- Source: https://tynansylvester.com/2013/06/the-simulation-dream/

**Crusader Kings 3.**
- A secret is "criminal" or merely "shunned" depending on the faith's doctrines, and can be exposed or turned into a hook (a weak hook works once, a strong one repeats).
- Schemes have a success chance, phases and secrecy, with up to 5 agents.
- Stress runs from 0 to 400, with breakdowns the first time it passes 100, 200 and 300, and coping traits (drunkard, flagellant).
- Executing a prisoner costs opinion (-20 with the dynasty, -30 with friends, -50 with family) and adds +2 tyranny unless the crime was severe. A public execution gives +15 popular opinion for 5 years.
- **Loved:** consequences that build up over a lifetime. **Failed:** written events repeat (GameSpot's review; the "cat story").
- **Steal:** crime category set by doctrine; opinion penalties spreading along kin and friends. **Avoid:** event cards as the main story source.
- Sources: https://ck3.paradoxwikis.com/Hooks, https://ck3.paradoxwikis.com/Prisoner, https://www.gamespot.com/reviews/crusader-kings-3-review-vicious-cycles/1900-6417551/

**Shadows of Doubt.**
- 4-10 daily journeys per citizen are planned in a batch before the day starts (10-15 seconds); only the few who deviate are replanned live.
- One global sighting check covers travelling citizens, including views through lit windows.
- Memories start accurate, then the time blurs first, then the memory is lost; forgetting is faster for strangers, bland faces, weak memories and low alertness.
- Innocent citizens whose presence looks bad may lie. Prints and blood fade within hours. A wrong accusation costs a fine, and the killer keeps killing.
- **Failed:** "samey" after a few hours: about five murder types, the same documents everywhere, and killers with no motive.
- **Steal:** planning each day at dawn, a sightings table, and time accuracy that fades. **Avoid:** crimes with no grievance behind them.
- Sources: https://colepowered.com/shadows-of-doubt-devblog-8-simulating-a-city/ and https://playday.one/2024/09/23/shadows-of-doubt-review/

**Talk of the Town (Ryan, Mateas, Summerville).**
- Each belief keeps its value, the belief it replaced, a list of evidence, a strength and whether it's accurate.
- There are 11 evidence types:
  - **Origin:** observation, transference, confabulation, lie, implant, reflection.
  - **Spreading:** statement, eavesdropping.
  - **Reinforcement:** declaration. Retelling strengthens a belief, so a habitual liar comes to believe the lie.
  - **Decay:** mutation along a hand-written graph.
  - **End:** forgetting.
- "Salience" (the relationship to the observer, and the type of detail) decides what gets noticed, told and forgotten. Heard evidence is weighted by how much the listener likes the source and how sure the source is. A new belief wins only if its evidence is stronger, so beliefs can flip back and forth.
- Confabulated details follow the town's real distribution.
- **Failed:** too expensive to simulate, so knowledge was implanted at world generation; abandoned in 2017; its showcase (Bad News) needed a live actor.
- **Steal:** the evidence types, reinforcement by retelling and the mutation graph, applied to crime facts only.
- Source: https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter37_Simulating_Character_Knowledge_Phenomena_in_Talk_of_the_Town.pdf

**Versu (Evans, Short).**
- "Social practices" (a dinner, a conversation) are objects with roles that offer actions and never command; each agent picks by utility.
- An action that breaks a norm is marked "violated", and NPCs strongly avoid it. A violation spawns a response practice (disapprove, forgive, get angry, evict).
- The interface shows each emotion with its target and cause. A "dominating practice" (a body found) suppresses jokes and flirting.
- **Lessons:** with over 300 desires, tuning was "difficult and unrewarding". The Sims 3 needed extra animations for inner conflict (a shy host answering the door reluctantly).
- **Steal:** a public punishment as a dominating practice with roles; adverbs like "reluctantly" as cheap pose and pace modifiers.
- Source: https://versu.com/wp-content/uploads/2014/05/versu.pdf

**Comme il Faut and Prom Week.**
- Social exchanges have an initiator, a responder and an optional third party. Desire to start one is the sum of the weights of rules currently true; shared rule sets carry the general rules. Responder rules decide acceptance, and trigger rules fire afterwards.
- 18 characters, 40+ exchanges, 5,000+ rules; the interface shows each character's ranked wishes.
- **Failed:** hand-written dialogue couldn't express the social state.
- **Steal:** desire as an integer sum of weighted rules. **Avoid:** the rule count.
- Source: http://www.ben-samuel.com/wp-content/uploads/2015/09/FDG-2011-Prom-Week-Social-Physics-as-Gameplay.pdf

**The Sims.**
- Needs ("motives") decay; objects advertise how much they satisfy each motive; a Sim weights the offers by current needs and picks the best.
- Behaviour lives in the objects, so new objects add behaviour without touching the agents.
- An early build made Sims too capable, and the team made them dumber so the player had a role.
- **Steal:** the pillory, gallows, well and shrine advertise actions (jeer, pelt, pray, draw water), so new punishments are data. **Avoid** always picking the single best option: `[inference]` crowds would move in lockstep.
- Source: https://gmtk.substack.com/p/the-genius-ai-behind-the-sims

**Frostpunk.**
- Laws can't be revoked, and each is priced in hope and discontent.
- The Execution Platform, at the end of the Order or Faith tree, kills a random adult "public enemy" at 22:00, with a 2-day cooldown and a sharp drop in discontent. "Public Penance" injures some citizens, lowers discontent and raises hope.
- The designer, Marta Fijak: players can't care about 700 people; they become numbers.
- **Critics:** hope treated as a resource. **Steal:** irreversible laws, and a reckoning at the end. **Avoid:** a punishment button aimed at an anonymous victim.
- Sources: https://frostpunk.fandom.com/wiki/Execution_Platform and https://www.pcgamesinsider.biz/news/67933/11bits-marta-fijak-empathising-with-500-people-is-hard-in-frostpunk/

**Oblivion's Radiant AI.**
- NPCs got general goals instead of scripts.
- **Failed:** addicts murdered a quest-giving dealer for his stock, and others killed for items, breaking quests. NPCs stealing from the player was cut because players took missing items for bugs. It was also too heavy for the Xbox 360. For Skyrim, Howard said an open playground went badly for many players, and "Radiant Story" gave control back.
- **Avoid:** killing as the cheapest route to a goal. Every crime needs a motive, an opportunity and weak enough inhibitions; story-critical roles are protected.
- Sources: https://www.gamesradar.com/remember-skyrims-radiant-ai-its-got-the-potential-to-revolutionise-rpgs/ and https://en.wikipedia.org/wiki/Radiant_AI

**Village-life games.**
- **Kenshi:**
  - Witnessed crimes post bounties that expire within hours unless the criminal is notorious; severity sets the sentence.
  - NPCs obey the same laws as the player.
  - Killing or capturing a faction leader flips a "world state", swapping the town for a pre-written version; the developer capped this because complexity grows exponentially.
  - **Steal:** pre-written town versions keyed to world flags.
  - Source: https://kenshi.fandom.com/wiki/World_States
- **Bannerlord:**
  - Relations are with individual notables, not with whole villages. Executing a lord turns every notable in his fiefs against you. Crime ratings are per kingdom and decay.
  - **Steal:** grudges held by people.
  - Source: https://mountandblade.fandom.com/wiki/Notables
- **Medieval Dynasty:**
  - Mood is a checklist (house 50%, job skill 20%, marriage 10%, 5% per child).
  - Reviews: villagers feel lifeless, quests are fetch loops, whole villages sleep at night.
  - **Avoid:** checklist mood.
  - Source: https://medieval-dynasty.fandom.com/wiki/Mood
- **Manor Lords:**
  - Workers are families of three; approval above 50% on the first of the month admits one family, above 75% two.
  - Critics liked the ambient chatter but missed stories from the people; players asked for births, deaths and festivals.
  - **Steal:** ambient barks. **Avoid:** faceless family units.
  - Source: https://en.wikipedia.org/wiki/Manor_Lords

**STALKER A-Life.**
- Offline behaviour is a lower level of detail of online behaviour: only NPCs within about 150 m run full AI; offline NPCs move on a coarse graph, and "smart terrains" hand out tasks (hence the campfire scenes).
- **Failed, STALKER 2:** after the simulated radius was shrunk, the game shipped spawning NPCs in a bubble around the player with no offline progress. Patch 1.1 restored offline progress and stopped spawns behind the player.
- **Steal:** two tiers running the same rules. **Avoid:** spawning around the player.
- Sources: https://www.gamedeveloper.com/game-platforms/interview-inside-the-ai-of-i-s-t-a-l-k-e-r-i- and https://www.thesixthaxis.com/2024/12/19/huge-stalker-2-patch-1-1-brings-over-1800-fixes-a-life-improvements/

**Salem.**
- Boyer and Nissenbaum mapped accusers on the western, farming Putnam side and the accused on the eastern, commercial Porter side. Ray (2008) found no significant east-west split, so that faction line is contested.
- Better attested:
  - of about 152 formal accusations, only about 39 were in Salem Village and Town;
  - Andover had the most, after a man invited the afflicted girls to see his sick wife;
  - a town-wide touch test there led to 17-18 arrests;
  - the magistrate who then refused further warrants was accused himself;
  - those who confessed survived, those who denied were hanged.
- **Steal:** cascades travel along invitations and kin; resisting the process makes you a target; confession trades guilt for life.
- Sources: https://www.gilderlehrman.org/history-resources/essays/years-magical-thinking-explaining-salem-witchcraft-crisis, https://www2.tulane.edu/~salem/Andover%20Accusations.html, http://www2.iath.virginia.edu/bcr/geoconflict2.html

**Oster 2004.**
- Witch trials rose with cold weather and slow growth, reviving around 1560 with a sharp temperature drop.
- Contested: Leeson and Russ (2018) don't reproduce it in a larger dataset; Christian (2019) found good harvests raised Scottish trials by funding the prosecutors.
- **Steal:** two separate dials: hardship (demand for a scapegoat) and the authorities' capacity (supply of trials).
- Source: https://www.aeaweb.org/articles?id=10.1257/089533004773563502

**Granovetter 1978.**
- Each person joins once the number already acting passes their personal threshold. With thresholds spread evenly from 0 to 99, 100 people riot; change the person with threshold 1 to 2, and one window breaks.
- Macy and Evtushenko (2020): a little randomness makes outcomes more predictable. Centola and Macy (2007): "complex" contagions need several independent sources.
- **Steal:** mobs and escalating pelting as threshold cascades. An accusation needs 2 independent sources to be believed; ordinary gossip needs 1.
- Sources: https://www.journals.uchicago.edu/doi/abs/10.1086/226707 and https://www.journals.uchicago.edu/doi/10.1086/521848

**Ordeals, the scaffold, the scapegoat.**
- **Ordeals:** at Várad, 130 of 208 hot-iron ordeals (62.5%) acquitted; Leeson argues the priests rigged them, because only the innocent volunteered.
- **The scaffold:** Foucault notes that execution crowds sometimes sided with the condemned, rioted and rescued them.
- **The pillory:** Defoe's 1703 crowd threw flowers and drank his health (partly legend).
- **The scapegoat:** Girard describes the victim as first demonised, then made sacred.
- **Steal:** every punishment carries a possible reversal.
- Sources: https://www.peterleeson.com/Ordeals.pdf, https://www.britannica.com/topic/Hymn-To-The-Pillory, https://iep.utm.edu/girard/

## Synthesis `[design]`

**The ten mechanisms most worth adopting** (believability gained ÷ cost; the costs are `[inference]`):
1. **Culture norm table:** each act rated per culture and era (required, respected, indifferent, shunned, criminal, abhorrent), driving reactions. This is the ancestors-versus-present clash and the main thing that makes villages differ. A table lookup.
2. **Smart sites that advertise roles,** weighted by needs and values, with a weighted-random choice among the top three. A slow tick; new punishments are data.
3. **Knowledge limited to witnesses:** one cheap visibility pass per tick fills a sightings table; with no witness, only the effect is known.
4. **Threshold crowds:** each villager has an integer threshold (personality, grievance, kinship to the condemned). Escalation, and mobs forming or dissolving, happen by cascade. The player's lever is the early joiners. O(n) per event.
5. **Pacing director:** a keyed on/off cycle per village; at most one lethal public event per on-cycle; festivals and weddings in the off-cycles.
6. **Dawn planning plus two tiers of detail:** plan the day at dawn, replan only those who deviate; offline villages run the same rules on a daily tick. One batch per game day; this makes the rest affordable.
7. **Stress from acting against one's values, with visible coping:** an executioner who values mercy starts drinking; a juror refuses to take part. Keyed breakdown timing.
8. **Evidence-typed beliefs, for crime facts only:** observed, told, lie, confabulated (confabulation leans towards the disliked); retelling strengthens; mutation and forgetting on a slow tick; about 8 facts per villager.
9. **Norm-violation responses and dominating practices:** a violation spawns responses (disapprove, forgive, report, attack), and a public punishment dominates, making the whole village spectators with roles.
10. **Reversal outcomes:** the crowd turns, a rescue succeeds, an ordeal acquits, a confession buys mercy, or the executed become martyrs with a shrine. Content, not compute.

**The five failure modes to design against:**
1. **Runaway violence** (Radiant AI; Dwarf Fortress spirals and loyalty cascades). Motive, opportunity and weak inhibition are required; a violence budget per village; grief dampers (burial, memorial, wake); kin defend each other only when the kin is the victim.
2. **Sameness** (Shadows of Doubt, the CK3 cat story, Medieval Dynasty). Each crime comes from a specific grievance; villages differ in norm table, era and founding feud; each village remembers recent events and never repeats a type twice in a row; judge by look boards, not seed counts ("Perceptual uniqueness is the real metric", Kate Compton).
3. **Invisible causes** (Sylvester's hairball, DF villains, Oblivion's missing items). Simulate only variables that end in a story; every emotion shows its target and cause as a look, a gesture or a place; plots leave physical traces.
4. **People as meters** (Frostpunk bars, Manor Lords families). Everyone punished is named, has a home and relatives; kin react on camera; aftermath objects persist (an empty chair, a grave, a shrine).
5. **Fakery the player notices** (STALKER 2's bubble, Shadows of Doubt's robotic answers). Offline villages run the same rules on a coarse tick, nothing spawns in view, and a headless probe checks that offline and online runs agree.

**Keeping death and punishment from being grim or monotonous:**
- **Rarity keeps weight.** Most cases end in a fine, penance, the pillory or exile; death needs the norm table, the cascade and the authority to line up.
- **Several endings, and the crowd picks:** carried out, commuted, rescued, the crowd turns, an ordeal acquits (62.5% at Várad), a confession spares, or veneration (Girard). No single ending above about 40% in any village.
- **Veneration is a real system.** Once the truth about a wrongful execution spreads, the grave becomes a shrine that advertises prayer and flowers, lowers stress and draws pilgrims; the accuser's standing collapses. Ancestors may venerate what the present condemns, through the same norm table.
- **Rhythm:** on-cycles for the big moments; births, weddings, festivals and harvests in the off-cycles.
- **Farce from the same systems:** a stolen goose, a pillory pelted with vegetables, escalating only if the cascade crosses its threshold; absurdity stays non-lethal.
- **Aftermath over the act:** grief rites, feuds and memorials carry the story. As Sylvester argues, loss is part of the story, not its end.
