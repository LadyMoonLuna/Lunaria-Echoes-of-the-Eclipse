extends CanvasLayer

var is_open: bool = false
var current_npc_id: int = 0
var current_npc_name: String = ""
var view_mode: String = "main" # "main" ou "trade"
const ClassPaths = preload("res://scripts/ClassPaths.gd")

static func get_hearts_string(points: int) -> String:
	if points >= 100:
		return "❤️❤️❤️❤️❤️"
	elif points >= 80:
		return "❤️❤️❤️❤️♡"
	elif points >= 60:
		return "❤️❤️❤️♡♡"
	elif points >= 40:
		return "❤️❤️♡♡♡"
	elif points >= 20:
		return "❤️♡♡♡♡"
	else:
		return "♡♡♡♡♡"

static func get_hearts_level_text(points: int) -> String:
	if points >= 100:
		return "❤️❤️❤️❤️❤️ (Nível Máximo: Alma Irmã — 20% Desconto + Receitas Secretas)"
	elif points >= 80:
		return "❤️❤️❤️❤️♡ (Nível 5: Leal — 15% Desconto)"
	elif points >= 60:
		return "❤️❤️❤️♡♡ (Nível 4: Confidente — 10% Desconto + Segredos)"
	elif points >= 40:
		return "❤️❤️♡♡♡ (Nível 3: Amigo — 5% Desconto)"
	elif points >= 20:
		return "❤️♡♡♡♡ (Nível 2: Conhecido)"
	else:
		return "♡♡♡♡♡ (Nível 1: Desconhecido)"

