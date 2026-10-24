extends CanvasLayer
const LunariaUI = preload("res://scripts/ui/LunariaUI.gd")
const ItemDataScript = preload("res://scripts/ItemData.gd")

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
		return "❤️❤️❤️❤️❤️ (Alma Irmã)"
	elif points >= 80:
		return "❤️❤️❤️❤️♡ (Leal)"
	elif points >= 60:
		return "❤️❤️❤️♡♡ (Confidente)"
	elif points >= 40:
		return "❤️❤️♡♡♡ (Amigo — Presentes e Favores liberados)"
	elif points >= 20:
		return "❤️♡♡♡♡ (Conhecido)"
	else:
		return "♡♡♡♡♡ (Desconhecido)"

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
	}
}

# NPCs da vila que não ensinam classe: mesma caixa de diálogo, sem a seção de vocação
const VILLAGER_DATA := {
	117: {
		"title": "Bran, Aprendiz da Forja",
		"sub": "Forja de Garrick • Humano, 17 anos • Sonha em forjar a própria espada",
		"greeting": "Ah! Oi! Desculpa a fuligem... o mestre Garrick me mandou cuidar do fole. Precisa de alguma coisa?",
		"about": "Garrick me pegou da rua quando eu tinha doze anos. Hoje eu já sei temperar uma lâmina — quase sem quebrar nenhuma.",
		"color": Color("#ffb74d"),
		"talk_quotes": [
			"Se o mestre Garrick faltar um dia, sou eu quem assume a bigorna. Ele diz que eu ainda bato torto.",
			"Escutei que o cobre perto do rio é mais macio. Dá pra trabalhar sem rachar.",
			"Uma vez deixei uma espada cair no barril de têmpera e ela saiu azul. Ninguém sabe por quê."
		],
	},
	118: {
		"title": "Pip, Aprendiz de Alquimia",
		"sub": "Laboratório de Lyra • Gnomo, 23 anos • Explodiu o caldeirão três vezes",
		"greeting": "Cuidado onde pisa! Esse frasco é... bom, não sei o que é, mas borbulha. Olá!",
		"about": "Lyra diz que tenho mãos firmes e cabeça avoada. Eu digo que é criatividade.",
		"color": Color("#ba68c8"),
		"talk_quotes": [
			"Água Purificada da fonte da praça é a melhor base pra poções. A do rio deixa gosto de lama.",
			"Cogumelos brilhantes só crescem perto da água. Nunca coma um sem saber o nome!",
			"Se eu errar a receita sai uma poção ruim... a Lyra finge que não vê."
		],
	},
	119: {
		"title": "Tilda, Ajudante de Cozinha",
		"sub": "Taverna do Javali Dourado • Halfling, 30 anos • Mão boa para temperos",
		"greeting": "Bem-vindo à Taverna! O Chef está gritando lá dentro, então fala baixinho comigo.",
		"about": "Cresci entre panelas. O Chef Bartolomeu diz que meu ensopado é quase tão bom quanto o dele. Quase.",
		"color": Color("#ff8a65"),
		"talk_quotes": [
			"Carne de javali precisa descansar no sal antes de ir pro fogo.",
			"Os guardas pedem sempre dose dupla depois da patrulha noturna.",
			"Quem come bem aguenta o frio da montanha. Leve comida antes de viajar!"
		],
	},
	120: {
		"title": "Mortimer, o Coveiro",
		"sub": "Cemitério da Vila • Humano, 61 anos • Enterra quem ninguém enterra",
		"greeting": "Hmm. Visitante vivo. Raridade por aqui. Veio prestar respeito ou cavar problema?",
		"about": "Quarenta anos de pá na mão. Os mortos são calmos; os vivos é que me dão trabalho.",
		"color": Color("#90a4ae"),
		"talk_quotes": [
			"Corpos largados viram coisa ruim depois de um tempo. Traga-os pra cá, é mais seguro pra todos.",
			"A Igreja vigia o cemitério. Necromante que aparecer por aqui não sai inteiro.",
			"Cada lápide tem um nome. Eu lembro de todos."
		],
	},
	123: {
		"title": "Mestra Joalheira Selene Lapidária",
		"sub": "Ateliê de Joias • Elfa, 140 anos • Lapida gemas desde antes da Vila existir",
		"greeting": "Bem-vindo ao meu ateliê. Cada pedra tem uma luz escondida; meu ofício é libertá-la.",
		"about": "Aprendi a lapidar com os anões das montanhas, e eles aprenderam comigo a ter paciência.",
		"color": Color("#80deea"),
		"talk_quotes": [
			"Rubis guardam calor; safiras guardam calma. Escolha bem o que levar no dedo.",
			"Quartzo é humilde, mas uma boa lapidação o faz brilhar como diamante.",
			"Traga-me Prata e eu cravejo qualquer gema que você encontrar."
		],
	},
	400: {
		"title": "Paladino da Luz",
		"sub": "Caçador da Igreja da Luz Sagrada",
		"greeting": "Que a Luz o proteja, viajante. Estou na trilha de mortos-vivos e de quem os ergue.",
		"about": "Fiz votos diante do altar de Seraphina. Minha espada só se ergue contra a escuridão.",
		"color": Color("#fff176"),
		"talk_quotes": [
			"Se vir um necromante, avise a Igreja. Não tente enfrentá-lo sozinho.",
			"Zumbis temem fogo e Luz. Água benta também ajuda.",
			"Rezo pelos que caíram sem túmulo."
		],
	},
	420: {
		"title": "Clériga da Luz",
		"sub": "Caçadora da Igreja da Luz Sagrada",
		"greeting": "A Luz guia meus passos. Precisa de cura ou de coragem?",
		"about": "Curei feridos em três epidemias. A Peste Cinzenta só cede às preces da Igreja.",
		"color": Color("#fff59d"),
		"talk_quotes": [
			"Doenças passam de pessoa para pessoa. Evite beber da água do rio.",
			"A Irmã Seraphina cura até a Peste Cinzenta, por uma oferta à Igreja.",
			"Os mortos merecem descanso. Leve os corpos ao Coveiro."
		],
	},
}

