# Gera server/internal/world/fauna_data.go — tabela única das 140 espécies (10 por região).
# (nome, corpo, temperamento, vida, dano, velocidade, escala, massa_kg, cor, aquática, grupo, couro)
Z = {}
Z["ZoneVillage"] = [
 ("Coelho-do-Campo","quad","P",30,0,4.4,0.35,2.5,"#b49a7a",0,4,"lobo"),
 ("Raposa Vermelha","quad","N",90,9,4.6,0.6,7,"#c8562a",0,2,"lobo"),
 ("Cervo-Galheiro","quad","P",220,14,5.0,1.25,140,"#8a6240",0,3,"javali"),
 ("Ouriço-Cacheiro","quad","P",25,3,1.6,0.3,1.2,"#6b5a48",0,2,"osso"),
 ("Texugo-das-Tocas","quad","T",130,12,3.2,0.55,12,"#5b5b5b",0,2,"pelo"),
 ("Pombo-Torcaz","bird","P",20,0,4.0,0.35,0.5,"#9aa3ad",0,5,"penas"),
 ("Corvo-Carniceiro","bird","N",35,5,4.2,0.4,1.2,"#1d1d24",0,3,"penas"),
 ("Cobra-d'Água","serpent","T",70,10,2.6,0.6,2,"#4d6b3a",0,2,"escamas"),
 ("Lontra-do-Rio","amphibian","N",95,8,3.4,0.6,9,"#6a4a32",1,2,"pelo"),
 ("Truta Prateada","fish","P",22,0,3.0,0.45,2,"#b8c6d0",1,5,"escamas"),
]
Z["ZoneForest"] = [
 ("Urso-Pardo do Bosque","quad","T",700,38,4.0,1.8,320,"#5a3d26",0,1,"pelo"),
 ("Lince Cinzento","quad","A",240,22,5.2,0.8,22,"#8a8478",0,2,"lobo"),
 ("Alce-Real","quad","N",520,30,4.4,1.7,450,"#6b4a30",0,2,"javali"),
 ("Esquilo-Ruivo","quad","P",15,0,4.8,0.25,0.4,"#b5541e",0,4,"lobo"),
 ("Coruja-das-Torres","bird","P",40,4,4.2,0.5,0.6,"#cdb38a",0,2,"penas"),
 ("Pica-Pau-Verde","bird","P",18,0,4.0,0.3,0.2,"#4f8a3a",0,3,"penas"),
 ("Víbora-do-Musgo","serpent","A",90,16,2.8,0.6,1.5,"#3d5a2a",0,2,"escamas"),
 ("Besouro-Chifrudo","insect","N",110,10,2.2,0.6,1.5,"#2b1d12",0,3,"quitina"),
 ("Castor-Construtor","amphibian","P",120,8,2.6,0.7,25,"#6a4426",1,2,"pelo"),
 ("Salmão-do-Bosque","fish","P",35,0,3.4,0.6,5,"#d07a5a",1,5,"escamas"),
]
Z["ZoneSparseWoods"] = [
 ("Javali-Malhado","quad","T",170,16,3.8,0.95,85,"#5a4630",0,3,"javali"),
 ("Corça-Ligeira","quad","P",140,8,5.4,1.0,60,"#a5784a",0,3,"lobo"),
 ("Lebre-Saltadora","quad","P",28,0,5.0,0.38,3,"#a59070",0,4,"lobo"),
 ("Furão-Selvagem","quad","N",60,8,4.6,0.4,1.5,"#4a3a2a",0,2,"lobo"),
 ("Gavião-Caçador","bird","N",60,10,5.0,0.55,1.4,"#7a5a3a",0,2,"penas"),
 ("Perdiz-Cinzenta","bird","P",22,0,3.6,0.35,0.5,"#8a7f6a",0,4,"penas"),
 ("Cobra-Coral","serpent","T",60,18,2.8,0.5,0.8,"#c43a2a",0,2,"escamas"),
 ("Aranha-Lobo","spider","A",120,14,3.6,0.6,0.8,"#4a3a30",0,3,"teia"),
 ("Sapo-Cururu","amphibian","P",40,4,2.0,0.4,1.2,"#6a6a32",1,3,"pele"),
 ("Carpa-Dourada","fish","P",30,0,2.8,0.55,4,"#d8a032",1,5,"escamas"),
]
Z["ZoneGrasslands"] = [
 ("Bisão-das-Planícies","quad","N",900,40,4.0,1.9,700,"#4a3424",0,4,"pelo"),
 ("Cavalo-Selvagem","quad","P",380,20,6.0,1.5,420,"#8a5a3a",0,4,"javali"),
 ("Coiote-Uivante","quad","A",160,14,5.0,0.7,14,"#a5865a",0,3,"lobo"),
 ("Marmota-da-Pradaria","quad","P",30,0,3.8,0.35,4,"#9a7a52",0,4,"lobo"),
 ("Abetarda-Real","bird","P",70,4,4.4,0.8,12,"#b8a07a",0,3,"penas"),
 ("Falcão-Peregrino","bird","N",55,12,6.0,0.5,1,"#6a6a72",0,2,"penas"),
 ("Cascavel-do-Capim","serpent","T",80,20,3.0,0.65,2,"#a58a5a",0,2,"escamas"),
 ("Gafanhoto-Gigante","insect","N",50,6,4.0,0.5,0.6,"#7a9a3a",0,4,"quitina"),
 ("Garça-Branca","bird","P",45,4,3.8,0.8,2,"#eeeeea",1,3,"penas"),
 ("Bagre-Barbudo","fish","P",45,0,2.6,0.7,8,"#6a6a5a",1,4,"escamas"),
]
Z["ZoneSavanna"] = [
 ("Leão-Dourado","quad","A",900,48,5.4,1.6,190,"#c89a4a",0,3,"pelo"),
 ("Zebra-Listrada","quad","P",320,18,5.8,1.4,320,"#e6e6e6",0,5,"javali"),
 ("Girafa-Manchada","quad","P",800,26,4.6,2.6,1100,"#d8a85a",0,2,"javali"),
 ("Hiena-Risonha","quad","A",260,22,5.0,0.9,55,"#8a7a5a",0,4,"lobo"),
 ("Elefante-da-Savana","quad","T",2600,70,3.6,3.2,5000,"#7a7a7a",0,2,"pelo"),
 ("Abutre-Calvo","bird","P",70,6,4.4,0.8,8,"#4a3a32",0,3,"penas"),
 ("Avestruz","bird","N",260,20,6.2,1.5,110,"#3a3230",0,3,"penas"),
 ("Escorpião-Amarelo","spider","A",110,18,3.2,0.5,0.4,"#c8a032",0,3,"quitina"),
 ("Hipopótamo-do-Lago","amphibian","T",1800,60,3.4,2.4,1800,"#7a6a7a",1,2,"pele"),
 ("Crocodilo-do-Lago","reptile","A",1100,55,3.6,2.0,500,"#4a5a32",1,2,"escamas"),
]
Z["ZoneSaltDesert"] = [
 ("Camelo-do-Sal","quad","P",600,24,4.0,2.0,600,"#c8a06a",0,3,"pelo"),
 ("Raposa-do-Deserto","quad","N",70,8,5.2,0.45,1.5,"#e0c08a",0,2,"lobo"),
 ("Lagarto-de-Chifres","reptile","N",90,10,3.4,0.5,0.5,"#b08a5a",0,3,"escamas"),
 ("Escaravelho-de-Sal","insect","P",40,4,2.4,0.45,0.3,"#3a6a7a",0,4,"quitina"),
 ("Escorpião-Pálido","spider","A",160,24,3.4,0.6,0.5,"#e8dcc0",0,3,"quitina"),
 ("Serpente-das-Dunas","serpent","A",140,26,3.6,0.9,6,"#d8b880","0",2,"escamas"),
 ("Abutre-das-Salinas","bird","P",65,6,4.4,0.8,7,"#8a7a6a",0,3,"penas"),
 ("Gerbo-Saltador","quad","P",18,0,5.2,0.25,0.1,"#d8b88a",0,4,"lobo"),
 ("Tartaruga-do-Sal","reptile","P",300,10,1.2,0.9,40,"#8a7a5a",0,2,"osso"),
 ("Verme-de-Areia","serpent","T",900,45,3.0,2.2,900,"#c8a87a",0,1,"pele"),
]
Z["ZoneWindPlateau"] = [
 ("Cabra-Montesa","quad","N",180,16,4.4,0.9,80,"#d8d0c0",0,4,"pelo"),
 ("Lobo-dos-Ventos","quad","A",260,22,5.2,0.95,45,"#9aa0a8",0,3,"lobo"),
 ("Águia-Real","bird","N",90,16,6.4,0.8,6,"#5a3a22",0,2,"penas"),
 ("Marmota-das-Rochas","quad","P",35,0,3.6,0.4,5,"#8a7050",0,4,"lobo"),
 ("Carneiro-Selvagem","quad","T",260,24,4.2,1.1,120,"#c8b89a",0,3,"pelo"),
 ("Andorinha-das-Escarpas","bird","P",14,0,5.4,0.25,0.1,"#2a3a5a",0,5,"penas"),
 ("Lagarto-das-Pedras","reptile","P",45,4,3.6,0.4,0.6,"#7a7a6a",0,3,"escamas"),
 ("Grilo-do-Vento","insect","P",15,0,3.4,0.3,0.1,"#6a5a3a",0,4,"quitina"),
 ("Martim-Pescador","bird","P",16,0,5.0,0.3,0.2,"#2a8ab8",1,3,"penas"),
 ("Truta-das-Corredeiras","fish","P",28,0,3.6,0.5,3,"#9ab0b8",1,5,"escamas"),
]
Z["ZoneRuins"] = [
 ("Rato-das-Ruínas","quad","N",35,5,4.2,0.3,0.5,"#5a5048",0,5,"lobo"),
 ("Morcego-das-Criptas","bird","N",30,6,5.0,0.35,0.3,"#2a2228","0",5,"pele"),
 ("Gato-Selvagem","quad","N",90,12,5.0,0.5,5,"#7a6a5a",0,2,"lobo"),
 ("Lobo-Cinzento do Norte","quad","A",300,26,5.0,1.0,55,"#b0b4b8",0,3,"pelo"),
 ("Coruja-das-Neves","bird","P",45,6,4.4,0.55,2,"#f0f0f2",0,2,"penas"),
 ("Raposa-Ártica","quad","N",80,10,5.0,0.5,4,"#f4f4f4",0,2,"pelo"),
 ("Centopeia-Gigante","insect","A",150,18,3.6,0.8,2,"#7a3a2a",0,2,"quitina"),
 ("Aranha-das-Muralhas","spider","A",140,16,3.4,0.6,1,"#3a3a3a",0,3,"teia"),
 ("Arminho","quad","P",22,0,5.0,0.28,0.3,"#e8e2d8",0,3,"pelo"),
 ("Lúcio-Gelado","fish","N",40,8,3.6,0.7,6,"#8aa0a0",1,4,"escamas"),
]
Z["ZoneFrozenPeaks"] = [
 ("Urso-Polar","quad","A",1100,55,4.4,2.0,500,"#f2f2ee",0,2,"pelo"),
 ("Iaque-das-Neves","quad","N",700,34,3.4,1.8,600,"#4a3a32",0,3,"pelo"),
 ("Leopardo-das-Neves","quad","A",380,32,5.6,1.0,50,"#e8e4dc",0,2,"pelo"),
 ("Lebre-Alpina","quad","P",30,0,5.0,0.4,4,"#f4f4f4",0,4,"pelo"),
 ("Bode-Glacial","quad","T",300,26,4.2,1.1,110,"#d8d8d8",0,3,"pelo"),
 ("Águia-das-Geleiras","bird","N",100,18,6.4,0.85,7,"#d8d8e0",0,2,"penas"),
 ("Pinguim-dos-Picos","bird","P",60,4,1.8,0.6,25,"#1a1a22",1,4,"penas"),
 ("Verme-de-Gelo","serpent","T",200,20,2.4,0.9,8,"#b0d8f0",0,2,"pele"),
 ("Foca-do-Lago Glacial","amphibian","P",260,10,2.6,1.3,130,"#8a8a92",1,3,"pele"),
 ("Peixe-Gelo","fish","P",30,0,3.0,0.45,1.5,"#d0e8f4",1,5,"escamas"),
]
Z["ZoneBasaltHills"] = [
 ("Javali-de-Basalto","quad","T",260,22,3.8,1.05,120,"#3a3230",0,3,"javali"),
 ("Lagarto-de-Lava","reptile","A",220,24,3.6,0.8,15,"#c8502a",0,3,"escamas"),
 ("Cabra-das-Cinzas","quad","N",170,14,4.4,0.9,70,"#6a6060",0,3,"pelo"),
 ("Falcão-de-Fogo","bird","N",70,14,6.0,0.55,1.2,"#c8642a",0,2,"penas"),
 ("Escorpião-de-Obsidiana","spider","A",260,28,3.2,0.8,2,"#1a1418",0,2,"quitina"),
 ("Toupeira-Gigante","quad","P",120,8,2.2,0.7,20,"#4a3a32",0,3,"pelo"),
 ("Cobra-de-Cinzas","serpent","A",110,20,3.0,0.7,3,"#5a5250","0",2,"escamas"),
 ("Besouro-Bombardeiro","insect","N",80,14,2.4,0.5,0.4,"#3a5a2a",0,4,"quitina"),
 ("Morcego-das-Fendas","bird","N",30,6,5.0,0.35,0.3,"#2a2020",0,5,"pele"),
 ("Salamandra-de-Basalto","amphibian","N",90,10,2.4,0.5,1,"#8a2a1a",0,3,"pele"),
]
Z["ZoneAshFrontier"] = [
 ("Salamandra-Ígnea","amphibian","A",240,26,3.2,0.8,4,"#e8602a",0,3,"pele"),
 ("Cão-das-Cinzas","quad","A",320,28,5.2,0.95,40,"#3a2a2a",0,4,"pelo"),
 ("Fênix-Menor","bird","N",200,24,6.0,0.9,5,"#f0902a",0,2,"penas"),
 ("Lagarto-Brasa","reptile","T",280,26,3.6,0.9,20,"#a03a1a",0,3,"escamas"),
 ("Besouro-de-Magma","insect","N",160,16,2.4,0.7,2,"#5a1a12",0,4,"quitina"),
 ("Aranha-de-Cinzas","spider","A",210,22,3.6,0.8,1.5,"#4a4040",0,3,"teia"),
 ("Abutre-de-Fuligem","bird","P",80,6,4.4,0.85,8,"#2a2222","0",3,"penas"),
 ("Serpente-de-Enxofre","serpent","A",230,30,3.2,1.1,10,"#d8c83a",0,2,"escamas"),
 ("Javali-Infernal","quad","T",420,34,4.0,1.2,180,"#5a1a12",0,3,"javali"),
 ("Tatu-de-Obsidiana","quad","P",260,10,2.6,0.8,30,"#2a2228",0,2,"osso"),
]
Z["ZoneSanctuary"] = [
 ("Mariposa-do-Eclipse","insect","P",30,0,3.4,0.6,0.2,"#7a4ab8",0,5,"quitina"),
 ("Corvo-Sombrio","bird","N",50,8,4.4,0.45,1.3,"#1a1222",0,4,"penas"),
 ("Cervo-Espectral","quad","P",300,16,5.4,1.3,150,"#c8c8f0",0,2,"javali"),
 ("Lobo-Sombra","quad","A",340,30,5.4,1.0,50,"#2a2238","0",3,"pelo"),
 ("Morcego-Vampiro","bird","A",60,10,5.2,0.4,0.4,"#3a1a22",0,5,"pele"),
 ("Aranha-do-Crepúsculo","spider","A",220,22,3.6,0.8,1.5,"#4a2a5a",0,3,"teia"),
 ("Serpente-Lunar","serpent","T",200,22,3.0,1.0,8,"#c8d0f0",0,2,"escamas"),
 ("Gato-das-Sombras","quad","N",140,16,5.6,0.55,6,"#1a1a24",0,2,"pelo"),
 ("Coruja-Fantasma","bird","P",55,6,4.6,0.6,1,"#e8e8f8",0,2,"penas"),
 ("Sapo-de-Névoa","amphibian","P",45,4,2.2,0.45,1,"#6a7aa0",0,3,"pele"),
]
Z["ZoneMistMarsh"] = [
 ("Crocodilo-do-Brejo","reptile","A",1000,52,3.4,1.9,450,"#3a4a2a",1,2,"escamas"),
 ("Sapo-Gigante do Pântano","amphibian","N",220,18,2.6,0.9,15,"#4a6a2a",1,3,"pele"),
 ("Garça-Azul","bird","P",50,4,3.8,0.8,2.5,"#6a8ab0",1,3,"penas"),
 ("Sanguessuga-Gigante","serpent","A",90,10,2.0,0.6,1,"#3a2a22",1,3,"pele"),
 ("Mosquito-Pestilento","insect","A",20,4,4.6,0.35,0.05,"#5a5a3a",0,5,"quitina"),
 ("Cobra-do-Lodo","serpent","A",150,22,2.8,0.9,5,"#4a5a32",0,2,"escamas"),
 ("Tartaruga-Mordedora","reptile","T",380,30,1.6,1.0,60,"#4a4a32",1,2,"osso"),
 ("Javali-do-Brejo","quad","T",200,18,3.6,1.0,95,"#3a3228",0,3,"javali"),
 ("Enguia-Elétrica","fish","T",120,18,3.4,0.9,15,"#3a4a5a",1,3,"escamas"),
 ("Libélula-Gigante","insect","P",25,0,5.4,0.5,0.1,"#3ab8a0",0,4,"quitina"),
]
Z["ZoneAncientSewers"] = [
 ("Ratazana-dos-Esgotos","quad","A",60,8,4.6,0.45,1.2,"#4a4038",0,5,"lobo"),
 ("Barata-Gigante","insect","N",50,6,4.0,0.45,0.2,"#5a3a1a",0,5,"quitina"),
 ("Crocodilo-Albino","reptile","A",900,48,3.4,1.8,400,"#e8e0d0",1,1,"escamas"),
 ("Morcego-dos-Túneis","bird","N",28,5,5.0,0.35,0.3,"#2a2220",0,5,"pele"),
 ("Centopeia-dos-Canos","insect","A",130,16,3.6,0.8,1.5,"#6a3a22",0,3,"quitina"),
 ("Aranha-das-Galerias","spider","A",150,18,3.6,0.7,1,"#2a2a22",0,3,"teia"),
 ("Sanguessuga-dos-Esgotos","serpent","N",70,8,2.0,0.5,0.6,"#3a3a22",1,3,"pele"),
 ("Sapo-Tóxico","amphibian","N",50,10,2.2,0.45,0.8,"#6ab83a",0,3,"pele"),
 ("Enguia-de-Lodo","fish","N",80,10,3.0,0.8,6,"#4a4a32",1,3,"escamas"),
 ("Caranguejo-de-Esgoto","crab","T",180,16,2.2,0.7,4,"#8a5a3a",0,3,"osso"),
]
# Rio só corre na coluna central: aquáticos fora dela vivem nos brejos/canais (lagoas da zona)
RIVER = {"ZoneVillage","ZoneForest","ZoneSparseWoods","ZoneGrasslands","ZoneSavanna","ZoneWindPlateau","ZoneRuins","ZoneFrozenPeaks"}
BODY = {"quad":"FaunaQuadruped","bird":"FaunaBird","serpent":"FaunaSerpent","insect":"FaunaInsect","spider":"FaunaArachnid",
        "fish":"FaunaFish","amphibian":"FaunaAmphibian","reptile":"FaunaReptile","crab":"FaunaCrab"}