# Metadados de Treinamento, Diálogos e Comércio por Mestre NPC
const MASTER_DATA := {
	100: { # Garrick, o Ferreiro
		"title": "Garrick, o Mestre Ferreiro",
		"sub": "Forja da Bigorna Ancestral & Aço Temperado",
		"class_id": 7,
		"class_name": "Forjador de Estrelas",
		"greeting": "Pela bigorna sagrada! O fogo da forja purifica o aço e molda guerreiros imbatíveis. Quer afiar sua lâmina, reparar sua armadura ou aprender a arte do Ferreiro de Combate?",
		"color": Color("#ff9800"),
		"talk_quotes": [
			"O ferro nunca mente. Se bater com a força e o ritmo certos, ele sempre obedece à sua vontade.",
			"Cuidado com as feras da noite! As garras dos lobos quebram armaduras mal temperadas com facilidade.",
			"Dizem que no topo das Ruínas da Vigília há ligas antigas de aço celeste que ninguém conseguiu recuperar.",
			"Se trouxer um bom pedaço de Minério de Ferro para a forja, saberei recompensar sua lealdade com receitas raras."
		],
		"services": [
			{"icon": "🔨", "title": "Reparar Todos os Equipamentos", "desc": "Restaura a durabilidade de todas as armas e armaduras desgastadas.", "action": "repair"},
			{"icon": "🛡️", "title": "Forja de Armadura Pesada", "desc": "Encomende Placas de Aço Pesada para reforçar sua defesa contra monstros.", "action": "plate"},
			{"icon": "⚒️", "title": "Forjar Malho Rúnico de Batalha", "desc": "Disponível para aliados com Receita Secreta e Afiança Nível 3+.", "action": "warhammer"},
			{"icon": "📦", "title": "Comprar Lingotes de Ferro Temperado", "desc": "Matéria-prima essencial para aprimoramento na bigorna.", "action": "iron"}
		]
	},
	103: { # Lyra, a Alquimista
		"title": "Lyra, a Mestra Alquimista",
		"sub": "Transmutação Elemental & Elixires da Vida",
		"class_id": 8,
		"class_name": "Transmutador",
		"greeting": "O equilíbrio dos elementos governa todo o universo! Quer aprender a manipular poções corrosivas de ácido e frascos curativos de éter? Junte-se à arte alquímica!",
		"color": Color("#00e676"),
		"talk_quotes": [
			"A alquimia não é apenas misturar ingredientes, é entender a respiração dos elementos da terra e das luas.",
			"Os lobos da bruma absorvem o luar em suas veias. O sangue deles tem propriedades transmutativas extraordinárias.",
			"Às 03:00 da madrugada os vapores dos velhos esgotos sobem pela aldeia... Há sussurros do passado enterrados lá.",
			"Nunca confie em quem busca o poder proibido sem dominar primeiro a paciência das destilações puras."
		],
		"services": [
			{"icon": "🧪", "title": "Transmutar Poção de Sangue Lupino", "desc": "Combina Sangue Lupino Fresco e Frasco Vazio (+20% Velocidade e Crítico).", "action": "wolf_potion"},
			{"icon": "🏺", "title": "Adquirir Frascos de Vidro Vazios", "desc": "Recipientes essenciais para coleta de sangue e veneno de monstros abatidos.", "action": "empty_flask"},
			{"icon": "🌿", "title": "Elixir de Regeneração Acelerada", "desc": "Poção restauradora que cura ferimentos graves em segundos.", "action": "regen_potion"},
			{"icon": "🔮", "title": "Destilar Sangue Lunar Puro", "desc": "Transmuta a essência do Lobo Alfa em elixires de poder sublime.", "action": "pure_lunar"}
		]
	},
	104: { # Varis, o Mercador Sombrio
		"title": "Varis, o Mercador do Beco Sombrio",
		"sub": "Ceifador da Lua Negra & Pactos Proibidos",
		"class_id": 27,
		"class_name": "Ceifador da Lua Negra",
		"greeting": "Pssiu... A luz da vila é fraca demais contra o que rasteja lá fora. Se você não tem medo de ceifar almas com uma foice colossal, as sombras o acolherão...",
		"color": Color("#d500f9"),
		"talk_quotes": [
			"Nem tudo que brilha é sagrado, e nem toda escuridão traz a ruína. Há poder onde ninguém tem coragem de olhar.",
			"A foice do eclipse só ceifa quem não tem firmeza no espírito. Você teria a coragem de empunhá-la?",
			"Se um dia você encontrar um cálice antigo com a alma partida... não o jogue fora. O destino cobra seu preço.",
			"Os guardas da aldeia fingem que protegem a todos, mas tremem ao menor uivo na escuridão da mata."
		],
		"services": [
			{"icon": "💀", "title": "Troca Obscura: Cálice da Alma Partida", "desc": "Entregue uma Glândula de Veneno Sombrio para obter o Cálice Proibido.", "action": "chalice"},
			{"icon": "📖", "title": "Adquirir Tomo do Ceifador da Lua Negra", "desc": "Grimório proibido que permite despertar a classe Ceifador da Lua Negra.", "action": "scythe_tome"},
			{"icon": "🌑", "title": "Anel de Obsidiana das Sombras", "desc": "Relíquia que potencializa o dano crítico e furtividade nas trevas.", "action": "obsidian_ring"},
			{"icon": "🗡️", "title": "Adagas Envenenadas de Contrabando", "desc": "Armas leves imbuidas com secreção de aranhas do esgoto.", "action": "poison_dagger"}
		]
	},
	105: { # Capitão Randel
		"title": "Capitão Randel, Comandante da Guarda",
		"sub": "Mestre da Lâmina & Vanguarda Real",
		"class_id": 1,
		"class_name": "Espadachim da Aurora",
		"greeting": "A vila precisa de escudos fortes e lâminas afiadas contra os monstros do eclipse! Venha recruta, jure lealdade à vanguarda e torne-se um nobre Espadachim da Aurora!",
		"color": Color("#64b5f6"),
		"talk_quotes": [
			"A sentinela que dorme no posto condena toda a aldeia. Mantenha os olhos afiados no horizonte norte.",
			"Nossos batedores avistaram saqueadores se agrupando nas Ruínas da Vigília. O Comandante Vaelen comanda aquela escória.",
			"A espada é uma extensão da sua honra. Não a desembanhe em vão, mas nunca hesite em um golpe justo.",
			"A disciplina da guarda mantém os aldeões vivos. Sem ordem, o eclipse devoraria Lunaria em uma única noite."
		],
		"services": [
			{"icon": "🛡️", "title": "Inspecionar & Afiar Lâminas de Serviço", "desc": "Ajuste militar de combate para armas de corte e escudos.", "action": "guard_sharpen"},
			{"icon": "🥖", "title": "Rações Militares de Vanguarda", "desc": "Restaura vida e vigor rapidamente durante patrulhas prolongadas.", "action": "guard_rations"},
			{"icon": "⚔️", "title": "Espada Longa de Treinamento", "desc": "Lâmina equilibrada de aço forjado para novos recrutas da guarda.", "action": "training_sword"},
			{"icon": "📜", "title": "Relatório de Alerta: Ruínas da Vigília", "desc": "Informações táticas sobre a distribuição de saqueadores e besteiros.", "action": "vigil_report"}
		]
	},
	106: { # Guarda Valen
		"title": "Guarda Valen, Patrulheiro da Vila",
		"sub": "Arquearia Silvana & Rastreamento Primordial",
		"class_id": 3,
		"class_name": "Sentinela dos Ventos",
		"greeting": "Passos silenciosos na mata e olhos afiados nas trevas. Quer dominar o arco, flechas perfurantes e armadilhas táticas? Aprenda as artes do Sentinela dos Ventos!",
		"color": Color("#69f0ae"),
		"talk_quotes": [
			"O vento na relva entrega a aproximação de qualquer predador antes mesmo que você o veja.",
			"Se ouvir um uivo grave ecoando perto do Bosque Sussurrante, não fique parado ao luar desprotegido.",
			"Flechas com pontas de aço pesado são as únicas que perfuram a couraça espessa de um executor.",
			"Um bom caçador conhece o terreno como a palma da mão. Nunca lute encurralado contra matilhas de lobos."
		],
		"services": [
			{"icon": "🏹", "title": "Aljava de Flechas de Patrulha", "desc": "Flechas de penas de falcão e pontas de ferro temperado.", "action": "scout_arrows"},
			{"icon": "🧥", "title": "Capa Camuflada dos Bosques", "desc": "Reduz o alcance de detecção dos monstros enquanto espreita na vegetação.", "action": "camo_cloak"},
			{"icon": "🔥", "title": "Kit de Fogueira & Sinalizadores", "desc": "Iluminação tática para acampamentos em noites de bruma densa.", "action": "campfire_kit"},
			{"icon": "🗺️", "title": "Mapa de Trilhas do Bosque", "desc": "Rotas seguras e atalhos contornando o covil dos lobos.", "action": "woods_map"}
		]
	},
	107: { # Irmã Seraphina
		"title": "Irmã Seraphina, Mestra Guardiã",
		"sub": "Igreja da Luz Solar & Bênçãos Lunares",
		"class_id": 6,
		"class_name": "Guardião do Bastião",
		"greeting": "A Luz celestial dissipa as sombras mais antigas. Se seu espírito busca conforto, purificação das feridas ou a vocação de escudo inabalável, você encontrou seu refúgio.",
		"color": Color("#ffd54f"),
		"talk_quotes": [
			"Que a Chama Solar purifique sua alma contra os tormentos que habitam o Bosque e as Ruínas.",
			"A Lua e o Sol são faces complementares da mesma divindade celestial. Em noites de eclipse, o equilíbrio se rompe.",
			"A oração e o cântico dos protetores já salvaram mais vidas na vanguarda do que uma dúzia de espadas afiadas.",
			"A doação de amuletos sagrados e anéis estelares ajuda a manter as chamas do altar sempre acesas."
		],
		"services": [
			{"icon": "☀️", "title": "Receber Bênção da Luz Sagrada", "desc": "Purifica maldições e concede regeneração acelerada de vida (+Buff).", "action": "solar_blessing"},
			{"icon": "💧", "title": "Consagrar Água Benta da Igreja", "desc": "Frasco de água benta que causa dano severo a criaturas das sombras.", "action": "holy_water"},
			{"icon": "📿", "title": "Adquirir Amuleto da Lua Prateada", "desc": "Relíquia sagrada que amplia o poder de cura e resistência mágica.", "action": "silver_amulet"},
			{"icon": "🕯️", "title": "Vela Votiva do Altar Solar", "desc": "Afasta aparições espectrais menores e traz serenidade ao viajante.", "action": "votive_candle"}
		]
	},
	108: { # Mestre Aurelius
		"title": "Mestre Aurelius, Arquimago das Luas",
		"sub": "Observatório Astral & Cúpula Arcana",
		"class_id": 2,
		"class_name": "Arcanista",
		"greeting": "As dez fases da lua regem as correntes do éter em Lunaria. Venha decifrar os mistérios do cosmos e despertar as energias do Arcanista!",
		"color": Color("#4fc3f7"),
		"talk_quotes": [
			"Observe atentamente as órbitas lunares. Na Lua Cheia o éter se expande, e na Lua de Sangue ele entra em fúria.",
			"Esta torre foi erguida sobre uma encruzilhada de linhas de ley primordiais. Sinta a vibração mágica no ar.",
			"Os segredos da magia iniciada exigem mente serena e foco inabalável. Não se deixe seduzir pelos atalhos obscuros.",
			"Anéis estelares e fragmentos de meteoros ressoam com a cúpula mágica. São presentes de imenso valor científico."
		],
		"services": [
			{"icon": "🌌", "title": "Consulta Astronômica: As 10 Fases Lunares", "desc": "Aprenda sobre o impacto de cada lua nos elementos e monstros de Lunaria.", "action": "moon_lore"},
			{"icon": "🔮", "title": "Orbe de Ressonância Estelar", "desc": "Canalizador mágico que aumenta a amplificação de dano elemental.", "action": "star_orb"},
			{"icon": "📜", "title": "Tomo de Meditação Arcana", "desc": "Grimório que ensina técnicas aceleradas de foco místico.", "action": "arcane_tome"},
			{"icon": "✨", "title": "Pergaminho de Éter Puro", "desc": "Restaura instantaneamente a energia arcana e purifica anomalias.", "action": "ether_scroll"}
		]
	},
	109: { # Kaelen, o Mestre Caçador
		"title": "Kaelen, Mestre Caçador de Feras",
		"sub": "Posto da Fronteira & Rastreamento da Bruma",
		"class_id": 3,
		"class_name": "Sentinela dos Ventos",
		"greeting": "A floresta não perdoa os imprudentes. Os Lobos da Bruma caçam em matilha, e sob a Lua Cheia o Alfa desperta. Quer aprender a ler os rastros ou precisa de equipamentos de caça?",
		"color": Color("#81c784"),
		"talk_quotes": [
			"As pegadas dos Lobos da Bruma somem rápido na umidade da relva. Siga o cheiro característico de folhas esmagadas.",
			"O Lobo Alfa só sai de seu covil no Bosque Sussurrante sob o ápice da Lua Cheia nas coordenadas (75, -60).",
			"E se o céu ficar rubro sob a Lua de Sangue... fuja ou prepare-se para encarar o terrível Licantropo Alfa em (88, -72).",
			"Presas de lobo bem afiadas podem ser trocadas por pontas especiais de flechas perfurantes aqui no posto."
		],
		"services": [
			{"icon": "🏹", "title": "Flechas Perfurantes de Presa Lupina", "desc": "Projéteis de alta penetração que aplicam sangramento nas feras.", "action": "fang_arrows"},
			{"icon": "🐺", "title": "Dicas de Rastreamento do Covil do Alfa", "desc": "Pontos de emboscada e coordenadas exatas para caçar os grandes lobos.", "action": "alpha_tips"},
			{"icon": "🥩", "title": "Carne Seca de Fera Temperada", "desc": "Alimento concentrado de longa duração que restaura estamina.", "action": "dried_meat"},
			{"icon": "🪤", "title": "Armadilha Pesada de Espinhos", "desc": "Imobiliza grandes predadores por tempo suficiente para disparar flechas.", "action": "beast_trap"}
		]
	},
	110: { # O Alquimista Esquecido
		"title": "O Alquimista Esquecido",
		"sub": "Ecos dos Esgotos & Transmutações Proibidas",
		"class_id": 0,
		"class_name": "Transmutador Proibido",
		"greeting": "Sssss... Você desceu até a podridão para ouvir os sussurros dos mortos? Lyra me traiu e enterrou meu nome... Mas minhas fórmulas proibidas continuam vivas...",
		"color": Color("#69f0ae"),
		"talk_quotes": [
			"Eles me trancaram aqui embaixo para calar as verdades que os guardas da Luz não queriam que a vila soubesse...",
			"Lyra conhece muito bem meus frascos. Ela sabe que a fórmula da transmutação suprema foi roubada das minhas mãos...",
			"Nas horas mortas entre a meia-noite e as quatro da manhã, o véu da realidade se rompe nestes esgotos...",
			"Traga-me glândulas de veneno e sangue puro... Meu espírito ainda sabe como destilar o poder proibido."
		],
		"services": [
			{"icon": "⚗️", "title": "História Oculta: O Mistério das 03:00", "desc": "Os registros esquecidos sobre o eclipse primordial e a traição de Lyra.", "action": "ghost_story"},
			{"icon": "☠️", "title": "Transmutação Proibida do Sangue Lunar", "desc": "Converte Sangue Lunar em essência ectoplásmica de imenso poder.", "action": "ghost_transmute"},
			{"icon": "🧪", "title": "Elixir Ectoplásmico das Sombras", "desc": "Torna o viajante translúcido, reduzindo a agressividade de monstros.", "action": "ghost_elixir"},
			{"icon": "📜", "title": "Fragmento do Pergaminho Proibido", "desc": "Notas alquímicas antigas contendo fórmulas nunca ensinadas na superfície.", "action": "ghost_scroll"}
		]
	},
	111: { # Nyx Sombraveloz
		"title": "Nyx Sombraveloz, Mestra das Lâminas Silentes",
		"sub": "Beco do Mercado Negro (só à noite) • Umbryss, 31 anos • Ex-Irmandade do Sol Negro",
		"class_id": 4,
		"class_name": "Lâmina Silente",
		"greeting": "Você me encontrou nas sombras. Poucos conseguem. Fale baixo — e diga o que quer.",
		"color": Color("#7e57c2"),
		"talk_quotes": [
			"Fugi da Irmandade do Sol Negro quando mandaram matar uma criança no Eclipse. Desde então, caço meus antigos irmãos.",
			"Ataque quando o inimigo virar as costas. Honra não serve de nada para quem está morto.",
			"Chá de jasmim acalma as mãos. Mãos calmas não erram o golpe.",
			"Traga-me Glândulas de Veneno Sombrio dos esgotos e eu passo a confiar em você."
		],
		"services": [
			{"icon": "💨", "title": "Bomba de Fumaça", "desc": "Some por alguns instantes da vista dos monstros.", "action": "smoke_bomb"},
			{"icon": "🗡️", "title": "Lâminas Envenenadas", "desc": "Adagas leves banhadas em veneno de aranha.", "action": "poison_blades"},
			{"icon": "🎭", "title": "Máscara Sem Rosto", "desc": "Ninguém lembra de um rosto que nunca viu.", "action": "faceless_mask"},
			{"icon": "📜", "title": "Rumores da Irmandade", "desc": "Onde os assassinos do Sol Negro andam se escondendo.", "action": "nyx_rumors"}
		]
	},
	112: { # Mestre Tao Ferroventre
		"title": "Mestre Tao Ferroventre, Grão-Mestre do Punho Celeste",
		"sub": "Clareira na entrada do Bosque Sussurrante • Kharad, 64 anos • Palma do Vento",
		"class_id": 5,
		"class_name": "Punho Celeste",
		"greeting": "Ha-ha! Um visitante! Sente-se, tome um chá. Ou levante-se e me mostre esses punhos!",
		"color": Color("#ffb74d"),
		"talk_quotes": [
			"Lutei sete dias com um Jotunar no Pico das Nove Luas. Perdi dois dedos, ganhei a Palma do Vento.",
			"A força nasce dos pés, sobe pelo quadril e só termina no punho.",
			"Três socos seguidos e o corpo endurece como pedra. Continue batendo!",
			"Se derrubar o Lobo Alfa, traga a pele. Meu tatame está gasto. Ha-ha!"
		],
		"services": [
			{"icon": "🍵", "title": "Chá das Nove Luas", "desc": "Restaura o fôlego e acalma o espírito.", "action": "nine_moon_tea"},
			{"icon": "🥊", "title": "Faixas de Treino", "desc": "Faixas de linho que protegem os nós dos dedos.", "action": "hand_wraps"},
			{"icon": "🧘", "title": "Meditação na Cachoeira", "desc": "Uma lição sobre respiração e foco.", "action": "waterfall_meditation"},
			{"icon": "🍚", "title": "Bolinho de Arroz do Monge", "desc": "Simples, quente e cheio de energia.", "action": "rice_ball"}
		]
	},
	113: { # Iolanthe Mármore-Lunar
		"title": "Iolanthe Mármore-Lunar, Escultora de Almas",
		"sub": "Pátio das Estátuas, Ruínas da Vigília • Elarin, 27 anos • Aprendiz do Escultor do Luar",
		"class_id": 9,
		"class_name": "Escultor de Almas",
		"greeting": "Shh... as estátuas estão dormindo. Fale baixinho, viajante. O que procura nas ruínas?",
		"color": Color("#b0bec5"),
		"talk_quotes": [
			"Quando a Vigília caiu, os soldados me pediram para continuar de guarda. Esculpi cada um deles.",
			"A estátua com a espada quebrada era meu irmão Corvin. Às vezes juro que ele acena.",
			"Na Lua Cheia, as pedras cantam. É a coisa mais bonita que já ouvi.",
			"Um Anel de Luz Estelar daria olhos lindos para minha próxima estátua."
		],
		"services": [
			{"icon": "🪨", "title": "Cinzel de Pedra-Lua", "desc": "Ferramenta que desperta pequenas centelhas na pedra.", "action": "moonstone_chisel"},
			{"icon": "✨", "title": "Pó Lunar", "desc": "Brilha no escuro e fortalece guardiões de pedra.", "action": "lunar_dust"},
			{"icon": "🗿", "title": "Estatueta de Proteção", "desc": "Um pequeno vigia para a sua mochila.", "action": "ward_statuette"},
			{"icon": "📖", "title": "História da Vigília", "desc": "Como a fortaleza caiu e quem ainda a protege.", "action": "vigil_story"}
		]
	},
	114: { # Madame Fiorella Agulhadouro
		"title": "Madame Fiorella Agulhadouro, Tecelã Carmesim",
		"sub": "Ateliê Carmesim da Vila (08h–20h) • Cambion, 45 anos • Ex-costureira da corte de Aurelith",
		"class_id": 11,
		"class_name": "Tecelão Carmesim",
		"greeting": "Darling! Entre! Esse traje está implorando por socorro. O que posso costurar para você hoje?",
		"color": Color("#e53950"),
		"talk_quotes": [
			"Fugi de um casamento arranjado costurando o noivo na cortina. Melhor ponto que já dei!",
			"Fio de aço encantado corta melhor que espada, darling. E combina com tudo.",
			"Coleciono botões raros. Se achar algum, traga para mim!",
			"Prata da lua deixa o fio firme como promessa. Um Amuleto de Prata da Lua me faria muito feliz."
		],
		"services": [
			{"icon": "🧵", "title": "Carretel de Fio de Aço", "desc": "Fio encantado para costurar inimigos à distância.", "action": "steel_thread"},
			{"icon": "🪡", "title": "Agulhas Rúnicas", "desc": "Agulhas finas que guardam pequenos feitiços.", "action": "runic_needles"},
			{"icon": "🧥", "title": "Manto Sob Medida", "desc": "Um manto elegante para aventuras elegantes.", "action": "tailored_cloak"},
			{"icon": "🔘", "title": "Fofocas do Ateliê", "desc": "Tudo o que a vila não quer que você saiba.", "action": "atelier_gossip"}
		]
	},
	115: { # Chef Bartolomeu Brasa-Alta
		"title": "Chef Bartolomeu Brasa-Alta, Mestre do Banquete",
		"sub": "Cozinha da Taverna (10h–02h) • Orkhan, 52 anos • Ex-cozinheiro de navio",
		"class_id": 12,
		"class_name": "Mestre do Banquete",
		"greeting": "Fome, é? Conheço essa cara! Sente-se que o ensopado já está fervendo!",
		"color": Color("#ff7043"),
		"talk_quotes": [
			"Naufraguei numa ilha de monstros e passei três anos cozinhando tudo que tentava me devorar.",
			"Meu wok é preto porque cozinhei uma Hidra por dentro. História real!",
			"Não estou chorando, é o vapor da cebola.",
			"Sangue Lupino Fresco é o segredo do meu chouriço. Traga um frasco para a cozinha!"
		],
		"services": [
			{"icon": "🍲", "title": "Ensopado de Javali", "desc": "Restaura a vida de qualquer aventureiro faminto.", "action": "boar_stew"},
			{"icon": "🔪", "title": "Afiar Cutelo", "desc": "Corte limpo na autópsia, corte limpo na batalha.", "action": "sharpen_cleaver"},
			{"icon": "🍄", "title": "Sopa de Cogumelos do Bosque", "desc": "Aquece o corpo e clareia a mente.", "action": "mushroom_soup"},
			{"icon": "📒", "title": "Histórias do Naufrágio", "desc": "Três anos numa ilha de monstros, contados com molho.", "action": "shipwreck_tales"}
		]
	},
	116: { # Thorne, o Eremita das Feras (Mestre secreto)
		"title": "Thorne, o Eremita das Feras",
		"sub": "Coração do Bosque Sussurrante • Ulvar, 58 anos • Vive com a loba Cinza",
		"class_id": 0,
		"class_name": "Senhor das Feras",
		"greeting": "...Mãos longe da arma. Cinza não gosta de estranhos. O que quer aqui?",
		"color": Color("#8d6e63"),
		"talk_quotes": [
			"Numa Lua Cheia, poupei uma loba ferida em vez de matá-la. A matilha me adotou.",
			"Os lobos lembram de quem os respeita. E de quem não respeita também.",
			"Há vinte anos não piso na vila. Lá só ensinam a matar.",
			"Traga o que restou dos lobos que abateu. Presas. Peles. Devolvo tudo à terra."
		],
		"services": [
			{"icon": "🐺", "title": "Ouvir a Matilha", "desc": "Thorne conta o que os lobos sussurram.", "action": "thorne_pack"},
			{"icon": "🌕", "title": "Sobre a Lua Cheia", "desc": "Por que a matilha canta quando a lua está inteira.", "action": "thorne_moon"},
			{"icon": "🦴", "title": "Entregar Troféus de Lobo", "desc": "Presas e peles de Alfa aumentam a confiança de Thorne.", "action": "thorne_offer"},
			{"icon": "🌿", "title": "Ervas do Bosque", "desc": "Plantas que acalmam feras assustadas.", "action": "forest_herbs"}
		]
	}
}