## Dados da caixa de diálogo de qualquer NPC (Mestres, aldeões, caçadores da Igreja).
func info_for(npc_id: int) -> Dictionary:
	if MASTER_DATA.has(npc_id):
		return MASTER_DATA[npc_id]
	var key := npc_id
	if npc_id >= 400 and npc_id < 420:
		key = 400
	elif npc_id >= 420 and npc_id < 440:
		key = 420
	var d: Dictionary = VILLAGER_DATA.get(key, {
		"title": "Morador de Lunaria", "sub": "Habitante da Vila",
		"greeting": "Olá, viajante. Belo dia, não?", "color": Color("#cfd8dc"),
		"talk_quotes": ["Dizem que a Fonte da praça nunca seca.", "Cuidado com as feras depois do pôr do sol."],
		}).duplicate()
	d["villager"] = true
	d["class_id"] = 0
	d["class_name"] = ""
	return d

# Pistas das Provações de Linhagem (servidor: race_trials.go)
const LINEAGE_RUMORS := [
	"Lupharion: um Varkai, Ferovar ou Ulvar que derrubar o Licantropo Alfa sob a Lua de Sangue.",
	"Seraphel: leve uma Tocha Sagrada ao altar da Igreja e espere a aurora (05h–06h).",
	"Umbryss: no Santuário, encare o Eclipse Total sem fugir por 20 segundos.",
	"Runaric: entregue o Malho Rúnico a um Garrick que confie muito em você.",
	"Sylvari: fique na clareira do Bosque quando as pétalas voarem ou o arco-íris surgir.",
	"Myconid: nos Esgotos, durante o Nevoeiro de Esporos, ofereça restos orgânicos à colônia.",
	"Ignivarn: derrube cinco Executores na Fronteira das Cinzas sob calor ou chuva de cinzas.",
	"Chimeryth: carregue um Retalho Quimérico quando a Quimera Costurada cair.",
	"Thalassiano: deixe a Monção do Bosque te abraçar por 40 segundos.",
	"Cambion: à meia-noite, no coração das Cinzas, com uma Glândula de Veneno nas mãos.",
	"Nephilim: no Santuário, entre o pôr do sol e a lua, numa noite de Lua Cheia.",
	"Aurelith: leve o Olho do Arauto para Irmã Seraphina purificar, de dia.",
	"Pyrael: dance (permaneça) 45 segundos sob a Chuva de Cinzas.",
	"Jotunar: só quem derrota Ymir herda o gelo eterno.",
	"Terravyrn: com uma Escama Primordial, transforme dez Gárgulas em pó.",
	"Hydravyrn: com uma Escama Primordial, deixe a chuva do Bosque molhá-la.",
	"Fulgravyrn: com uma Escama Primordial, espere o raio nas Ruínas durante a tempestade.",
	"Arcavyrn: com uma Escama Primordial, entre na Tempestade Arcana do Santuário.",
	"Orkhan: leve Carne Nobre Assada ao Chef Bartolomeu quando forem bons amigos (nível 10+).",
	"Dvergar: seja Alma Irmã de Garrick e entregue-lhe Minério de Ferro.",
	"Elarin: ouça as estátuas cantarem com Iolanthe numa noite de Lua Cheia.",
	"Solarin: ao meio-dia em ponto, céu limpo, no centro da praça (nível 15+).",
	"Lunarin: à meia-noite da Lua Cheia, no centro da praça (nível 15+).",
	"Faelith: entre na ciranda dos vaga-lumes no Bosque por 45 segundos.",
	"Gnarlin: conquiste a confiança de Varis e fale com ele à noite.",
	"Testudar: fique um minuto inteiro parado na chuva da clareira do Bosque.",
	"Lilitara: Nyx guarda um segredo que só revela sob a Lua de Sangue a quem é próximo dela.",
	"Ulvar: quando Thorne e Cinza confiarem em você, visite-os na Lua Cheia.",
	"Manamante: medite uma hora de madrugada (00h–03h) no centro da Torre Arcana (nível 20+).",
	"Sangrael, Cinerion, Aracne, Borealin, Cronari e Escarion despertam com relíquias raríssimas de monstros.",
]

