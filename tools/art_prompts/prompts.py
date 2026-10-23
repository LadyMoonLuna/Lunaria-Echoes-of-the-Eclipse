#!/usr/bin/env python3
"""Prompts de geração 3D (Meshy, Tripo3D, Rodin, CSM) no modelo de arte do projeto.

Cada entrada preenche os campos entre colchetes do template:
  [SUJEITO], [DESCRIÇÃO FÍSICA / ROUPA / TEXTURA], [CORES / ILUMINAÇÃO]

Raças geram duas variantes (masculina e feminina). O campo `uid` é o nome do arquivo
que o jogo procura em client/assets/models/hd/<uid>.glb quando o modelo gerado
estiver pronto (ver docs/art/README.md).

Uso:  python3 tools/art_prompts/prompts.py
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUT_MD = os.path.join(REPO, "docs", "art", "prompts_3d.md")
OUT_JSON = os.path.join(REPO, "docs", "art", "prompts_3d.json")
HTML_TEMPLATE = os.path.join(HERE, "page_template.html")
OUT_HTML = os.path.join(REPO, "docs", "previews", "prompts_3d.html")

STYLE = ("heroic anime art style inspired by Sword Art Online and Fate series. Expressive sharp features, "
         "detailed textures, {colors}. Dark fantasy anime video game aesthetic, cel-shaded details with high-end "
         "Unreal Engine 5 render lighting, {framing}, plain neutral gray background, {hands}, 8k resolution.")

FRAMING = {
    "character": ("Full body character concept art of", "symmetrical A-pose, full body"),
    "creature": ("Full body creature concept art of", "neutral standing pose in three-quarter side view, full body"),
    "biped_creature": ("Full body creature concept art of", "symmetrical A-pose, full body"),
    "item": ("Close-up item concept art of", "close-up, centered three-quarter view, isolated single object"),
    "outfit": ("Full body character concept art of", "symmetrical A-pose, full body"),
}


def render(kind, subject, details, colors, hands="no extra clutter in hands unless specified"):
    lead, framing = FRAMING[kind]
    if not subject.startswith(("a ", "an ", "the ")):
        subject = ("an " if subject[0].lower() in "aeiou8" or subject.startswith("1") and subject[:2] in ("11", "18") else "a ") + subject
    return "%s %s, %s, %s" % (lead, subject, details, STYLE.format(colors=colors, framing=framing, hands=hands))


# ---------------------------------------------------------------------------
# Raças (variantes masculina e feminina)
# (uid, nome, [sujeito masc, sujeito fem], detalhes, cores)
# ---------------------------------------------------------------------------
RACES = [
    ("race_1", "Valeriano", ["25-year-old male human adventurer", "24-year-old female human adventurer"],
     "athletic classic proportions, determined heroic face, short wind-swept brown hair, simple starter outfit of "
     "loose beige linen shirt under a fitted brown leather vest with brushed steel buckles, rope belt, brown leather "
     "trousers and worn travel boots, fine fabric weave and leather grain visible",
     "warm earthy browns and soft beige with brushed steel accents, golden-hour rim light"),
    ("race_2", "Noctari", ["tall slender male moon elf", "tall slender female moon elf"],
     "very long pointed ears swept backwards, pale bluish porcelain skin, long flowing silver-white hair, glowing "
     "cyan lunar eyes, elegant midnight-blue fitted robes with silver filigree trim and a long sash",
     "midnight blue, silver and glowing cyan, cold moonlight key light with soft blue rim"),
    ("race_3", "Kharad", ["short broad-shouldered male ash-forged dwarf-like being, 1.5 meters tall",
                          "short broad-shouldered female ash-forged dwarf-like being, 1.5 meters tall"],
     "dense musculature, skin of dark grey basalt rock split by glowing orange ember fissures, bald stone head, "
     "eyes like hot coals, heavy leather kilt and wide belt, cracked stone texture with volcanic pores",
     "charcoal grey basalt with molten orange #FF5722 glowing cracks, warm forge underlighting"),
    ("race_4", "Varkai", ["athletic male beast-blooded warrior", "athletic female beast-blooded warrior"],
     "feline and lupine posture, furry wolf ears on top of the head, visible fangs, black claws, long furry tail, "
     "slit amber eyes, wild tousled hair, light leather harness and wraps, detailed individual fur strands",
     "tawny brown fur, dark leather, glowing amber eyes, warm sunset light with strong rim"),
    ("race_5", "Dhampir / Vampiro Progenitor", ["aristocratic male vampire noble", "aristocratic female vampire noble"],
     "cold white marble skin, cadaverous elegant face, glowing ruby red eyes, long upper fangs, sharp black nails, "
     "slicked-back black hair, high gothic red-and-black collar, long fitted black coat with crimson velvet lining "
     "and silver brooch",
     "black, deep crimson #E74C3C and silver, cold moonlight with crimson rim light"),
    ("race_6", "Licantropo Primordial", ["colossal 2.3-meter male primordial werewolf", "colossal 2.3-meter female primordial werewolf"],
     "bipedal wolf with digitigrade legs, gigantic chest covered in thick black and crimson fur, ferocious scarred "
     "wolf head, long claws, bristling mane, torn trouser remnants, each fur clump individually sculpted",
     "black and blood-crimson fur, burning red eyes, blood moon backlight with red rim"),
    ("race_7", "Amaldiçoado das Cinzas (Revenant)", ["undead male revenant warrior", "undead female revenant warrior"],
     "dried grey skin stretched tightly over bones, exposed ribs in the center of the chest caging a bright pulsing "
     "cyan spirit flame like a heart, hollow eye sockets with cyan pinpoints, tattered dark cloth and rusted iron "
     "pauldron",
     "ashen grey, rusted iron, glowing cyan #00FFFF soul fire as main light source"),
    ("race_8", "Celestino (Serafim Astral)", ["serene male astral seraph", "serene female astral seraph"],
     "body sculpted from polished white marble with flowing gold veins, serene face with pupil-less eyes emitting "
     "golden light, golden circlet, four wings made of translucent golden light blades floating detached from the back",
     "white marble, gold and radiant light, divine top light with bloom"),
    ("race_9", "Abissal (Filho do Eclipse)", ["faceless male child of the eclipse", "faceless female child of the eclipse"],
     "entirely matte black silhouette with a deep starry night sky texture across the body, featureless face with only "
     "two glowing purple eyes, a small black hole with a spinning purple and orange fire ring set in an opening in the chest",
     "void black with tiny white stars, purple and orange accretion glow, dramatic low-key lighting"),
    ("race_10", "Autômato Rúnico (Alma Forjada)", ["medieval runic automaton knight (masculine build)",
                                                   "medieval runic automaton knight (feminine build)"],
     "body of aged bronze plates and black iron, exposed gears at elbows and knees, mouthless helm with a horizontal "
     "glowing cyan visor slit, rotating crystal core in the chest, engraved runes and rivets",
     "aged bronze, black iron, glowing cyan #00E5FF, workshop key light with cool rim"),
    ("race_11", "Alto Valeriano", ["noble 28-year-old male high human", "noble 26-year-old female high human"],
     "athletic proportions, brown hair with luminous golden streaks, eyes of pure gold, a subtle floating solar "
     "crown of golden rays above the forehead, refined linen and leather garments with gold trims",
     "gold, warm brown and ivory, radiant golden backlight"),
    ("race_12", "Andarilho do Éter", ["28-year-old male ether wanderer", "26-year-old female ether wanderer"],
     "hair tips and forearms darkened into a swirling galaxy void texture of purple #8E44AD with tiny stars, glowing "
     "violet eyes, travel clothes of linen and leather torn by space rifts, small floating star motes",
     "deep purple galaxy, black void, violet glow, cosmic rim light"),
    ("race_13", "Arconte Lunar", ["tall male lunar archon elf", "tall female lunar archon elf"],
     "long swept-back pointed ears, pale bluish skin with glowing silver astral tattoos on face and arms, long silver "
     "hair, ornate midnight robes with silver filigree, a crystal silver crescent moon floating behind the back",
     "silver, midnight blue and soft cyan glow, moonlit rim light"),
    ("race_14", "Espectro Umbral", ["male umbral specter elf", "female umbral specter elf"],
     "night-grey skin #2C3E50, fully black sclera with glowing white pupils, long silver hair, dark elegant robes, "
     "living shadows dripping and smoking from the feet",
     "night grey, black and white glow, cold low-key lighting with purple smoke"),
    ("race_15", "Guardião Rúnico", ["male runic guardian ash-forged warrior, 1.5 meters tall",
                                     "female runic guardian ash-forged warrior, 1.5 meters tall"],
     "broad basalt stone body with ember fissures, geometric steel and gold plates embedded into shoulders and chest, "
     "glowing blue runes carved into the stone skin",
     "basalt grey, steel, gold and glowing rune blue, forge light with blue rune glow"),
    ("race_16", "Titã de Obsidiana", ["male obsidian titan, 1.55 meters tall", "female obsidian titan, 1.55 meters tall"],
     "broad basalt body, short polished black volcanic glass horns on the forehead and shoulders, living incandescent "
     "lava veins running down the chest",
     "glossy obsidian black, molten lava orange-red, volcanic underlighting"),
    ("race_17", "Soberano Dracônico", ["regal male draconic sovereign", "regal female draconic sovereign"],
     "athletic body, a pair of noble horns curving backwards, red and gold dragon scale plates on shoulders and arms, "
     "thick reptilian tail, slit amber eyes, small fangs, leather and gold regalia",
     "crimson red, gold and dark leather, royal warm light"),
    ("race_18", "Fera do Frenesi", ["feral male frenzy beast warrior", "feral female frenzy beast warrior"],
     "dense bristling fur covering shoulders and back, pronounced semi-lupine snout, long claws stained crimson, wild "
     "mane, wolf ears, furry tail, ragged leather wraps",
     "dark brown fur, blood crimson stains, red rim light"),
    ("race_19", "Sylvari (Nascido da Seiva)", ["male sylvari elf of living oak", "female sylvari elf of living oak"],
     "elf-like body carved from polished living oak and roots, glowing golden amber sap veins, hair made of vines, "
     "leaves and small night-blooming flowers glowing yellow and blue, branch antlers, pointed wooden ears, moss sash",
     "warm oak brown, moss green, amber gold sap and soft blue flower glow, enchanted forest moonlight"),
    ("race_20", "Myconid / Esporiano", ["slender male myconid fungal humanoid", "slender female myconid fungal humanoid"],
     "slim body with bluish-white fungal flesh texture, a large bioluminescent purple and cyan mushroom cap on the head "
     "like a wizard hat, glowing gills, small glowing mushrooms growing on the right shoulder, mantle of mushrooms, "
     "floating spores",
     "pale blue-white, violet and cyan bioluminescence, dark sewer ambient light"),
    ("race_21", "Aracne (Tecelão da Bruma)", ["male arachne mist weaver", "female arachne mist weaver"],
     "pale greyish porcelain skin, straight black silk-like hair, six glowing red eyes (two normal and four smaller on "
     "the forehead), four sharp articulated black spider legs emerging from the shoulder blades, black and silver silk "
     "garments, silver tiara",
     "porcelain white, black, silver and glowing ruby red, misty cold light"),
    ("race_22", "Draconato de Cinzas (Escama-Negra)", ["muscular male ashen dragonborn", "muscular female ashen dragonborn"],
     "hairless reptilian humanoid with a dragon head, black obsidian horns, thick heavy tail, overlapping matte black "
     "scales with orange fire glowing between the scales of neck and chest, molten gold eyes, black scale shoulder plates",
     "matte black scales, molten orange fire glow, gold eyes, volcanic rim light"),
    ("race_23", "Quimera (O Experimento Costurado)", ["male stitched chimera experiment", "female stitched chimera experiment"],
     "Frankenstein mutant look with thick surgical stitch lines on the skin, giant hairy right arm with wolf claws, left "
     "arm covered in green scales with glowing venom tubes, one yellow beast eye and one blue human eye, single bone horn, "
     "pulsing acid sacs on the back, lizard tail",
     "patchwork skin tones, brown fur, green scales, acid green glow, harsh lab light"),
    ("race_24", "Boreal (Coração de Geada)", ["male boreal frost guardian", "female boreal frost guardian"],
     "pale ice-blue skin, spiky frost-white hair like hoarfrost, sharp translucent ice crystals #5DADE2 growing from the "
     "shoulders, forearms and as a cold crown on the forehead, white fur mantle, navy cape, breath condensing into ice crystals",
     "ice blue, frost white and navy, cold aurora light"),
    ("race_25", "Thalassiano (Filho da Maré Negra)", ["male thalassian amphibian", "female thalassian amphibian"],
     "deep navy-blue skin with smooth scales on the arms, membranous fins instead of ears and on the elbows, gills on the "
     "neck, neon-blue bioluminescent stripes along the body, large glowing eyes, pearl necklace and coral jewelry",
     "deep navy, neon blue and coral orange, underwater caustic lighting"),
    ("race_26", "Cambion (Sangue-de-Enxofre)", ["male cambion infernal hybrid", "female cambion infernal hybrid"],
     "dark red and charcoal skin, two long ringed horns curving backwards, long tail ending in a triangular spade tip, "
     "eyes of yellow fire, broken iron chains hanging from the wrists, dark spiked armor with gold trims and ember cracks",
     "charcoal, dark crimson, sulfur yellow and gold, hellfire underlighting"),
    ("race_27", "Nephilim (Híbrido do Crepúsculo)", ["male nephilim twilight hybrid", "female nephilim twilight hybrid"],
     "divine asymmetry: right side with white hair, golden eye and one white-gold angel wing; left side with black hair, "
     "abyssal purple eye and one black demon raven wing, split white-and-black robes with gold, broken half halo",
     "white and gold versus black and violet, split lighting warm on the right and cold on the left"),
    ("race_28", "Errante Temporal (Cronomante)", ["male chronomancer time wanderer", "female chronomancer time wanderer"],
     "wrapped in an astral blue and gold mantle and hood, a ring of golden roman numerals floating and slowly rotating "
     "behind the back, golden star-sand particles flowing from hands and feet, translucent afterimage slightly ahead of "
     "the body, hourglass on the belt",
     "astral indigo, gold and star-sand glow, magical golden rim light"),
    ('race_29', 'Orc', ['broad muscular male orc warrior', 'broad muscular female orc warrior'],
     'moss-green skin, prominent lower tusks, honor scars across the face, black warrior braid, bone pauldron with spikes, leather harness and fur kilt',
     'moss green, bone white and dark leather, harsh steppe daylight'),
    ('race_30', 'Goblin', ['short wiry male goblin trickster, 1.1 meters tall', 'short wiry female goblin trickster, 1.1 meters tall'],
     'lime-green skin, huge pointed ears, hooked nose, mischievous toothy grin, brown hood, belt full of pouches and shiny coins',
     'lime green, brown leather and gold coin glints, warm cave torchlight'),
    ('race_31', 'Elfo', ['slender male forest elf', 'slender female forest elf'],
     'long pointed ears, long pale-blond hair with leaf clips, forest-green tunic with leaf embroidery, carved leather bracers',
     'forest green, pale gold and soft brown, dappled forest light'),
    ('race_32', 'Elfo Solar', ['radiant male solar elf', 'radiant female solar elf'],
     'golden flowing hair, white and gold plate armor with a glowing sun disc on the chest, halo of golden rays behind the head',
     'white, gold and amber, bright solar backlight'),
    ('race_33', 'Elfo Lunar', ['pale male lunar elf', 'pale female lunar elf'],
     'silver hair down to the waist, pale skin, night-blue cloak with embroidered crescents, glowing crescent diadem',
     'night blue, silver and pale cyan, cold moonlight'),
    ('race_34', 'Drago da Terra', ['stocky male earth drago draconic humanoid', 'stocky female earth drago draconic humanoid'],
     'earth-brown scales turning into stone plates on the shoulders, thick backward horns, amber crystals growing from the spine, heavy reptilian tail',
     'earth brown, stone grey and glowing amber, dusty warm light'),
    ('race_35', 'Drago da Água', ['sleek male water drago draconic humanoid', 'sleek female water drago draconic humanoid'],
     'turquoise scales, translucent fins on forearms and head, floating water droplets orbiting the body, long tail',
     'turquoise, sea foam white and deep blue, caustic underwater light'),
    ('race_36', 'Drago do Raio', ['agile male lightning drago draconic humanoid', 'agile female lightning drago draconic humanoid'],
     'electric yellow and black scales, zigzag horns, arcs of lightning jumping between spine spikes, glowing eyes',
     'electric yellow and black, crackling white sparks, stormy backlight'),
    ('race_37', 'Drago Místico', ['mystic male drago draconic humanoid', 'mystic female drago draconic humanoid'],
     'violet scales engraved with glowing runes, crystal horns, three arcane orbs orbiting the body',
     'violet, lilac and magenta glow, arcane rim light'),
    ('race_38', 'Pyromante', ['male pyromancer human', 'female pyromancer human'],
     'tanned skin cracked by glowing ember veins, hair like living flames, scorched crimson robe, fire dancing in both hands',
     'crimson, ember orange and charcoal, fiery underlight'),
    ('race_39', 'DemiHumano Escorpião', ['male scorpionkin demi-human', 'female scorpionkin demi-human'],
     'segmented amber chitin plates on chest and arms, articulated scorpion tail curving over the head with a glowing green venom stinger, desert wraps',
     'amber, sand and toxic green, harsh desert sun'),
    ('race_40', 'DemiHumano Tartaruga', ['sturdy male tortoisekin demi-human', 'sturdy female tortoisekin demi-human'],
     'olive-green skin, huge hexagonal shell on the back, plated plastron on the chest, calm ancient eyes, simple monk wraps',
     'olive green, shell brown and cream, calm soft daylight'),
    ('race_41', 'Fadinha', ['tiny male fairy', 'tiny female fairy'],
     'pink hair in a bun, petal dress, pointed ears, four translucent crystal wings shedding sparkling dust',
     'pastel pink, crystal white and sparkling gold, dreamy glow'),
    ('race_42', 'Meio-Celestial', ['male half-celestial', 'female half-celestial'],
     'fair glowing skin, white hair, white tunic with gold trims, faint golden halo, large white feathered wings',
     'white, gold and soft yellow, heavenly backlight'),
    ('race_43', 'Gigante de Gelo', ['colossal male frost giant, 2.4 meters tall', 'colossal female frost giant, 2.4 meters tall'],
     'pale blue skin, beard and hair made of ice, white bear-fur pauldrons, ice crystals growing on shoulders and forearms, glowing frost eyes',
     'ice blue, white fur and steel grey, cold blizzard light'),
    ('race_44', 'Meio-Demônio Súcubo', ['male incubus half-demon', 'female succubus half-demon'],
     'lavender skin, curved black horns, long wine-red hair, bat wings with violet membranes, thin tail ending in a glowing heart tip, velvet corset armor',
     'lavender, wine red and deep violet, seductive magenta rim light'),
    ('race_45', 'Manamante', ['male manamancer', 'female manamancer'],
     'pale skin with glowing blue mana veins, eyes of pure mana, cobalt robe with runes, a crystal heart pulsing in the chest',
     'cobalt blue, pale white and bright mana blue, arcane glow'),
]

NPCS = [
    ("npc_100", "Garrick, o Mestre Ferreiro", "character", "stocky 50-year-old male master blacksmith with Kharad blood, 1.65 meters tall",
     "barrel-like torso, extremely muscular arms covered in old burn scars and soot, bald head, long thick beard braided "
     "into three tips held by bronze rings with slightly singed ends, thick eyebrows, grumpy but honorable face, heavy "
     "charred bison-leather apron #4A2E1B over a dark sleeveless linen shirt, single beaten-iron plate pauldron on the "
     "left shoulder, thick leather-and-metal gloves to the elbows, steel-toed boots, wide belt with blacksmith tongs, "
     "iron chains and a greasy rag",
     "brown leather, soot black, bronze and forge-orange glow, warm forge light"),
    ("npc_103", "Lyra, a Mestra Alquimista", "character", "elegant 24-year-old female master alchemist, half Valerian half Noctari, 1.70 meters tall",
     "fine features, messy silver-lavender bun pierced by two glass alchemical rods, round brass goggles with green lenses "
     "resting on the forehead, expressive green eyes, asymmetric amethyst medieval tunic #5B2C6F with golden borders, light "
     "leather vest stained with glowing blue and green splashes, thin dark leather gloves, chest bandolier with five small "
     "glowing test tubes, dried herb pouch and recipe book at the hip",
     "amethyst purple, gold, light leather, glowing green #2ECC71 and blue #00D2FF, soft alchemy lab light"),
    ("npc_104", "Varis, o Contrabandista do Beco Sombrio", "character", "tall slender 35-year-old male smuggler, 1.80 meters tall",
     "slightly hunched forward posture, deep black leather hood covering the upper face, dark crimson cloth mask #641E16 "
     "over the lower face, only glowing yellow eyes #F1C40F visible in the hood shadow, worn black leather overcoat #17202A "
     "with sewer-mud stained hem, layered leather shoulder pads like raven feathers, soft dark suede boots, coat slightly "
     "open revealing rows of purple poison vials, master keys and coin pouches, two curved daggers at the waist",
     "black leather, crimson, poison purple and yellow eye glow, dim alley lighting"),
    ("npc_105", "Capitão Randel", "character", "imposing 45-year-old male guard captain, 1.85 meters tall",
     "military posture, full polished steel plate armor #BDC3C7 with golden trims #D4AC0D, breastplate engraved with a "
     "broken sun symbol, long royal-blue cape #1B4F72, no helmet, veteran face with short grey beard and a scar on the cheek",
     "polished steel, gold and royal blue, noble daylight with cool rim"),
    ("npc_106", "Guarda Valen", "character", "30-year-old male village patrol guard",
     "lighter infantry armor for walking: chainmail under a simple steel breastplate and navy-blue gambeson, closed "
     "bascinet-style helmet with visor slit, iron lantern with warm yellow light hanging from the belt for the night patrol",
     "steel grey, navy blue and warm lantern yellow, night patrol lighting"),
    ("npc_107", "Alquimista Fantasma dos Esgotos", "character", "elderly hunched male alchemist ghost",
     "no lower legs: the torn robe dissolves into ectoplasmic smoke above the ground, entire body translucent and emissive "
     "ghostly green #48C9B0, broken rusty iron chains on the wrists, holding a cracked smoking censer",
     "translucent ghost teal-green, rusty brown, eerie sewer glow at 3 AM"),
]

MOBS = [
    ("mob_1", "Lobo da Bruma", "creature", "agile grey mist wolf",
     "lean quadruped body, long snout, glowing red eyes, thick layered grey fur with individual strands and tufts, mist "
     "curling around the paws, scarred ears",
     "cold grey-blue fur, red eyes, foggy forest moonlight"),
    ("mob_2", "Saqueador Deserdado", "biped_creature", "disinherited raider bandit",
     "rust-red patched leather armor, dented round iron shield with spikes on the left arm, notched short sword, cloth "
     "bandana and scarf, belts and pouches, scarred face",
     "rust red, worn leather brown and dull iron, harsh daylight"),
    ("mob_3", "Besteiro da Vigília", "biped_creature", "watchtower crossbowman",
     "hunter-green padded gambeson with leather bracers, hooded cowl, heavy wooden crossbow with iron limbs held forward, "
     "bolt quiver on the hip",
     "hunter green, brown wood and iron, overcast light"),
    ("mob_4", "Acólito do Eclipse", "biped_creature", "eclipse cult acolyte",
     "dark purple hooded robes with occult embroidery, dark twisted staff topped with a floating shadow orb, pale face "
     "hidden in the hood, ritual tattoos",
     "deep purple, black and glowing violet orb, ritual candle light"),
    ("mob_5", "Executor de Ferro", "biped_creature", "massive iron executioner brute, 1.4 times human size",
     "hulking body in black iron plate armor, huge heavy shoulder plates, closed bucket helm with slits, colossal "
     "flanged iron mace, chains and leather straps, executioner hood under the helm",
     "black iron, dark leather and dull red cloth, grim low light"),
    ("mob_6", "Lobo Alfa", "creature", "large silver alpha wolf, 1.45 times a normal wolf",
     "majestic quadruped with shining silver fur, thick mane of layered fur around the neck, pronounced snout, tall ears, "
     "glowing golden eyes, faint blue lunar glow in the fur tips",
     "silver white fur, golden eyes, blue moonlight glow"),
    ("mob_7", "Licantropo Alfa", "biped_creature", "colossal alpha werewolf raid boss",
     "bipedal giant with broad shoulders covered in muscular spikes, black-crimson bristling fur, elongated wolf snout with "
     "sharp fangs, blood-red glowing eyes, very long claws on both hands, torn chains",
     "black and crimson fur, blood moon red glow, dramatic red backlight"),
    ("mob_10", "Cultista Sombrio", "biped_creature", "shadow cultist",
     "dark violet tattered robes and deep hood, floating orb of darkness, bone charms and ritual daggers on the belt, "
     "smoke trailing from the robe hem",
     "dark violet, black, bone white, eerie purple glow"),
    ("mob_11", "Gárgula de Pedra", "biped_creature", "stone gargoyle",
     "hunched grey stone body with cracks and moss, large bat-like rock wings with stone membranes and finger bones, "
     "horned demonic head, glowing amber eyes, clawed feet",
     "grey stone, green moss and amber eyes, gothic overcast light"),
    ("mob_12", "Inquisidor Vex", "biped_creature", "inquisitor Vex mini-boss",
     "tall gaunt figure in crimson and black inquisitor robes with high collar, iron mask, long dark scythe with glowing "
     "crimson blade, chains and holy seals",
     "crimson, black and glowing blood red, cathedral shadows"),
    ("mob_13", "Comandante Vaelen, o Traidor", "biped_creature", "traitor commander Vaelen boss",
     "full dark steel plate armor with golden pauldrons, torn royal cape, broad greatsword, defaced knightly crest, "
     "grim scarred face",
     "dark steel, gold and torn blue, cold battlefield light"),
    ("mob_14", "Malakor, o Arauto do Eclipse", "biped_creature", "colossal Malakor, herald of the eclipse raid boss",
     "giant abyssal being 2.2 times human size, void-black body with purple eclipse aura, huge primordial shadow wings with "
     "feathered and membranous layers, primordial eclipse scythe with glowing violet blade, crown of dark horns",
     "void black, radiant eclipse purple and violet, total eclipse corona backlight"),
]

ITEMS = [
    ("weapon_iron_dagger", "Adaga Curta de Ferro", "short iron dagger", "simple forged iron blade with fuller, leather-wrapped grip, round pommel, small crossguard", "dark iron and brown leather, neutral studio light"),
    ("weapon_wooden_staff", "Bastão de Madeira Simples", "simple wooden staff", "straight ash wood staff with knot at the top and cord wrap in the middle", "natural wood brown, neutral studio light"),
    ("weapon_knight_longsword", "Espada Longa de Cavaleiro", "1.1-meter knight longsword", "polished steel blade with central fuller, cross guard with gold end caps, leather grip, gold pommel, engraved runes", "polished steel, gold and leather, cool blue glint"),
    ("weapon_heater_shield", "Escudo Triangular (Heater)", "medieval heater shield", "painted blue wood face with steel rim, broken sun emblem in gold, rivets, leather straps on the back", "royal blue, steel and gold, soft studio light"),
    ("weapon_recurve_bow", "Arco Recurvo de Madeira e Ouro", "recurve bow of wood and gold", "elegant curved limbs of dark wood with gold tips and rings, leather grip, taut string", "dark wood, gold and leather, warm light"),
    ("weapon_steel_arrow", "Flecha de Ponta de Aço", "steel-tipped arrow", "straight wooden shaft, sharp steel broadhead, green feather fletching", "wood, steel and forest green, neutral light"),
    ("weapon_crystal_staff", "Cajado de Cristal Arcano", "1.7-meter arcane crystal staff", "twisted black wood shaft whose top branches cradle a floating blue crystal, gold rings", "black wood, gold and glowing arcane blue, magical glow"),
    ("weapon_holy_mace", "Maça Sagrada Dourada", "golden holy flanged mace", "six-flanged golden head with sun engravings, white-wrapped grip, spike tip", "gold and ivory, holy warm light"),
    ("weapon_solar_talisman", "Talismã / Orbe Solar", "floating solar talisman orb", "radiant sun orb inside a rotating golden ring with ray spikes", "gold and radiant sunlight, bloom glow"),
    ("weapon_forge_warhammer", "Martelo de Forja de Guerra", "colossal two-handed forge warhammer", "square black iron head with glowing orange ember fissures, iron bands, long ash handle", "black iron, ember orange glow, forge light"),
    ("weapon_alchemy_flask", "Frasco Esférico Alquímico", "spherical alchemy flask", "round glass flask with cork filled with glowing green and purple liquid and bubbles", "clear glass, glowing green and purple, lab light"),
    ("weapon_injector_gauntlet", "Manopla Injetora de Latão", "brass injector gauntlet", "brass bracer with glass tubes of glowing reagent, needle injector at the knuckles, leather glove", "brass, leather and glowing green, workshop light"),
    ("weapon_eclipse_scythe", "Foice Colossal do Eclipse", "2-meter colossal eclipse scythe", "twisted black haft, huge curved black blade with glowing blood-red edge, raven skull and crimson wrap", "black, blood red glow, dark fantasy light"),
    ("weapon_hammer_cannon", "Martelo-Canhão Rúnico", "runic hammer-cannon", "heavy bronze sledge front, rear runic turbine glowing blue, central firing barrel, iron handle", "bronze, iron and glowing rune blue, steampunk light"),
    ("weapon_philosopher_chalice", "Cálice da Pedra Filosofal", "philosopher's stone chalice", "ornate golden chalice holding a floating crimson philosopher's stone emitting red rays", "gold and glowing crimson, mystical light"),
    ("weapon_hunting_knife", "Faca de Caça (Autópsia)", "hunting and autopsy knife", "curved steel skinning blade, bone handle, small guard", "steel and bone, neutral light"),
    ("companion_homunculus", "Mini-Homúnculo", "50-centimeter floating homunculus creature", "small being of red crystal and shadows, glowing eyes, floating crystal shards", "red crystal and black shadow, crimson glow"),
]

OUTFITS = [
    ("outfit_traveler", "Viajante", "loose beige linen shirt tied with a rope belt, simple brown leather trousers, worn travel boots", "beige, brown leather"),
    ("outfit_swordsman", "Espadachim", "steel breastplate over chainmail, symmetrical steel pauldrons, blue and white tabard at the waist", "steel, blue and white"),
    ("outfit_scout", "Batedor", "light forest-green and brown leather coat, hood thrown back on the shoulders, archer gloves, arrow quiver on the back", "forest green and brown"),
    ("outfit_initiate", "Iniciado", "long night-blue mage robe with gold embroidery, short shoulder mantle, belt with an open grimoire on a chain", "night blue and gold"),
    ("outfit_acolyte", "Acólito", "immaculate white clerical robes with gold plates on chest and shoulders, long stole with sun and moon symbols", "white and gold"),
    ("outfit_blacksmith", "Ferreiro", "heavy reinforced leather chestpiece with riveted iron plates, heavy mechanical bracer on the right arm, tool belt", "brown leather and iron"),
    ("outfit_alchemist", "Alquimista", "long acid-resistant dark brown leather coat, bandolier full of glowing potions, backpack with a bubbling green glass tank", "dark brown, glowing green"),
    ("outfit_reaper", "Ceifador do Eclipse", "torn black dark-hunter cloak, raven skull pauldrons, crimson details", "black and crimson"),
    ("outfit_artificer", "Artífice Rúnico", "heavy steampunk-runic bronze armor, glowing pressure tubes on the back, runic monocle", "bronze and glowing blue"),
    ("outfit_homunculus_creator", "Criador de Homúnculos", "royal supreme alchemist suit in black, gold and crimson, high collar, short crimson cape", "black, gold and crimson"),
]


CLASS_EN = {
    "outfit_traveler": "Traveler", "outfit_swordsman": "Swordsman", "outfit_scout": "Scout",
    "outfit_initiate": "Arcane Initiate", "outfit_acolyte": "Acolyte priest", "outfit_blacksmith": "Battle Blacksmith",
    "outfit_alchemist": "Combat Alchemist", "outfit_reaper": "Eclipse Reaper", "outfit_artificer": "Runic Artificer",
    "outfit_homunculus_creator": "Homunculus Creator",
}


def build_entries():
    entries = []
    for uid, name, subjects, details, colors in RACES:
        for gender, subject in zip(("masculino", "feminino"), subjects):
            suffix = "_m" if gender == "masculino" else "_f"
            entries.append({"uid": uid + suffix, "base_uid": uid, "group": "Raças", "name": "%s (%s)" % (name, gender),
                            "prompt": render("character", subject, details, colors)})
    for uid, name, kind, subject, details, colors in NPCS:
        hands = "holding only the items described" if uid == "npc_107" else "no extra clutter in hands unless specified"
        entries.append({"uid": uid, "base_uid": uid, "group": "NPCs", "name": name,
                        "prompt": render(kind, subject, details, colors, hands)})
    for uid, name, kind, subject, details, colors in MOBS:
        entries.append({"uid": uid, "base_uid": uid, "group": "Criaturas", "name": name,
                        "prompt": render(kind, subject, details, colors, "holding only the weapons described")})
    for uid, name, subject, details, colors in ITEMS:
        entries.append({"uid": uid, "base_uid": uid, "group": "Armas e itens", "name": name,
                        "prompt": render("item", subject, details, colors, "no hands, the object alone, pivot at the grip")})
    for uid, name, details, colors in OUTFITS:
        subject = "a neutral athletic human mannequin wearing the %s class outfit" % CLASS_EN[uid]
        entries.append({"uid": uid, "base_uid": uid, "group": "Trajes de classe", "name": name,
                        "prompt": render("outfit", subject, details + ", bald featureless head so only the clothing matters",
                                         colors + ", neutral studio light", "empty hands")})
    return entries


def main():
    entries = build_entries()
    os.makedirs(os.path.dirname(OUT_MD), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, indent=1)
    lines = ["# Prompts de geração 3D — Lunaria", "",
             "Gerado por `tools/art_prompts/prompts.py`. Cada prompt segue o modelo de arte do projeto",
             "(anime heroico inspirado em Sword Art Online / Fate, cel-shading, render Unreal Engine 5).", "",
             "Arquivo esperado pelo jogo: `client/assets/models/hd/<arquivo>.glb` (ver `docs/art/README.md`).", ""]
    group = None
    for e in entries:
        if e["group"] != group:
            group = e["group"]
            lines += ["## " + group, ""]
        lines += ["### %s" % e["name"], "", "Arquivo: `%s.glb`" % e["uid"], "", "```text", e["prompt"], "```", ""]
    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    if os.path.exists(HTML_TEMPLATE):
        with open(HTML_TEMPLATE, encoding="utf-8") as f:
            html = f.read().replace("/*__PROMPTS__*/null", json.dumps(entries, ensure_ascii=False))
        with open(OUT_HTML, "w", encoding="utf-8") as f:
            f.write(html)
    counts = {}
    for e in entries:
        counts[e["group"]] = counts.get(e["group"], 0) + 1
    print("Prompts:", ", ".join("%s=%d" % kv for kv in counts.items()), "| total", len(entries))


if __name__ == "__main__":
    main()