# Referências de Nós
var main_panel: PanelContainer = null
var master_title_label: Label = null
var master_sub_label: Label = null
var master_friendship_label: Label = null
var master_greeting_label: Label = null
var content_vbox: VBoxContainer = null
var options_vbox: VBoxContainer = null

func _ready() -> void:
	layer = 22
	visible = false
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()

func open_master_menu(npc_id: int) -> void:
	current_npc_id = npc_id
	var m_info: Dictionary = MASTER_DATA.get(npc_id, MASTER_DATA[105])
	current_npc_name = m_info["title"]
	view_mode = "main"

	_update_display()
	open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var world := get_parent()
	if world and world.get("local_player") and is_instance_valid(world.local_player):
		world.local_player.set("is_menu_open", true)

func close_menu() -> void:
	is_open = false
	visible = false
	view_mode = "main"
	var world := get_parent()
	var any_other_open := false
	if world:
		if world.get("char_select_ui") and world.char_select_ui.get("is_open"):
			any_other_open = true
		if world.get("attributes_ui") and world.attributes_ui.get("is_open"):
			any_other_open = true
		if world.get("inventory_ui") and world.inventory_ui.get("is_open"):
			any_other_open = true
		if world.get("skills_ui") and world.skills_ui.get("is_open"):
			any_other_open = true
	if not any_other_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if world and world.get("local_player") and is_instance_valid(world.local_player):
			world.local_player.set("is_menu_open", false)