# Referências de Nós
var main_panel: PanelContainer = null
var master_title_label: Label = null
var master_sub_label: Label = null
var master_friendship_label: Label = null
var master_greeting_label: Label = null
var content_vbox: VBoxContainer = null
var options_vbox: VBoxContainer = null
var social: Dictionary = {} # corações, cooldowns e favor vindos do servidor (0x64)

func _ready() -> void:
	layer = 22
	visible = false
	_build_ui()
	LunariaUI.watch(self) # mesmo estilo do inventário
	NetworkManager.social_state_received.connect(_on_social_state)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()

func open_master_menu(npc_id: int) -> void:
	current_npc_id = npc_id
	var m_info: Dictionary = info_for(npc_id)
	current_npc_name = m_info["title"]
	view_mode = "main"
	social = {}
	NetworkManager.send_social_action(npc_id, 0)

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
	var m_info: Dictionary = info_for(current_npc_id)

	if master_title_label:
		master_title_label.text = m_info["title"]
		master_title_label.add_theme_color_override("font_color", m_info["color"])

	if master_sub_label:
		master_sub_label.text = m_info["sub"]

	update_friendship_display()

	for ch in options_vbox.get_children():
		ch.queue_free()

	if view_mode == "gift":
		_render_gift_view()
	elif view_mode == "quest":
		_render_quest_view()
	elif view_mode == "talk":
		_render_talk_view(m_info)
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
	talk_btn.text = "💬 Conversar (assuntos e Afiança)"
	talk_btn.add_theme_font_size_override("font_size", 12)
	talk_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var talk_style := StyleBoxFlat.new()
	talk_style.bg_color = Color(0.12, 0.22, 0.32, 0.95)
	talk_style.border_color = Color(0.4, 0.7, 1.0, 0.9)
	talk_style.set_border_width_all(1)
	talk_style.set_corner_radius_all(6)
	talk_btn.add_theme_stylebox_override("normal", talk_style)
	talk_btn.pressed.connect(func():
		view_mode = "talk"
		_update_display()
	)
	options_vbox.add_child(talk_btn)

	# Presente e Missões: só a partir de 2 corações
	var hearts: int = int(social.get("hearts", 0))
	if hearts >= 2:
		var gift_btn := Button.new()
		gift_btn.custom_minimum_size = Vector2(0, 40)
		var gw: float = float(social.get("gift_wait", 0.0))
		gift_btn.text = "🎁 Presente" if gw <= 0.0 else "🎁 Presente (de novo em %s)" % _hours_text(gw)
		gift_btn.pressed.connect(func():
			view_mode = "gift"
			_update_display()
		)
		options_vbox.add_child(gift_btn)
		if bool(social.get("has_quests", false)):
			var quest_btn := Button.new()
			quest_btn.custom_minimum_size = Vector2(0, 40)
			quest_btn.text = "📜 Missões" + (" (favor em andamento)" if social.get("quest") != null else "")
			quest_btn.pressed.connect(func():
				view_mode = "quest"
				_update_display()
			)
			options_vbox.add_child(quest_btn)

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

	if current_npc_id == 100 and world and int(world.get("current_zone_id")) == 17:
		var forge_open := Button.new()
		forge_open.custom_minimum_size = Vector2(0, 40)
		forge_open.text = "🔨 Usar a Forja (Ligas e Blueprints)"
		forge_open.pressed.connect(func():
			close_menu()
			world.open_forge(false)
		)
		options_vbox.add_child(forge_open)

	if m_info.get("villager", false):
		return # aldeões não ensinam vocações

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
# -------------------------------------------------------------
# VISÃO DE CONVERSA: ASSUNTOS
# -------------------------------------------------------------
const TALK_TOPICS := [
	["👋", "Como vai você?", "mood"],
	["🧑", "Fale um pouco sobre você.", "about"],
	["📜", "Alguma novidade por aí?", "rumor"],
	["🗺️", "O que há para fazer na região?", "hint"],
	["💕", "Conversar com calma (1x a cada 8 h de jogo · leva até 2 corações)", "bond"],
]