TEMP = {"P":"TemperPassive","N":"TemperNeutral","A":"TemperAggressive","T":"TemperTerritorial"}
HIDE = {"lobo":"MatWolfLeather","javali":"MatBoarLeather","pelo":"MatThickFur","escamas":"MatScales","penas":"MatFeathers",
        "quitina":"MatScorpionChitin","teia":"MatSpiderWeb","osso":"MatBones","pele":"MatRawHide"}
out = ["// ARQUIVO GERADO por tools/gen_fauna.py — não edite à mão (edite a tabela no script).", "package world", "",
       "// FaunaCatalog: 10 espécies por região aberta (tipos de mob 100 a 239).", "var FaunaCatalog = []FaunaDef{"]
t = 100
for zone, lst in Z.items():
    assert len(lst) == 10, zone
    for (n, b, tp, hp, dmg, sp, sz, mass, col, aq, cnt, hide) in lst:
        aq = int(aq)
        if aq and zone not in RIVER:
            aq = 2  # 2 = vive nas águas paradas (lagoas/canais) da zona
        out.append('\t{%d, %s, "%s", %s, %s, %d, %d, %.1f, %.2f, %.1f, "%s", %d, %d, %s},' % (
            t, zone, n, BODY[b], TEMP[tp], hp, dmg, sp, sz, mass, col, aq, cnt, HIDE[hide]))
        t += 1
out.append("}")
print("\n".join(out))