func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.05, 0.78)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(760, 520)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	p_style.border_color = Color(0.85, 0.72, 0.28, 0.95)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(10)
	p_style.shadow_color = Color(0, 0, 0, 0.85)
	p_style.shadow_size = 20
	p_style.content_margin_left = 24
	p_style.content_margin_right = 24
	p_style.content_margin_top = 18
	p_style.content_margin_bottom = 18
	main_panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(root_vbox)

	# Cabeçalho do Mestre
	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	root_vbox.add_child(header_vbox)

	master_title_label = Label.new()
	master_title_label.text = "Mestre de Lunaria"
	master_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	master_title_label.add_theme_font_size_override("font_size", 18)
	master_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	header_vbox.add_child(master_title_label)

	master_sub_label = Label.new()
	master_sub_label.text = "Vocação & Especialidade"
	master_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	master_sub_label.add_theme_font_size_override("font_size", 11)
	master_sub_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	header_vbox.add_child(master_sub_label)

	master_friendship_label = Label.new()
	master_friendship_label.text = "Afiança: ♡♡♡♡♡ (Nível 1: Desconhecido)"
	master_friendship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	master_friendship_label.add_theme_font_size_override("font_size", 12)
	master_friendship_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.55))
	header_vbox.add_child(master_friendship_label)

	root_vbox.add_child(HSeparator.new())

	# Diálogo / Fala do Mestre
	var speech_panel := PanelContainer.new()
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	sp_style.border_color = Color(0.3, 0.42, 0.6, 0.5)
	sp_style.set_border_width_all(1)
	sp_style.set_corner_radius_all(6)
	sp_style.content_margin_left = 14
	sp_style.content_margin_right = 14
	sp_style.content_margin_top = 10
	sp_style.content_margin_bottom = 10
	speech_panel.add_theme_stylebox_override("panel", sp_style)
	root_vbox.add_child(speech_panel)

	master_greeting_label = Label.new()
	master_greeting_label.text = "Fala do mestre..."
	master_greeting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	master_greeting_label.add_theme_font_size_override("font_size", 12)
	master_greeting_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	speech_panel.add_child(master_greeting_label)

	# Área de Conteúdo Central (Scrollável para caber perfeitamente todas as opções)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

	options_vbox = VBoxContainer.new()
	options_vbox.add_theme_constant_override("separation", 10)
	options_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(options_vbox)

	# Rodapé com Atalho de DEV e Fechar
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(footer_hbox)

	var dev_btn := Button.new()
	dev_btn.text = "⚡ [DEV: +10 Níveis Instantâneos]"
	dev_btn.add_theme_font_size_override("font_size", 11)
	dev_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var dev_style := StyleBoxFlat.new()
	dev_style.bg_color = Color(0.3, 0.18, 0.45, 0.9)
	dev_style.border_color = Color(0.7, 0.4, 0.9, 0.9)
	dev_style.set_border_width_all(1)
	dev_style.set_corner_radius_all(4)
	dev_btn.add_theme_stylebox_override("normal", dev_style)
	dev_btn.pressed.connect(_on_dev_level_up)
	footer_hbox.add_child(dev_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Despedir-se [Fechar / ESC]"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_menu)
	footer_hbox.add_child(close_btn)

func _update_display() -> void:
	var m_info: Dictionary = MASTER_DATA.get(current_npc_id, MASTER_DATA[105])

	if master_title_label:
		master_title_label.text = m_info["title"]
		master_title_label.add_theme_color_override("font_color", m_info["color"])

	if master_sub_label:
		master_sub_label.text = m_info["sub"]

	update_friendship_display()

	for ch in options_vbox.get_children():
		ch.queue_free()

	if view_mode == "trade":
		_render_trade_view(m_info)
	else:
		_render_main_view(m_info)

func update_friendship_display() -> void:
	var world := get_parent()
	var f_pts: int = 0
	if world and world.has_method("get_npc_friendship"):
		f_pts = world.get_npc_friendship(current_npc_id)
	if master_friendship_label:
		master_friendship_label.text = "Afiança: %s [%d/100 pts]" % [get_hearts_level_text(f_pts), f_pts]

# -------------------------------------------------------------
# VISÃO PRINCIPAL: 3 OPÇÕES (CONVERSAR, COMÉRCIO, CLASSE)
# -------------------------------------------------------------
func _render_main_view(m_info: Dictionary) -> void:
	if master_greeting_label:
		master_greeting_label.text = "\"%s\"" % m_info["greeting"]

	var world := get_parent()
	var my_class: int = 0
	var my_tier: int = 1
	var my_level: int = 1
	var my_race: int = 1
	if world:
		if world.get("my_class_id"): my_class = world.my_class_id
		if world.get("my_class_tier"): my_tier = world.my_class_tier
		if world.get("my_level"): my_level = world.my_level
		if world.get("my_race_id"): my_race = world.my_race_id

	var target_class_id: int = m_info["class_id"]
	var target_class_name: String = m_info["class_name"]

	# -------------------------------------------------------------
	# 1. BOTÃO CONVERSAR (GANHAR AMIZADE / AFIANÇA +5):
	# -------------------------------------------------------------
	var talk_btn := Button.new()
	talk_btn.custom_minimum_size = Vector2(0, 44)
	talk_btn.text = "💬 Conversar & Estreitar Laços (+Amizade / Afiança Diária)"
	talk_btn.add_theme_font_size_override("font_size", 12)
	talk_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var talk_style := StyleBoxFlat.new()
	talk_style.bg_color = Color(0.12, 0.22, 0.32, 0.95)
	talk_style.border_color = Color(0.4, 0.7, 1.0, 0.9)
	talk_style.set_border_width_all(1)
	talk_style.set_corner_radius_all(6)
	talk_btn.add_theme_stylebox_override("normal", talk_style)
	talk_btn.pressed.connect(_on_talk_pressed)
	options_vbox.add_child(talk_btn)

	# -------------------------------------------------------------
	# 2. BOTÃO ABRIR COMÉRCIO (COMPRAR / VENDER / REPARAR):
	# -------------------------------------------------------------
	var cur_hour: int = 12
	if world and "current_world_hour" in world:
		cur_hour = world.current_world_hour

	var f_pts: int = 0
	if world and world.has_method("get_npc_friendship"):
		f_pts = world.get_npc_friendship(current_npc_id)

	var is_shop_npc: bool = (current_npc_id == 100 or current_npc_id == 103)
	var is_night: bool = (cur_hour >= 18 or cur_hour < 6)
	var is_soulmate: bool = (f_pts >= 100) # Nível 5: Alma Irmã ❤️❤️❤️❤️❤️

	if is_shop_npc and is_night and not is_soulmate:
		var lock_pnl := PanelContainer.new()
		var lp_style := StyleBoxFlat.new()
		lp_style.bg_color = Color(0.18, 0.08, 0.08, 0.95)
		lp_style.border_color = Color(0.85, 0.3, 0.2, 0.8)
		lp_style.set_border_width_all(1)
		lp_style.set_corner_radius_all(6)
		lp_style.content_margin_left = 12
		lp_style.content_margin_right = 12
		lp_style.content_margin_top = 10
		lp_style.content_margin_bottom = 10
		lock_pnl.add_theme_stylebox_override("panel", lp_style)
		options_vbox.add_child(lock_pnl)

		var lock_lbl := Label.new()
		lock_lbl.text = "🔒 Expediente encerrado (Aberto das 06:00 às 18:00). O NPC está em horário de descanso!"
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.45))
		lock_pnl.add_child(lock_lbl)
	else:
		var trade_btn := Button.new()
		trade_btn.custom_minimum_size = Vector2(0, 44)
		if is_shop_npc and is_night and is_soulmate:
			trade_btn.text = "🛒 [Exceção de Alma Irmã ❤️❤️❤️❤️❤️] Abrir Loja / Forja Noturna"
		else:
			trade_btn.text = "🛒 Abrir Comércio & Serviços (Comprar / Vender / Reparar)"
		trade_btn.add_theme_font_size_override("font_size", 12)
		trade_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var trade_style := StyleBoxFlat.new()
		if is_shop_npc and is_night and is_soulmate:
			trade_style.bg_color = Color(0.35, 0.15, 0.25, 0.95)
			trade_style.border_color = Color(1.0, 0.45, 0.6, 0.9)
		else:
			trade_style.bg_color = Color(0.25, 0.2, 0.1, 0.95)
			trade_style.border_color = Color(1.0, 0.8, 0.3, 0.9)
		trade_style.set_border_width_all(1)
		trade_style.set_corner_radius_all(6)
		trade_btn.add_theme_stylebox_override("normal", trade_style)
		trade_btn.pressed.connect(_on_open_trade_pressed)
		options_vbox.add_child(trade_btn)

	# Separador sutil antes do bloco de Classe
	var class_sep := HSeparator.new()
	options_vbox.add_child(class_sep)

	# -------------------------------------------------------------
	# 3. SEÇÃO DE CLASSE (APRENDER / EVOLUIR / STATUS COMPATÍVEL):
	# -------------------------------------------------------------
	# Caso 3A: Viajante Sem Classe (ClassID == 0) -> Aprender Classe Básica
	if my_class == 0:
		if target_class_id > 0:
			var learn_btn := Button.new()
			learn_btn.custom_minimum_size = Vector2(0, 46)
			learn_btn.text = "⚔️ APRENDER CLASSE BÁSICA: %s (TIER 1)" % target_class_name.to_upper()
			learn_btn.add_theme_font_size_override("font_size", 13)
			learn_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var bstyle := StyleBoxFlat.new()
			bstyle.bg_color = m_info["color"].darkened(0.6)
			bstyle.border_color = m_info["color"]
			bstyle.set_border_width_all(2)
			bstyle.set_corner_radius_all(6)
			learn_btn.add_theme_stylebox_override("normal", bstyle)
			learn_btn.pressed.connect(func(): _learn_class(my_race, target_class_id))
			options_vbox.add_child(learn_btn)
		else:
			var secret_btn := Button.new()
			secret_btn.custom_minimum_size = Vector2(0, 46)
			secret_btn.text = "🔮 ABSORVER SEGREDOS PROIBIDOS DA ALQUIMIA"
			secret_btn.add_theme_font_size_override("font_size", 12)
			secret_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var s_style := StyleBoxFlat.new()
			s_style.bg_color = Color(0.15, 0.35, 0.25, 0.95)
			s_style.border_color = Color(0.4, 1.0, 0.6)
			s_style.set_border_width_all(2)
			s_style.set_corner_radius_all(6)
			secret_btn.add_theme_stylebox_override("normal", s_style)
			secret_btn.pressed.connect(func(): _on_secret_knowledge_pressed())
			options_vbox.add_child(secret_btn)

	# Caso 3B: Jogador é aluno desta classe -> Evolução e Ascensão
	elif my_class == target_class_id:
		var status_lbl := Label.new()
		status_lbl.text = "🛡️ Status de Aluno: Você é um %s (Tier %d, Nível %d)." % [target_class_name, my_tier, my_level]
		status_lbl.add_theme_font_size_override("font_size", 12)
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
		options_vbox.add_child(status_lbl)

		var my_sub_path: int = 0
		if world and world.get("my_sub_path"):
			my_sub_path = world.my_sub_path
		if ClassPaths.has_paths(my_class) and my_tier >= 2:
			if my_sub_path >= 1:
				var path_lbl := Label.new()
				path_lbl.text = "🧭 Caminho %d: %s — %s\n(Ao subir de Tier, nos níveis 25 e 45, você poderá trocar de Caminho.)" % [my_sub_path, ClassPaths.path_full_name(my_class, my_sub_path), ClassPaths.pros_cons(my_class, my_sub_path)]
				path_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				path_lbl.add_theme_font_size_override("font_size", 11)
				path_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
				options_vbox.add_child(path_lbl)
			else:
				var evo_prompt := Label.new()
				evo_prompt.text = "Seu domínio avançou! Escolha 1 dos 4 Caminhos Evolutivos (pode trocar a cada novo Tier):"
				evo_prompt.add_theme_font_size_override("font_size", 11)
				evo_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
				options_vbox.add_child(evo_prompt)
				for sub_path in range(1, 5):
					var path_id: int = sub_path
					var path_btn := Button.new()
					path_btn.custom_minimum_size = Vector2(0, 38)
					path_btn.text = "🧭 Caminho %d: %s (%s)" % [path_id, ClassPaths.path_full_name(my_class, path_id), ClassPaths.pros_cons(my_class, path_id)]
					path_btn.add_theme_font_size_override("font_size", 11)
					path_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					path_btn.pressed.connect(func(): _choose_path(path_id))
					options_vbox.add_child(path_btn)

		# Classes Únicas Exclusivas da raça do jogador (Tier 5, reset para o nível 1)
		for unique_id in ClassPaths.uniques_for_race(my_race):
			var u_id: int = unique_id
			var u_info: Dictionary = ClassPaths.TRANSCENDENT[u_id]
			if my_class == u_id:
				continue
			var u_btn := Button.new()
			u_btn.custom_minimum_size = Vector2(0, 38)
			u_btn.add_theme_font_size_override("font_size", 11)
			u_btn.text = "🩸 Despertar Classe Única da sua Linhagem: %s (exige %s) — reseta para o Nível 1" % [u_info["name"], u_info["requirement"]]
			u_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			u_btn.pressed.connect(func(): _learn_class(my_race, u_id))
			options_vbox.add_child(u_btn)

		# Variantes Secretas (13 a 18) que esta classe básica pode despertar (nível 25+, sem reset de nível)
		for variant_id in ClassPaths.variants_for_base(my_class):
			var v_id: int = variant_id
			var v_info: Dictionary = ClassPaths.VARIANTS[v_id]
			var v_btn := Button.new()
			v_btn.custom_minimum_size = Vector2(0, 38)
			v_btn.add_theme_font_size_override("font_size", 11)
			if my_level >= ClassPaths.VARIANT_MIN_LEVEL:
				v_btn.text = "🔮 Despertar Variante Secreta: %s (%s) — mantém o nível" % [v_info["name"], v_info["subtitle"]]
				v_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				v_btn.pressed.connect(func(): _learn_class(my_race, v_id))
			else:
				v_btn.text = "🔒 Variante Secreta: %s (requer nível %d)" % [v_info["name"], ClassPaths.VARIANT_MIN_LEVEL]
				v_btn.disabled = true
			options_vbox.add_child(v_btn)

		if my_tier == 5 and my_level >= 45:
			var leg_btn := Button.new()
			leg_btn.custom_minimum_size = Vector2(0, 42)
			leg_btn.text = "👑 Iniciar / Validar Provação Lendária (Ascensão Tier 6)"
			leg_btn.add_theme_font_size_override("font_size", 12)
			leg_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var leg_style := StyleBoxFlat.new()
			leg_style.bg_color = Color(0.45, 0.28, 0.05, 0.95)
			leg_style.border_color = Color(1.0, 0.85, 0.35, 1.0)
			leg_style.set_border_width_all(2)
			leg_style.set_corner_radius_all(6)
			leg_btn.add_theme_stylebox_override("normal", leg_style)
			leg_btn.pressed.connect(func(): _start_legendary_trial())
			options_vbox.add_child(leg_btn)

		if (my_level < 10) or (my_tier >= 4 and my_tier < 5) or (my_tier >= 6):
			var in_order_lbl := Label.new()
			in_order_lbl.text = "✨ Seu treinamento com este Mestre está em dia. Continue caçando monstros e ganhando experiência em Lunaria!"
			in_order_lbl.add_theme_font_size_override("font_size", 11)
			in_order_lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 0.75))
			options_vbox.add_child(in_order_lbl)

	# Caso 3C: Jogador possui OUTRA classe básica -> Informativo, SEM TRAVAR!
	else:
		var other_pnl := PanelContainer.new()
		var op_style := StyleBoxFlat.new()
		op_style.bg_color = Color(0.1, 0.12, 0.15, 0.8)
		op_style.border_color = Color(0.35, 0.45, 0.55, 0.6)
		op_style.set_border_width_all(1)
		op_style.set_corner_radius_all(6)
		op_style.content_margin_left = 10
		op_style.content_margin_right = 10
		op_style.content_margin_top = 8
		op_style.content_margin_bottom = 8
		other_pnl.add_theme_stylebox_override("panel", op_style)
		options_vbox.add_child(other_pnl)

		var other_lbl := Label.new()
		var player_class_name := "Outra Vocação"
		if world and "CLASS_NAMES" in world and my_class < world.CLASS_NAMES.size():
			player_class_name = world.CLASS_NAMES[my_class]
		other_lbl.text = "🛡️ Você já segue a vocação de %s. Como mestre de %s, respeito sua senda marcial! Você pode usufruir livremente de meus serviços de comércio, reparos e conversar para obter notícias e afiança." % [player_class_name, target_class_name]
		other_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		other_lbl.add_theme_font_size_override("font_size", 11)
		other_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
		other_pnl.add_child(other_lbl)