func _render_talk_view(m_info: Dictionary) -> void:
	for topic in TALK_TOPICS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s  %s" % [topic[0], topic[1]]
		b.add_theme_font_size_override("font_size", 12)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.1, 0.16, 0.24, 0.95)
		st.border_color = Color(0.35, 0.55, 0.85, 0.7)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		st.content_margin_left = 12
		b.add_theme_stylebox_override("normal", st)
		var kind: String = topic[2]
		b.pressed.connect(func(): _answer_topic(kind, m_info))
		options_vbox.add_child(b)
	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(0, 34)
	back_btn.text = "⬅️ Voltar"
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(func():
		view_mode = "main"
		_update_display()
	)
	options_vbox.add_child(back_btn)

func _answer_topic(kind: String, m_info: Dictionary) -> void:
	if kind == "bond":
		_on_talk_pressed()
		return
	var world := get_parent()
	var hour: int = 12
	if world and "current_world_hour" in world:
		hour = world.current_world_hour
	var quotes: Array = m_info.get("talk_quotes", [])
	var text := ""
	match kind:
		"mood":
			if hour < 6:
				text = "*boceja* Já era para eu estar dormindo... mas tudo bem, fale."
			elif hour < 12:
				text = "Bem disposto! A manhã é a melhor hora para trabalhar."
			elif hour < 18:
				text = "Cansado, mas o trabalho não para. E você, como vai a jornada?"
			else:
				text = "A noite chegou. Hora de descansar e ficar longe das feras."
		"about":
			text = m_info.get("about", m_info.get("sub", ""))
		"rumor":
			text = quotes[randi() % quotes.size()] if quotes.size() > 0 else m_info["greeting"]
		"hint":
			var hints := [
				"A Fonte de Água Purificada da praça enche seus frascos com água da melhor qualidade.",
				"O Rio Prateado corta todas as regiões. Siga a estrada e não se perde.",
				"Aperte M para ver o mapa de Lunaria inteiro.",
				"Os covis de feras ficam longe das estradas. Ande pelas trilhas se estiver ferido.",
			]
			text = hints[randi() % hints.size()]
	if master_greeting_label:
		master_greeting_label.text = "💬 \"%s\"" % text

# -------------------------------------------------------------
# AÇÕES E EVENTOS
# -------------------------------------------------------------
func _on_talk_pressed() -> void:
	# A Afiança da conversa é decidida pelo servidor (+3, uma vez a cada 8 h de jogo, até 2 corações)
	NetworkManager.send_social_action(current_npc_id, 1)
	NetworkManager.send_player_interact(current_npc_id)
	var m_info: Dictionary = info_for(current_npc_id)
	var quotes: Array = m_info.get("talk_quotes", [])
	var quote: String = quotes[randi() % quotes.size()] if quotes.size() > 0 else m_info["greeting"]
	if master_greeting_label:
		master_greeting_label.text = "💬 \"%s\"" % quote

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

	if world and world.has_method("open_shop"):
		close_menu()
		world.open_shop(current_npc_id, info_for(current_npc_id)["title"])

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