# -------------------------------------------------------------
# VISÃO DE COMÉRCIO & SERVIÇOS (COMPRAR / VENDER / REPARAR)
# -------------------------------------------------------------
func _render_trade_view(m_info: Dictionary) -> void:
	var trade_header := Label.new()
	trade_header.text = "🛒 Balcão de Comércio & Serviços de %s" % m_info["title"]
	trade_header.add_theme_font_size_override("font_size", 14)
	trade_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	options_vbox.add_child(trade_header)

	var services: Array = m_info.get("services", [])
	for s_data in services:
		var item_card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.09, 0.12, 0.17, 0.95)
		card_style.border_color = Color(0.35, 0.45, 0.6, 0.7)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		item_card.add_theme_stylebox_override("panel", card_style)
		options_vbox.add_child(item_card)

		var card_hbox := HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 12)
		item_card.add_child(card_hbox)

		var icon_lbl := Label.new()
		icon_lbl.text = s_data.get("icon", "📦")
		icon_lbl.add_theme_font_size_override("font_size", 18)
		card_hbox.add_child(icon_lbl)

		var text_vbox := VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_hbox.add_child(text_vbox)

		var t_title := Label.new()
		t_title.text = s_data.get("title", "Serviço")
		t_title.add_theme_font_size_override("font_size", 12)
		t_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		text_vbox.add_child(t_title)

		var t_desc := Label.new()
		t_desc.text = s_data.get("desc", "")
		t_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_desc.add_theme_font_size_override("font_size", 10)
		t_desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		text_vbox.add_child(t_desc)

		var act_btn := Button.new()
		act_btn.text = "Solicitar / Negociar"
		act_btn.add_theme_font_size_override("font_size", 11)
		act_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var ab_style := StyleBoxFlat.new()
		ab_style.bg_color = Color(0.18, 0.32, 0.22, 0.95)
		ab_style.border_color = Color(0.4, 0.85, 0.5, 0.9)
		ab_style.set_border_width_all(1)
		ab_style.set_corner_radius_all(4)
		act_btn.add_theme_stylebox_override("normal", ab_style)
		var act_name: String = s_data.get("action", "")
		var act_title: String = s_data.get("title", "")
		act_btn.pressed.connect(func(): _on_service_requested(act_name, act_title))
		card_hbox.add_child(act_btn)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(0, 38)
	back_btn.text = "⬅️ Voltar ao Diálogo Principal"
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(func():
		view_mode = "main"
		_update_display()
	)
	options_vbox.add_child(back_btn)