# -------------------------------------------------------------
# AMIZADE: PRESENTES E FAVORES (estado vem do servidor)
# -------------------------------------------------------------
func _hours_text(h: float) -> String:
	if h >= 1.0:
		return "%d h de jogo" % int(ceil(h))
	return "%d min de jogo" % int(ceil(h * 60.0))

func _on_social_state(st: Dictionary) -> void:
	if int(st.get("npc", 0)) != current_npc_id:
		return
	social = st
	var world := get_parent()
	if world and world.has_method("set_npc_friendship"):
		world.set_npc_friendship(current_npc_id, int(st.get("points", 0)))
	var m: String = str(st.get("msg", ""))
	if m != "" and master_greeting_label:
		master_greeting_label.text = "💬 " + m
	if is_open:
		_update_display()

func _render_gift_view() -> void:
	var info_lbl := Label.new()
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.text = "Escolha um presente. Cada morador tem seus gostos: o que ele ama rende muita Afiança, mas o que ele detesta faz você PERDER Afiança. Um presente por dia."
	options_vbox.add_child(info_lbl)
	var gw: float = float(social.get("gift_wait", 0.0))
	if gw > 0.0:
		var wait_lbl := Label.new()
		wait_lbl.text = "⏳ Já recebeu um presente seu hoje. Próximo em %s." % _hours_text(gw)
		options_vbox.add_child(wait_lbl)
	else:
		var gifts: Array = social.get("gifts", [])
		if gifts.is_empty():
			var none_lbl := Label.new()
			none_lbl.text = "Sua mochila está vazia."
			options_vbox.add_child(none_lbl)
		for g in gifts:
			var item_id: int = int(g["id"])
			var q: int = int(g["q"])
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 32)
			b.text = "🎁 %s  [Qualidade %d]  ×%d" % [str(ItemDataScript.info(item_id).get("name", "Item")), q, int(g["n"])]
			b.pressed.connect(func():
				NetworkManager.send_social_action(current_npc_id, 2, item_id, q)
			)
			options_vbox.add_child(b)
	_add_back_button()

func _render_quest_view() -> void:
	var q = social.get("quest")
	if q is Dictionary:
		var title := Label.new()
		title.text = "📜 %s" % str(q.get("title", "Favor"))
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		options_vbox.add_child(title)
		var intro := Label.new()
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro.text = "\"%s\"" % str(q.get("intro", ""))
		options_vbox.add_child(intro)
		var steps: Array = q.get("steps", [])
		var cur: int = int(q.get("step", 0))
		for i in range(steps.size()):
			var sl := Label.new()
			var mark := "✅" if i < cur else ("▶️" if i == cur else "▫️")
			sl.text = "%s %s" % [mark, str(steps[i])]
			options_vbox.add_child(sl)
		var rw := Label.new()
		rw.text = "Recompensa: %s" % str(q.get("reward", ""))
		rw.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		options_vbox.add_child(rw)
		var turn := Button.new()
		turn.custom_minimum_size = Vector2(0, 40)
		turn.text = "🏆 Receber a recompensa" if bool(q.get("ready", false)) else "📦 Entregar / Ver o que falta"
		turn.pressed.connect(func():
			NetworkManager.send_social_action(current_npc_id, 4)
		)
		options_vbox.add_child(turn)
		var give_up := Button.new()
		give_up.text = "Desistir deste favor"
		give_up.pressed.connect(func():
			NetworkManager.send_social_action(current_npc_id, 5)
		)
		options_vbox.add_child(give_up)
	else:
		var qw: float = float(social.get("quest_wait", 0.0))
		var ask := Button.new()
		ask.custom_minimum_size = Vector2(0, 40)
		if qw > 0.0:
			ask.text = "Sem favores agora (volte em %s)" % _hours_text(qw)
			ask.disabled = true
		else:
			ask.text = "🙋 Posso ajudar em alguma coisa?"
		ask.pressed.connect(func():
			NetworkManager.send_social_action(current_npc_id, 3)
		)
		options_vbox.add_child(ask)
	_add_back_button()

func _add_back_button() -> void:
	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(0, 34)
	back_btn.text = "⬅️ Voltar"
	back_btn.pressed.connect(func():
		view_mode = "main"
		_update_display()
	)
	options_vbox.add_child(back_btn)