# -------------------------------------------------------------
# AÇÕES E EVENTOS
# -------------------------------------------------------------
func _on_talk_pressed() -> void:
	print("[ClassMasterUI] Conversando com NPC #%d!" % current_npc_id)
	var nm_node := get_node_or_null("/root/NetworkManager")
	if nm_node:
		nm_node.send_player_interact(current_npc_id)

	var world := get_parent()
	var cur_pts: int = 0
	if world and world.has_method("get_npc_friendship"):
		cur_pts = world.get_npc_friendship(current_npc_id)
	cur_pts = mini(100, cur_pts + 5)
	if world and world.has_method("set_npc_friendship"):
		world.set_npc_friendship(current_npc_id, cur_pts)

	var m_info: Dictionary = MASTER_DATA.get(current_npc_id, MASTER_DATA[105])
	var quotes: Array = m_info.get("talk_quotes", [])
	var quote: String = quotes[randi() % quotes.size()] if quotes.size() > 0 else m_info["greeting"]

	if master_greeting_label:
		master_greeting_label.text = "💬 \"%s\"\n\n✨ [Você fortaleceu sua afiança com %s! (+5 Pontos no Servidor)]" % [quote, m_info["title"]]

	update_friendship_display()

	if world and world.has_method("show_loot_toast"):
		world.show_loot_toast("✨ Afiança Aumentada: +5 pontos com %s! (%s)" % [m_info["title"], get_hearts_string(cur_pts)])

func _on_open_trade_pressed() -> void:
	var world := get_parent()
	var cur_hour: int = 12
	if world and "current_world_hour" in world:
		cur_hour = world.current_world_hour

	var f_pts: int = 0
	if world and world.has_method("get_npc_friendship"):
		f_pts = world.get_npc_friendship(current_npc_id)

	var is_shop_npc: bool = (current_npc_id == 100 or current_npc_id == 103)
	var is_night: bool = (cur_hour >= 18 or cur_hour < 6)
	var is_soulmate: bool = (f_pts >= 100)

	if is_shop_npc and is_night and not is_soulmate:
		if world and world.has_method("show_loot_toast"):
			world.show_loot_toast("🔒 Expediente encerrado (Aberto das 06:00 às 18:00). O NPC está em horário de descanso!")
		return

	view_mode = "trade"
	_update_display()

func _on_service_requested(action_key: String, service_title: String) -> void:
	print("[ClassMasterUI] Serviço solicitado: %s (%s) ao NPC #%d" % [service_title, action_key, current_npc_id])
	# Notifica o servidor via interação de pacote para registrar transações / ofertas
	var nm_node := get_node_or_null("/root/NetworkManager")
	if nm_node:
		nm_node.send_player_interact(current_npc_id)

	var world := get_parent()
	var m_info: Dictionary = MASTER_DATA.get(current_npc_id, MASTER_DATA[105])

	match action_key:
		"repair", "guard_sharpen":
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("🔨 %s: \"Seus equipamentos foram forjados, afiados e estão prontos para combate!\"" % m_info["title"])
		"solar_blessing":
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("☀️ Bênção Sagrada Concedida! A Luz Celestial purifica suas feridas.")
		"moon_lore":
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("🌌 Mestre Aurelius: \"A Lua Cheia amplia a mana; a Lua de Sangue liberta as feras!\"")
		"alpha_tips":
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("🐺 Kaelen: \"O Lobo Alfa espreita no Bosque Sussurrante (75, -60) na Lua Cheia!\"")
		"thorne_pack":
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("🐺 Thorne: \"Os lobos confiam em quem devolve à terra o que tirou deles. Presas, peles...\"")
		"thorne_moon":
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("🌕 Thorne: \"Na Lua Cheia, ou quando os vaga-lumes dançam no Bosque, a matilha ouve um novo chamado.\"")
		"ghost_story":
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("⚗️ Sussurros dos Esgotos: \"Às 03:00 a traição de Lyra foi consumada...\"")
		_:
			if world and world.has_method("show_loot_toast"):
				world.show_loot_toast("🛒 Negociação realizada: %s com %s!" % [service_title, m_info["title"]])

func _on_secret_knowledge_pressed() -> void:
	print("[ClassMasterUI] Absorvendo conhecimento secreto com NPC #%d!" % current_npc_id)
	var nm_node := get_node_or_null("/root/NetworkManager")
	if nm_node:
		nm_node.send_player_interact(current_npc_id)
	var world := get_parent()
	if world and world.has_method("show_loot_toast"):
		world.show_loot_toast("🔮 Conhecimento Arcano Proibido revelado pelo Espírito dos Esgotos!")

func _learn_class(race_id: int, new_class_id: int) -> void:
	print("[ClassMasterUI] Solicitando confirmação de Classe %d com Mestre #%d!" % [new_class_id, current_npc_id])
	var world := get_parent()
	var class_name_str := "Classe #%d" % new_class_id
	var master_name := current_npc_name if current_npc_name != "" else ("Mestre #%d" % current_npc_id)
	if ClassPaths.is_variant(new_class_id):
		class_name_str = ClassPaths.VARIANTS[new_class_id]["name"]
	elif ClassPaths.TRANSCENDENT.has(new_class_id):
		class_name_str = ClassPaths.TRANSCENDENT[new_class_id]["name"]
	elif MASTER_DATA.has(current_npc_id):
		class_name_str = MASTER_DATA[current_npc_id].get("class_name", class_name_str)
	if world and world.has_method("request_class_or_race_change"):
		# Únicas/Lendárias (19 a 27) entram no Tier 5; Variantes Secretas (13 a 18) no Tier 3; básicas no Tier 1
		var target_tier: int = ClassPaths.tier_for_class(new_class_id)
		world.request_class_or_race_change(false, new_class_id, target_tier, class_name_str, master_name)
	else:
		var nm := get_node_or_null("/root/NetworkManager")
		if nm and nm.get("my_player_id") and nm.my_player_id > 0:
			nm.send_select_identity(race_id, new_class_id, 0)
	close_menu()

func _choose_path(path_id: int) -> void:
	print("[ClassMasterUI] Caminho %d escolhido no Mestre!" % path_id)
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_evolution_choice(2, path_id)
	close_menu()

func _start_legendary_trial() -> void:
	print("[ClassMasterUI] Provação Lendária acionada!")
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_evolution_choice(3, 6)
	close_menu()

func _on_dev_level_up() -> void:
	print("[ClassMasterUI] Botão DEV: Solicitando +10 Níveis ao servidor...")
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.send_dev_level_up(10)
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(_update_display)

