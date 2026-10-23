package world

import (
	"testing"

	"lunaria/server/internal/protocol"
)

func TestCalculateStatsByClassAndRace(t *testing.T) {
	// Espadachim (140, 100) + Valeriano (+10, +10) = (150, 110)
	hp, stam := CalculateStatsByClassAndRace(protocol.ClassSwordsman, protocol.RaceValerian)
	if hp != 150 || stam != 110 {
		t.Fatalf("Esperava (150, 110) para Espadachim Valeriano, obteve (%d, %d)", hp, stam)
	}

	// Batedor (105, 135) + Noctari (+0, +20) = (105, 155)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassScout, protocol.RaceNoctari)
	if hp != 105 || stam != 155 {
		t.Fatalf("Esperava (105, 155) para Batedor Noctari, obteve (%d, %d)", hp, stam)
	}

	// Iniciado (95, 110) + Kharad (+30, +0) = (125, 110)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassInitiate, protocol.RaceKharad)
	if hp != 125 || stam != 110 {
		t.Fatalf("Esperava (125, 110) para Iniciado Kharad, obteve (%d, %d)", hp, stam)
	}

	// Assassino (110, 140) + Dhampir (+10, +15) = (120, 155)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassAssassin, protocol.RaceDhampir)
	if hp != 120 || stam != 155 {
		t.Fatalf("Esperava (120, 155) para Assassino Dhampir, obteve (%d, %d)", hp, stam)
	}

	// Espadachim (140, 100) + Varkai (+15, +10) = (155, 110)
	hp, stam = CalculateStatsByClassAndRace(protocol.ClassSwordsman, protocol.RaceVarkai)
	if hp != 155 || stam != 110 {
		t.Fatalf("Esperava (155, 110) para Espadachim Varkai, obteve (%d, %d)", hp, stam)
	}

	// Ferreiro (155, 100) + Valeriano (+10, +10) = (165, 110)
	hp, stam = CalculateStats(protocol.ClassBlacksmith, protocol.RaceValerian, protocol.TierCommon, 1)
	if hp != 165 || stam != 110 {
		t.Fatalf("Esperava (165, 110) para Ferreiro Valeriano, obteve (%d, %d)", hp, stam)
	}

	// Alquimista (110, 120) + Noctari (+0, +20) = (110, 140)
	hp, stam = CalculateStats(protocol.ClassAlchemist, protocol.RaceNoctari, protocol.TierCommon, 1)
	if hp != 110 || stam != 140 {
		t.Fatalf("Esperava (110, 140) para Alquimista Noctari, obteve (%d, %d)", hp, stam)
	}
}

func TestClassTiersAndLevelProgression(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)
	// Inicial: Viajante Sem Classe (ClassID = 0, ClassTier = 0)
	if p.ClassTier != protocol.TierTraveler || p.ClassID != protocol.ClassNone || p.Level != 1 {
		t.Fatalf("Esperava Viajante Sem Classe Tier 0 e Level 1, obteve Tier %d Class %d Level %d", p.ClassTier, p.ClassID, p.Level)
	}

	// Aprende a Classe Espadachim com o Guarda Mestre (ActionMode 0): Valeriano (1) + Espadachim (1) -> Base (150, 110) Tier 1, Level 1
	p.SetIdentityMode(protocol.RaceValerian, protocol.ClassSwordsman, protocol.IdentityModeInitialChange)
	if p.ClassTier != protocol.TierCommon || p.Level != 1 {
		t.Fatalf("Esperava Tier 1 Comum e Level 1, obteve Tier %d Level %d", p.ClassTier, p.Level)
	}
	if p.MaxHP != 150 || p.MaxStamina != 110 {
		t.Fatalf("Esperava (150, 110), obteve (%d, %d)", p.MaxHP, p.MaxStamina)
	}

	// Treinar +5 Níveis (ActionMode 3): Level 1 -> Level 6
	// Level 6: +25 HP e +10 Stam -> Base (175, 120)
	p.SetIdentityMode(0, 0, protocol.IdentityModeTrainLevel5)
	if p.Level != 6 {
		t.Fatalf("Esperava Level 6 após treino, obteve %d", p.Level)
	}
	if p.MaxHP != 175 || p.MaxStamina != 120 {
		t.Fatalf("Esperava (175, 120) no Level 6 Tier 1, obteve (%d, %d)", p.MaxHP, p.MaxStamina)
	}

	// Evoluir Classe (ActionMode 1): Tier 1 -> Tier 2 (Incomum: 1.20x)
	// Level DEVE SER MANTIDO em 6!
	// 175 * 1.20 = 210 HP, 120 * 1.20 = 144 Stam (Caminho Evolutivo ainda não escolhido: sem multiplicador)
	p.SetIdentityMode(0, 0, protocol.IdentityModeEvolveClass)
	if p.ClassTier != protocol.TierUncommon {
		t.Fatalf("Esperava Tier 2 Incomum, obteve %d", p.ClassTier)
	}
	if p.Level != 6 {
		t.Fatalf("Evolução de classe base deve MANTER o nível! Esperava 6, obteve %d", p.Level)
	}
	if p.MaxHP != 210 || p.MaxStamina != 144 {
		t.Fatalf("Esperava (210, 144) no Tier 2 Level 6, obteve (%d, %d)", p.MaxHP, p.MaxStamina)
	}

	// Evoluir para Tier 3 (Rara: 1.45x)
	p.SetIdentityMode(0, 0, protocol.IdentityModeEvolveClass)
	if p.ClassTier != protocol.TierRare || p.Level != 6 {
		t.Fatalf("Esperava Tier 3 Rara mantendo Level 6, obteve Tier %d Level %d", p.ClassTier, p.Level)
	}

	// Evoluir para Tier 4 (Épica: 1.75x)
	p.SetIdentityMode(0, 0, protocol.IdentityModeEvolveClass)
	if p.ClassTier != protocol.TierEpic || p.Level != 6 {
		t.Fatalf("Esperava Tier 4 Épica mantendo Level 6, obteve Tier %d Level %d", p.ClassTier, p.Level)
	}

	// Classes Base têm teto no Tier 4 (não sobem para 5)
	p.SetIdentityMode(0, 0, protocol.IdentityModeEvolveClass)
	if p.ClassTier != protocol.TierEpic {
		t.Fatalf("Classe Base não pode ultrapassar Tier 4! Obteve %d", p.ClassTier)
	}

	// Trocar para Classe Secreta (ActionMode 2): Ceifador do Eclipse (7)
	// Deve iniciar no Tier 5 (Única) e RESETAR NÍVEL PARA 1!
	p.SetIdentityMode(protocol.RaceDhampir, protocol.ClassEclipseReaper, protocol.IdentityModeSecretReset)
	if p.ClassID != protocol.ClassEclipseReaper {
		t.Fatalf("Esperava Classe 7 Ceifador, obteve %d", p.ClassID)
	}
	if p.ClassTier != protocol.TierUnique {
		t.Fatalf("Classe Secreta deve iniciar no Tier 5 Única, obteve %d", p.ClassTier)
	}
	if p.Level != 1 {
		t.Fatalf("Troca para Classe Secreta DEVE RESETAR o nível para 1! Obteve %d", p.Level)
	}

	// Evoluir Classe Secreta de Tier 5 (Única) para Tier 6 (Lendária: 2.60x) mantendo o nível!
	p.AddLevel(2) // sobe para level 3
	p.SetIdentityMode(0, 0, protocol.IdentityModeEvolveClass)
	if p.ClassTier != protocol.TierLegendary {
		t.Fatalf("Evolução final da Classe Secreta deve ir para Tier 6 Lendária, obteve %d", p.ClassTier)
	}
	if p.Level != 3 {
		t.Fatalf("Evolução para Lendária deve manter o nível 3! Obteve %d", p.Level)
	}
}

func TestPlayerRespawnMechanics(t *testing.T) {
	p := NewPlayer(1, nil, 10.0, -12.0, 5.0)
	p.HP = 10
	p.Stamina = 5.0

	// Executa Respawn oficial no Centro (0, 1.5, 0)
	p.Respawn(0.0, 1.5, 0.0)

	if p.PosX != 0.0 || p.PosY != 1.5 || p.PosZ != 0.0 {
		t.Fatalf("Posição pós-respawn incorreta: (%.1f, %.1f, %.1f)", p.PosX, p.PosY, p.PosZ)
	}
	if p.HP != p.MaxHP || p.Stamina != float32(p.MaxStamina) {
		t.Fatalf("HP e Stamina deveriam estar no máximo pós-respawn: HP %d/%d, Stamina %.1f/%d",
			p.HP, p.MaxHP, p.Stamina, p.MaxStamina)
	}
	if !p.IsInvulnerable() {
		t.Fatalf("Jogador deve estar invulnerável nos 2s pós-respawn")
	}
	if !p.IsRespawnLocked() {
		t.Fatalf("Trava de 1s de respawn UDP deve estar ativa")
	}

	// Dano durante I-Frame pós-respawn deve ser ignorado
	hpBefore := p.HP
	newHP, dead := p.TakeDamage(100)
	if dead || newHP != hpBefore {
		t.Fatalf("Dano durante I-Frame pós-respawn não foi ignorado: HP %d -> %d", hpBefore, newHP)
	}
}

func TestKharadDamageReduction(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.SetIdentity(protocol.RaceKharad, protocol.ClassMage) // classe sem passiva defensiva: isola a redução da raça

	initialHP := p.HP
	// Dano bruto de 100 deve ser reduzido em 20% para 80
	newHP, dead := p.TakeDamage(100)
	if dead {
		t.Fatalf("jogador nao deveria ter morrido")
	}
	expectedHP := initialHP - 80
	if newHP != expectedHP {
		t.Fatalf("esperava HP %d apos reducao de 20%%, obteve %d", expectedHP, newHP)
	}
}

func TestProjectileManager(t *testing.T) {
	pm := NewProjectileManager()
	proj := pm.Spawn(1, protocol.ProjTypePhysicalArrow, 0, 1.2, 0, 0, 2.0, 24.0, 16.0)

	if proj.ID < 1000 {
		t.Fatalf("ID do projetil invalido: %d", proj.ID)
	}
	if proj.DirZ != 1.0 || proj.DirX != 0.0 {
		t.Fatalf("direcao nao foi normalizada: (%.2f, %.2f)", proj.DirX, proj.DirZ)
	}

	active := pm.GetActiveProjectiles()
	if len(active) != 1 {
		t.Fatalf("esperava 1 projetil ativo, obteve %d", len(active))
	}

	// Marca como percorrido alem do MaxRange
	proj.Traveled = 17.0
	pm.Cleanup()

	active = pm.GetActiveProjectiles()
	if len(active) != 0 {
		t.Fatalf("projetil deveria ter sido limpo apos atingir MaxRange")
	}
}

func TestPlayerXPAndLevelProgression(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)
	if p.Level != 1 || p.XP != 0 || p.NextLevelXP != 100 || p.StatPoints != 0 {
		t.Fatalf("Estado inicial de XP incorreto: %+v", p)
	}

	leveled := p.AddXP(50)
	if leveled || p.Level != 1 || p.XP != 50 {
		t.Fatalf("Esperava Level 1 com 50 XP, obteve Level %d XP %d", p.Level, p.XP)
	}

	leveled = p.AddXP(60) // Total 110 XP -> sobe para Nível 2 com sobra de 10 XP
	// Tier 0 (Viajante): +3 StatPoints por nível!
	if !leveled || p.Level != 2 || p.XP != 10 || p.NextLevelXP != 150 || p.StatPoints != 3 {
		t.Fatalf("Esperava Level 2, 10 XP, Next 150, 3 StatPoints (Tier 0 Viajante), obteve Level %d XP %d Next %d Points %d",
			p.Level, p.XP, p.NextLevelXP, p.StatPoints)
	}

	// Escolhe Classe no Mestre: Espadachim (Tier 1 Comum: +5 StatPoints por nível)
	p.SetIdentityMode(protocol.RaceValerian, protocol.ClassSwordsman, protocol.IdentityModeInitialChange)

	// 500 XP de uma vez (como matar o Licantropo Alfa)
	leveled = p.AddXP(500)
	// Do Level 2 (10 XP, next 150): +500 = 510.
	// Lvl 2->3 consome 150 (sobra 360). Next 200. (+5)
	// Lvl 3->4 consome 200 (sobra 160). Next 250. (+5)
	// Final: Level 4, XP 160, Next 250, StatPoints = 3 (do Tier 0) + 5 + 5 = 13.
	if !leveled || p.Level != 4 || p.XP != 160 || p.NextLevelXP != 250 || p.StatPoints != 13 {
		t.Fatalf("Progresso em massa incorreto: Level %d XP %d Next %d Points %d",
			p.Level, p.XP, p.NextLevelXP, p.StatPoints)
	}
}

func TestPlayerStatAllocation(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)
	p.StatPoints = 5
	initialHP := p.MaxHP
	initialStam := p.MaxStamina
	initCON := p.CON
	initAGI := p.AGI

	// Aloca 1 ponto em CON (StatID 3): +18 MaxHP
	ok := p.AllocateStat(protocol.StatIDCON)
	if !ok || p.CON != initCON+1 || p.StatPoints != 4 || p.MaxHP != initialHP+18 {
		t.Fatalf("Falha ao alocar CON: ok=%v, CON=%d, Points=%d, MaxHP=%d (esperava %d)",
			ok, p.CON, p.StatPoints, p.MaxHP, initialHP+18)
	}

	// Aloca 1 ponto em AGI (StatID 4): +8 MaxStamina
	ok = p.AllocateStat(protocol.StatIDAGI)
	if !ok || p.AGI != initAGI+1 || p.StatPoints != 3 || p.MaxStamina != initialStam+8 {
		t.Fatalf("Falha ao alocar AGI: ok=%v, AGI=%d, Points=%d, MaxStam=%d (esperava %d)",
			ok, p.AGI, p.StatPoints, p.MaxStamina, initialStam+8)
	}

	// Aloca com ID inválido
	if p.AllocateStat(99) {
		t.Fatalf("Alocação com ID inválido não deveria suceder")
	}
}

func TestPrimordialLycanthropeEvolution(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)
	p.SetIdentity(protocol.RaceVarkai, protocol.ClassSwordsman)
	varkaiHP := p.MaxHP
	varkaiStam := p.MaxStamina

	p.EvolveToPrimordialLycanthrope()
	if p.RaceID != protocol.RacePrimordialLycanthrope {
		t.Fatalf("Esperava RacePrimordialLycanthrope (6), obteve %d", p.RaceID)
	}
	if p.MaxHP != varkaiHP+80 {
		t.Fatalf("Esperava MaxHP %d (+80), obteve %d", varkaiHP+80, p.MaxHP)
	}
	if p.MaxStamina != varkaiStam+30 {
		t.Fatalf("Esperava MaxStamina %d (+30), obteve %d", varkaiStam+30, p.MaxStamina)
	}
}

func TestPlayerInventoryAndEquip(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)

	// Validação de itens iniciais: 3x Frasco Vazio (1) e 2x Carne Crua (2)
	if p.GetItemCount(protocol.ItemEmptyFlask) != 3 {
		t.Fatalf("Esperava 3 frascos vazios iniciais, obteve %d", p.GetItemCount(protocol.ItemEmptyFlask))
	}
	if p.GetItemCount(protocol.ItemRawWolfMeat) != 2 {
		t.Fatalf("Esperava 2 carnes cruas iniciais, obteve %d", p.GetItemCount(protocol.ItemRawWolfMeat))
	}
	if !p.HasItem(protocol.ItemEmptyFlask) || !p.HasItem(protocol.ItemRawWolfMeat) {
		t.Fatalf("HasItem retornou falso para itens iniciais")
	}

	// Adição e Remoção de Itens
	p.AddItem(protocol.ItemAlphaWolfPelt, 1)
	p.AddItem(protocol.ItemAncestralFangRing, 1)
	if p.GetItemCount(protocol.ItemAlphaWolfPelt) != 1 {
		t.Fatalf("Falha ao adicionar Pele de Lobo Alfa")
	}

	slots := p.GetInventorySlots()
	if len(slots) != 4 { // Frasco (1), Carne (2), Pele (9), Anel (13)
		t.Fatalf("Esperava 4 slots, obteve %d", len(slots))
	}

	// Equipar Pele de Lobo Alfa (9): Capa de Pele Alfa -> +35 MaxHP, +3 STR
	oldHP := p.MaxHP
	strBefore, _, _, _, _, _, _, _ := p.GetAttributes()
	ok, _ := p.EquipItem(protocol.ItemAlphaWolfPelt)
	if !ok || p.EquippedArmorID != protocol.ItemAlphaWolfPelt {
		t.Fatalf("Falha ao equipar Pele de Lobo Alfa: ok=%v, armor=%d", ok, p.EquippedArmorID)
	}
	if p.GetItemCount(protocol.ItemAlphaWolfPelt) != 0 {
		t.Fatalf("Item equipado deveria ter sido removido do inventário")
	}
	if p.MaxHP != oldHP+35 {
		t.Fatalf("Esperava MaxHP %d (+35 da Pele Alfa), obteve %d", oldHP+35, p.MaxHP)
	}
	strAfter, _, _, _, _, _, _, _ := p.GetAttributes()
	if strAfter != strBefore+3 {
		t.Fatalf("Esperava FOR %d (+3 da Pele Alfa), obteve %d", strBefore+3, strAfter)
	}

	// Equipar Anel de Presa Ancestral (13): +3 DES, +3 AGI (+24 MaxStamina)
	oldStam := p.MaxStamina
	_, dexBefore, _, agiBefore, _, _, _, _ := p.GetAttributes()
	ok, _ = p.EquipItem(protocol.ItemAncestralFangRing)
	if !ok || p.EquippedAccessoryID != protocol.ItemAncestralFangRing {
		t.Fatalf("Falha ao equipar Anel: ok=%v, acc=%d", ok, p.EquippedAccessoryID)
	}
	_, dexAfter, _, agiAfter, _, _, _, _ := p.GetAttributes()
	if dexAfter != dexBefore+3 || agiAfter != agiBefore+3 {
		t.Fatalf("Esperava +3 DES e +3 AGI do Anel: DES %d->%d, AGI %d->%d", dexBefore, dexAfter, agiBefore, agiAfter)
	}
	if p.MaxStamina != oldStam+24 {
		t.Fatalf("Esperava MaxStamina %d (+24 por 3 AGI), obteve %d", oldStam+24, p.MaxStamina)
	}

	// Troca de Armadura: Adiciona e equipa Placa de Aço Pesada (12) -> deve devolver Pele Alfa para a mochila
	p.AddItem(protocol.ItemHeavySteelPlate, 1)
	ok, _ = p.EquipItem(protocol.ItemHeavySteelPlate)
	if !ok || p.EquippedArmorID != protocol.ItemHeavySteelPlate {
		t.Fatalf("Falha ao equipar Placa de Aço: ok=%v, armor=%d", ok, p.EquippedArmorID)
	}
	if p.GetItemCount(protocol.ItemAlphaWolfPelt) != 1 {
		t.Fatalf("Pele Alfa antiga deveria ter retornado à mochila")
	}

	// Desequipar armadura
	ok = p.UnequipItem("armor")
	if !ok || p.EquippedArmorID != 0 || p.GetItemCount(protocol.ItemHeavySteelPlate) != 1 {
		t.Fatalf("Falha ao desequipar armadura: ok=%v, armor=%d, count=%d", ok, p.EquippedArmorID, p.GetItemCount(protocol.ItemHeavySteelPlate))
	}
}

func TestPlayerConsumablesAndSecretTriggers(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)
	p.SetIdentity(protocol.RaceValerian, protocol.ClassSwordsman) // MaxHP = 150
	p.HP = 20
	p.Stamina = 10.0

	// Consumir Carne Crua de Lobo (2): +45 HP
	ok, _ := p.UseConsumable(protocol.ItemRawWolfMeat)
	if !ok || p.HP != 65 {
		t.Fatalf("Falha ao consumir Carne Crua: ok=%v, HP=%d", ok, p.HP)
	}
	if p.GetItemCount(protocol.ItemRawWolfMeat) != 1 {
		t.Fatalf("Esperava 1 carne restante, obteve %d", p.GetItemCount(protocol.ItemRawWolfMeat))
	}

	// Consumir Carne Nobre Assada (3): +90 HP, +40 Stamina
	p.AddItem(protocol.ItemCookedNobleMeat, 1)
	ok, _ = p.UseConsumable(protocol.ItemCookedNobleMeat)
	if !ok || p.HP != 150 || p.Stamina != 50.0 {
		t.Fatalf("Falha ao consumir Carne Nobre: ok=%v, HP=%d, Stam=%.1f", ok, p.HP, p.Stamina)
	}

	// Poção de Sangue Lupino (4): Buff de 20s
	p.AddItem(protocol.ItemWolfBloodPotion, 1)
	ok, _ = p.UseConsumable(protocol.ItemWolfBloodPotion)
	if !ok || !p.IsWolfPotionActive() {
		t.Fatalf("Falha ao ativar Poção Lupina: ok=%v, active=%v", ok, p.IsWolfPotionActive())
	}

	// Sangue do Progenitor Bestial (16): Desperta Dhampir (Raça 5)
	p.AddItem(protocol.ItemBeastProgenitorBlood, 1)
	ok, _ = p.UseConsumable(protocol.ItemBeastProgenitorBlood)
	if !ok || p.RaceID != protocol.RaceDhampir {
		t.Fatalf("Falha ao despertar Dhampir via item 16: ok=%v, race=%d", ok, p.RaceID)
	}

	// Tomo da Foice do Eclipse (17): Desperta Ceifador do Eclipse (Classe 7), Tier 5 Única, Nível 1 Reset
	p.AddLevel(10) // Nível 11
	p.AddItem(protocol.ItemEclipseScytheTome, 1)
	ok, _ = p.UseConsumable(protocol.ItemEclipseScytheTome)
	if !ok || p.ClassID != protocol.ClassEclipseReaper || p.ClassTier != protocol.TierUnique || p.Level != 1 {
		t.Fatalf("Falha ao despertar Ceifador via Tomo: ok=%v, class=%d, tier=%d, level=%d",
			ok, p.ClassID, p.ClassTier, p.Level)
	}

	// Núcleo de Forja Estelar (18): Desperta Artífice Rúnico (Classe 8), Tier 5 Única, Nível 1 Reset
	p.AddLevel(5) // Nível 6
	p.AddItem(protocol.ItemStarforgeCore, 1)
	ok, _ = p.UseConsumable(protocol.ItemStarforgeCore)
	if !ok || p.ClassID != protocol.ClassRunicArtificer || p.ClassTier != protocol.TierUnique || p.Level != 1 {
		t.Fatalf("Falha ao despertar Artífice via Núcleo: ok=%v, class=%d, tier=%d, level=%d",
			ok, p.ClassID, p.ClassTier, p.Level)
	}

	// Despertar da Raça Secreta Revenant (7): +50 MaxHP
	prevHP := p.MaxHP
	p.EvolveToRevenant()
	if p.RaceID != protocol.RaceRevenant {
		t.Fatalf("Esperava Raça Revenant (7), obteve %d", p.RaceID)
	}
	if p.MaxHP < prevHP+50 {
		t.Fatalf("Revenant deveria ter concedido +50 MaxHP: antes %d, depois %d", prevHP, p.MaxHP)
	}
}

func TestRPGEvolutionAndTierScaling(t *testing.T) {
	// 1. Testa Atributos Base por Raça Inicial
	races := []struct {
		raceID uint8
		s, d, c, a, i, sp, m, l uint8
	}{
		{protocol.RaceValerian, 6, 6, 6, 6, 6, 6, 7, 7},
		{protocol.RaceNoctari, 4, 8, 4, 8, 9, 7, 5, 5},
		{protocol.RaceKharad, 9, 4, 10, 3, 4, 6, 9, 5},
		{protocol.RaceVarkai, 8, 7, 7, 8, 3, 4, 6, 7},
	}

	for _, tc := range races {
		p := NewPlayer(1, nil, 0, 1.5, 0)
		p.SetIdentityMode(tc.raceID, 0, protocol.IdentityModeInitialChange)
		str, dex, con, agi, intStat, spi, mas, lck := p.GetAttributes()
		if str != tc.s || dex != tc.d || con != tc.c || agi != tc.a || intStat != tc.i || spi != tc.sp || mas != tc.m || lck != tc.l {
			t.Fatalf("Atributos da Raça %d divergentes: obtido (%d,%d,%d,%d,%d,%d,%d,%d)",
				tc.raceID, str, dex, con, agi, intStat, spi, mas, lck)
		}
	}

	// 2. Testa Escala de StatPoints por Tier (0 a 6)
	expectedPoints := map[uint8]uint8{
		protocol.TierTraveler:  3,
		protocol.TierCommon:    5,
		protocol.TierUncommon:  6,
		protocol.TierRare:      7,
		protocol.TierEpic:      8,
		protocol.TierUnique:    11,
		protocol.TierLegendary: 15,
	}
	for tier, pts := range expectedPoints {
		if StatPointsPerLevel(tier) != pts {
			t.Fatalf("Tier %d deveria conceder %d pontos/nível, obteve %d", tier, pts, StatPointsPerLevel(tier))
		}
	}

	// 3. Testa Cooldown e Execução de Habilidade Racial (ActionType 6 - Tecla Z)
	p := NewPlayer(1, nil, 0, 1.5, 0)
	if !p.CanPerformAction(protocol.ActionRacialSkill) {
		t.Fatalf("Deveria poder executar ActionRacialSkill inicialmente")
	}
	p.RecordAction(protocol.ActionRacialSkill)
	if p.CanPerformAction(protocol.ActionRacialSkill) {
		t.Fatalf("ActionRacialSkill deve entrar em cooldown de 10s!")
	}

	// 4. Testa RestoreStamina
	p.Stamina = 10.0
	p.RestoreStamina(40.0)
	if p.Stamina != 50.0 {
		t.Fatalf("Esperava 50.0 de stamina após RestoreStamina(40), obteve %.1f", p.Stamina)
	}

	// 5. Testa Reset de Provação Lendária ao Morrer
	p.LegendaryQuestActive = true
	p.LegendaryQuestKills = 2
	p.Respawn(0, 1.5, 0)
	if p.LegendaryQuestKills != 0 {
		t.Fatalf("Morte deve zerar os abates da provação lendária! Obteve %d", p.LegendaryQuestKills)
	}
}

func TestNPCFriendshipAndSecretRecipe(t *testing.T) {
	p := NewPlayer(10, nil, 0, 1.5, 0)

	// 1. Testa Ganho de Afiança e Limites (0 a 100)
	if p.GetFriendship(100) != 0 || p.GetFriendshipLevel(100) != 0 {
		t.Fatalf("Afiança inicial deveria ser 0, obteve %d", p.GetFriendship(100))
	}

	// Conversa Diária (+5)
	pts := AddFriendship(p, 100, 5)
	if pts != 5 || p.GetFriendship(100) != 5 || GetFriendshipLevel(p, 100) != 0 {
		t.Fatalf("Esperava 5 pontos (Nível 0), obteve %d (Nível %d)", pts, p.GetFriendshipLevel(100))
	}

	// Presentes de Minério (+20 cada)
	AddFriendship(p, 100, 20) // 25 (Nível 1)
	if p.GetFriendshipLevel(100) != 1 {
		t.Fatalf("25 pontos deveria ser Nível 1, obteve %d", p.GetFriendshipLevel(100))
	}

	AddFriendship(p, 100, 20) // 45 (Nível 2)
	if p.GetFriendshipLevel(100) != 2 {
		t.Fatalf("45 pontos deveria ser Nível 2, obteve %d", p.GetFriendshipLevel(100))
	}

	AddFriendship(p, 100, 25) // 70 (Nível 3 - Qualificado para Receita Secreta de Garrick)
	if p.GetFriendshipLevel(100) != 3 || p.GetFriendship(100) < 70 {
		t.Fatalf("70 pontos deveria ser Nível 3, obteve %d (pts: %d)", p.GetFriendshipLevel(100), p.GetFriendship(100))
	}

	// Limite Máximo 100 (Nível 5)
	AddFriendship(p, 100, 50) // 120 -> clamp para 100
	if p.GetFriendship(100) != 100 || p.GetFriendshipLevel(100) != 5 {
		t.Fatalf("Afiança máxima deveria ser 100 (Nível 5), obteve %d (Nível %d)", p.GetFriendship(100), p.GetFriendshipLevel(100))
	}

	// Limite Mínimo 0
	AddFriendship(p, 100, -200) // -> clamp para 0
	if p.GetFriendship(100) != 0 || p.GetFriendshipLevel(100) != 0 {
		t.Fatalf("Afiança mínima deveria ser 0, obteve %d", p.GetFriendship(100))
	}

	// 2. Testa Desbloqueio e Forja do Malho de Batalha Rúnico (Item 26 -> Item 27)
	p.SetIdentityMode(protocol.RaceValerian, protocol.ClassBlacksmith, protocol.IdentityModeInitialChange)
	p.AddItem(protocol.ItemRunicWarhammerRecipe, 1)

	ok, msg := p.UseConsumable(protocol.ItemRunicWarhammerRecipe)
	if !ok || !p.HasUnlockedRecipe(protocol.ItemRunicWarhammerRecipe) {
		t.Fatalf("Falha ao forjar Malho Rúnico via receita: ok=%v, msg=%s", ok, msg)
	}
	if p.GetItemCount(protocol.ItemRunicWarhammer) != 1 {
		t.Fatalf("Deveria ter recebido 1x Malho de Batalha Rúnico no inventário!")
	}

	// Equipar o Malho de Batalha Rúnico
	strBefore, _, conBefore, _, _, _, _, _ := p.GetAttributes()
	ok, _ = p.EquipItem(protocol.ItemRunicWarhammer)
	if !ok || p.EquippedAccessoryID != protocol.ItemRunicWarhammer {
		t.Fatalf("Falha ao equipar Malho Rúnico: ok=%v", ok)
	}
	strAfter, _, conAfter, _, _, _, _, _ := p.GetAttributes()
	if strAfter != strBefore+8 || conAfter != conBefore+6 {
		t.Fatalf("Malho Rúnico deveria conceder +8 FOR e +6 CON: antes (%d,%d), depois (%d,%d)",
			strBefore, conBefore, strAfter, conAfter)
	}
}

func TestAll46RacesBaseAttributes(t *testing.T) {
	testCases := []struct {
		raceID uint8
		str    uint8
		dex    uint8
		con    uint8
		agi    uint8
		intVal uint8
		spi    uint8
		mas    uint8
		lck    uint8
	}{
		// Raças Base
		{protocol.RaceValerian, 6, 6, 6, 6, 6, 6, 7, 7},
		{protocol.RaceNoctari, 4, 8, 4, 8, 9, 7, 5, 5},
		{protocol.RaceKharad, 9, 4, 10, 3, 4, 6, 9, 5},
		{protocol.RaceVarkai, 8, 7, 7, 8, 3, 4, 6, 7},
		// 6 Raças Secretas Originais
		{protocol.RaceDhampir, 8, 9, 6, 9, 8, 3, 6, 6},
		{protocol.RacePrimordialLycanthrope, 12, 9, 11, 10, 2, 3, 7, 6},
		{protocol.RaceRevenant, 7, 6, 9, 5, 9, 10, 6, 3},
		{protocol.RaceCelestial, 6, 6, 7, 7, 10, 12, 6, 8},
		{protocol.RaceAbyssal, 6, 7, 8, 6, 12, 8, 6, 5},
		{protocol.RaceRunicAutomaton, 10, 5, 12, 4, 8, 6, 10, 4},
		// Evoluções Ordem/Caos
		{protocol.RaceHighValerian, 10, 8, 9, 8, 9, 9, 9, 9},
		{protocol.RaceAetherWalker, 8, 10, 7, 12, 10, 8, 10, 10},
		{protocol.RaceLunarArchon, 5, 11, 6, 11, 14, 11, 8, 8},
		{protocol.RaceUmbralSpecter, 6, 13, 5, 14, 12, 9, 11, 9},
		{protocol.RaceRunicGuardian, 13, 6, 15, 5, 7, 9, 12, 7},
		{protocol.RaceObsidianTitan, 15, 5, 17, 4, 6, 7, 10, 6},
		{protocol.RaceDraconicSovereign, 13, 10, 11, 11, 6, 7, 9, 10},
		{protocol.RaceFrenzyBeast, 14, 11, 10, 13, 4, 5, 10, 11},
		// As 10 Novas Raças
		{protocol.RaceSylvari, 5, 7, 8, 6, 8, 10, 6, 5},
		{protocol.RaceMyconid, 4, 5, 10, 4, 10, 9, 8, 5},
		{protocol.RaceArachne, 6, 11, 5, 10, 7, 4, 12, 5},
		{protocol.RaceAshDragonborn, 12, 5, 12, 5, 8, 6, 6, 4},
		{protocol.RaceChimera, 9, 8, 9, 8, 6, 2, 10, 5},
		{protocol.RaceBoreal, 8, 6, 9, 5, 9, 8, 6, 4},
		{protocol.RaceThalassian, 7, 8, 7, 9, 9, 8, 5, 5},
		{protocol.RaceCambion, 11, 8, 8, 7, 9, 2, 5, 6},
		{protocol.RaceNephilim, 9, 9, 8, 8, 10, 10, 7, 7},
		{protocol.RaceTimeWanderer, 5, 10, 5, 12, 12, 9, 8, 9},
		// 18 Novas Raças do RPG (29 a 46)
		{protocol.RaceHalfCelestial, 8, 8, 8, 8, 9, 11, 7, 7},
		{protocol.RacePyromancer, 6, 8, 7, 8, 12, 6, 7, 6},
		{protocol.RaceFrostGiant, 14, 4, 15, 4, 6, 6, 9, 4},
		{protocol.RaceDragonEarth, 12, 5, 14, 4, 5, 6, 10, 5},
		{protocol.RaceDragonWater, 8, 9, 9, 8, 9, 9, 7, 7},
		{protocol.RaceDragonLightning, 8, 11, 7, 12, 10, 5, 8, 7},
		{protocol.RaceDragonMystic, 6, 8, 8, 7, 13, 10, 6, 6},
		{protocol.RaceOrc, 13, 6, 13, 6, 3, 3, 9, 5},
		{protocol.RaceDwarf, 11, 5, 13, 4, 6, 7, 12, 5},
		{protocol.RaceElf, 5, 11, 5, 12, 10, 8, 7, 6},
		{protocol.RaceSolarElf, 6, 10, 6, 10, 11, 10, 7, 7},
		{protocol.RaceLunarElf, 5, 11, 5, 12, 10, 8, 8, 8},
		{protocol.RaceFairy, 3, 10, 4, 13, 11, 11, 5, 10},
		{protocol.RaceGoblin, 6, 12, 5, 13, 6, 3, 10, 12},
		{protocol.RaceScorpionDemi, 9, 10, 8, 10, 7, 3, 11, 6},
		{protocol.RaceTurtleDemi, 9, 4, 16, 3, 6, 8, 9, 5},
		{protocol.RaceHalfDemon, 8, 10, 7, 10, 11, 4, 8, 8},
		{protocol.RaceWolfDemi, 12, 9, 10, 11, 3, 4, 8, 7},
		{protocol.RaceManamancer, 3, 6, 8, 6, 13, 11, 7, 4},
	}

	for _, tc := range testCases {
		s, d, c, a, i, sp, m, l := GetBaseRaceAttributes(tc.raceID)
		if s != tc.str || d != tc.dex || c != tc.con || a != tc.agi ||
			i != tc.intVal || sp != tc.spi || m != tc.mas || l != tc.lck {
			t.Fatalf("Raça ID %d atributos incorretos! Esperado: STR %d, DEX %d, CON %d, AGI %d, INT %d, SPI %d, MAS %d, LCK %d. Obteve: STR %d, DEX %d, CON %d, AGI %d, INT %d, SPI %d, MAS %d, LCK %d",
				tc.raceID, tc.str, tc.dex, tc.con, tc.agi, tc.intVal, tc.spi, tc.mas, tc.lck,
				s, d, c, a, i, sp, m, l)
		}
	}
}

func Test12EquipmentSlotsAndRingRotation(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)

	// Adiciona itens de teste para os 12 slots
	p.AddItem(protocol.ItemVigilHelmet, 1)
	p.AddItem(protocol.ItemSteelChestplate, 1)
	p.AddItem(protocol.ItemWolfLeatherPants, 1)
	p.AddItem(protocol.ItemMistwalkerBoots, 1)
	p.AddItem(protocol.ItemBlacksmithGauntlets, 1)
	p.AddItem(protocol.ItemAlchemistBelt, 1)
	p.AddItem(protocol.ItemSilverMoonAmulet, 1)
	p.AddItem(protocol.ItemAlphaPeltCloak, 1)

	// 4 Anéis diferentes
	p.AddItem(protocol.ItemAncestralFangRing, 1)
	p.AddItem(protocol.ItemBloodRubyRing, 1)
	p.AddItem(protocol.ItemObsidianRing, 1)
	p.AddItem(protocol.ItemStarlightRing, 1)
	p.AddItem(protocol.ItemAncestralFangRing, 1) // 5º anel para testar rotação FIFO

	// Equipa slots fixos
	slotsToEquip := []uint8{
		protocol.ItemVigilHelmet,
		protocol.ItemSteelChestplate,
		protocol.ItemWolfLeatherPants,
		protocol.ItemMistwalkerBoots,
		protocol.ItemBlacksmithGauntlets,
		protocol.ItemAlchemistBelt,
		protocol.ItemSilverMoonAmulet,
		protocol.ItemAlphaPeltCloak,
	}

	for _, item := range slotsToEquip {
		ok, msg := p.EquipItem(item)
		if !ok {
			t.Fatalf("Falha ao equipar item %d: %s", item, msg)
		}
	}

	slots := p.GetEquippedSlots()
	if slots[protocol.SlotHelmet] != protocol.ItemVigilHelmet ||
		slots[protocol.SlotChest] != protocol.ItemSteelChestplate ||
		slots[protocol.SlotLegs] != protocol.ItemWolfLeatherPants ||
		slots[protocol.SlotBoots] != protocol.ItemMistwalkerBoots ||
		slots[protocol.SlotGloves] != protocol.ItemBlacksmithGauntlets ||
		slots[protocol.SlotBelt] != protocol.ItemAlchemistBelt ||
		slots[protocol.SlotAmulet] != protocol.ItemSilverMoonAmulet ||
		slots[protocol.SlotCloak] != protocol.ItemAlphaPeltCloak {
		t.Fatalf("Slots fixos não correspondem aos itens equipados: %+v", slots)
	}

	// Equipa 4 Anéis nos slots [7, 8, 9, 10]
	rings := []uint8{
		protocol.ItemAncestralFangRing,
		protocol.ItemBloodRubyRing,
		protocol.ItemObsidianRing,
		protocol.ItemStarlightRing,
	}

	for _, ring := range rings {
		ok, msg := p.EquipItem(ring)
		if !ok {
			t.Fatalf("Falha ao equipar anel %d: %s", ring, msg)
		}
	}

	slots = p.GetEquippedSlots()
	if slots[7] != protocol.ItemAncestralFangRing ||
		slots[8] != protocol.ItemBloodRubyRing ||
		slots[9] != protocol.ItemObsidianRing ||
		slots[10] != protocol.ItemStarlightRing {
		t.Fatalf("Os 4 anéis deveriam ocupar slots [7, 8, 9, 10]. Obteve: %d, %d, %d, %d",
			slots[7], slots[8], slots[9], slots[10])
	}

	// Equipa 5º anel (outro AncestralFangRing) para testar a rotação FIFO
	ok, msg := p.EquipItem(protocol.ItemAncestralFangRing)
	if !ok {
		t.Fatalf("Falha ao rotacionar anel: %s", msg)
	}

	slots = p.GetEquippedSlots()
	// Esperado: antigo slot 7 (AncestralFangRing) voltou ao inventário, slots rotacionaram:
	// novo 7 = BloodRubyRing, novo 8 = ObsidianRing, novo 9 = StarlightRing, novo 10 = AncestralFangRing
	if slots[7] != protocol.ItemBloodRubyRing ||
		slots[8] != protocol.ItemObsidianRing ||
		slots[9] != protocol.ItemStarlightRing ||
		slots[10] != protocol.ItemAncestralFangRing {
		t.Fatalf("Rotação de anéis incorreta! Obteve: [7]=%d, [8]=%d, [9]=%d, [10]=%d",
			slots[7], slots[8], slots[9], slots[10])
	}

	if p.GetItemCount(protocol.ItemAncestralFangRing) != 1 {
		t.Fatalf("O anel descartado da posição 7 deveria ter retornado ao inventário!")
	}

	// Testa desequipar por slot index
	if !p.UnequipSlot(protocol.SlotHelmet) {
		t.Fatalf("Falha ao desequipar capacete!")
	}
	if p.GetEquippedSlots()[protocol.SlotHelmet] != 0 {
		t.Fatalf("Capacete deveria estar vazio (0)!")
	}
}

func TestDevSetRaceAndKit(t *testing.T) {
	p := NewPlayer(2, nil, 0, 0, 0)
	p.DevSetRaceAndKit(protocol.RaceTimeWanderer, protocol.ClassEclipseReaper)

	if p.RaceID != protocol.RaceTimeWanderer {
		t.Fatalf("DevSetRaceAndKit: RaceID esperada %d, obteve %d", protocol.RaceTimeWanderer, p.RaceID)
	}

	slots := p.GetEquippedSlots()
	for i := 0; i < 12; i++ {
		if slots[i] == 0 {
			t.Fatalf("DevSetRaceAndKit: slot %d está vazio!", i)
		}
	}

	if p.GetItemCount(protocol.ItemRunicHourglass) != 1 ||
		p.GetItemCount(protocol.ItemSilverSilkCocoon) != 1 ||
		p.GetItemCount(protocol.ItemOrganicTrash) != 3 {
		t.Fatalf("DevSetRaceAndKit: kit de itens de teste incompleto no inventário!")
	}

	// Testa todas as 46 raças aceitas pelo comando Dev
	for rid := uint8(1); rid <= 46; rid++ {
		p.DevSetRaceAndKit(rid, protocol.ClassSwordsman)
		if p.RaceID != rid {
			t.Fatalf("DevSetRaceAndKit falhou para raça %d!", rid)
		}
	}
}

func TestAutopsyProtectionFlag(t *testing.T) {
	p := NewPlayer(3, nil, 0, 0, 0)
	if p.IsInAutopsy() {
		t.Fatalf("Jogador não deveria estar em autópsia inicialmente!")
	}

	p.SetInAutopsy(true)
	if !p.IsInAutopsy() {
		t.Fatalf("Jogador deveria estar protegido durante a autópsia!")
	}

	p.SetInAutopsy(false)
	if p.IsInAutopsy() {
		t.Fatalf("Jogador não deveria mais estar em autópsia após SetInAutopsy(false)!")
	}
}

func TestTimeWandererRewindDestiny(t *testing.T) {
	p := NewPlayer(4, nil, 10.0, 1.5, 20.0)
	p.RaceID = protocol.RaceTimeWanderer
	p.HP = 200
	p.MaxHP = 200
	p.Stamina = 100.0

	// Grava um snapshot simulado
	p.RecordTimeSnapshot(10.0, 1.5, 20.0, 200, 100.0)

	// Simula dano e deslocamento
	p.HP = 50
	p.Stamina = 20.0
	p.PosX = 40.0
	p.PosZ = 50.0

	snap, _ := p.RewindTimeDestiny()
	if p.HP < 130 {
		t.Fatalf("HP após rebobinar deveria ter subido para no mínimo 130, obteve %d", p.HP)
	}
	if p.Stamina < 100.0 {
		t.Fatalf("Stamina após rebobinar deveria ter sido restaurada, obteve %.1f", p.Stamina)
	}
	if snap.HP == 0 {
		t.Fatalf("Snapshot retornado inválido!")
	}
}

func TestConsumablesNewRaces(t *testing.T) {
	p := NewPlayer(5, nil, 0, 0, 0)

	// 1. Esporiano com Lixo Orgânico
	p.RaceID = protocol.RaceValerian
	p.AddItem(protocol.ItemOrganicTrash, 1)
	ok, _ := p.UseConsumable(protocol.ItemOrganicTrash)
	if ok {
		t.Fatalf("Apenas Myconids deveriam poder comer lixo orgânico!")
	}

	p.RaceID = protocol.RaceMyconid
	p.HP = 50
	ok, msg := p.UseConsumable(protocol.ItemOrganicTrash)
	if !ok || p.HP < 100 {
		t.Fatalf("Myconid falhou ao comer lixo orgânico: ok=%v, msg=%s, hp=%d", ok, msg, p.HP)
	}

	// 2. Quimera com Carnes
	p.RaceID = protocol.RaceChimera
	p.HP = 10
	p.AddItem(protocol.ItemRawWolfMeat, 1)
	ok, _ = p.UseConsumable(protocol.ItemRawWolfMeat)
	if !ok || p.HP != 100 { // 10 + 90 (dobro de 45) = 100
		t.Fatalf("Quimera deveria receber 90 HP da carne crua! Obteve: %d", p.HP)
	}

	// 3. Despertar Aracne com Casulo de Seda Prateada
	p.AddItem(protocol.ItemSilverSilkCocoon, 1)
	ok, _ = p.UseConsumable(protocol.ItemSilverSilkCocoon)
	if !ok || p.RaceID != protocol.RaceArachne {
		t.Fatalf("Falha ao despertar Aracne via casulo de seda!")
	}

	// 4. Despertar Errante Temporal com Ampulheta Rúnica
	p.AddItem(protocol.ItemRunicHourglass, 1)
	ok, _ = p.UseConsumable(protocol.ItemRunicHourglass)
	if !ok || p.RaceID != protocol.RaceTimeWanderer {
		t.Fatalf("Falha ao despertar Errante Temporal via ampulheta!")
	}
}

func TestNewMasterNPCsFriendshipAndClasses(t *testing.T) {
	p := NewPlayer(99, nil, 0, 1.5, 0)

	// Valida afiança inicial 0 para os 4 novos mestres
	newMasters := []uint32{107, 108, 109, 110}
	for _, id := range newMasters {
		if p.GetFriendship(id) != 0 || p.GetFriendshipLevel(id) != 0 {
			t.Fatalf("NPC %d deveria iniciar com 0 afiança, obteve %d", id, p.GetFriendship(id))
		}
		// Incrementa conversa (+5)
		pts := AddFriendship(p, id, 5)
		if pts != 5 || p.GetFriendship(id) != 5 {
			t.Fatalf("Esperava 5 pontos de amizade com NPC %d, obteve %d", id, pts)
		}
		// Adiciona +40 pontos (Nível 2)
		AddFriendship(p, id, 40)
		if p.GetFriendshipLevel(id) != 2 {
			t.Fatalf("NPC %d deveria estar em Nível 2 com 45 pontos, obteve Nível %d", id, p.GetFriendshipLevel(id))
		}
	}

	// Testa transição de classes ensinadas pelos novos mestres:
	// Seraphina (107) -> Acólito (ClassID = 4)
	p.SetIdentityMode(protocol.RaceValerian, protocol.ClassAcolyte, protocol.IdentityModeInitialChange)
	if p.ClassID != protocol.ClassAcolyte {
		t.Fatalf("Falha ao definir classe Acólito para jogador!")
	}

	// Aurelius (108) -> Iniciado (ClassID = 3)
	p.SetIdentityMode(protocol.RaceValerian, protocol.ClassInitiate, protocol.IdentityModeInitialChange)
	if p.ClassID != protocol.ClassInitiate {
		t.Fatalf("Falha ao definir classe Iniciado para jogador!")
	}

	// Kaelen (109) -> Batedor (ClassID = 2)
	p.SetIdentityMode(protocol.RaceValerian, protocol.ClassScout, protocol.IdentityModeInitialChange)
	if p.ClassID != protocol.ClassScout {
		t.Fatalf("Falha ao definir classe Batedor para jogador!")
	}
}

func TestSecretClasses10to15AndDevDirect(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)

	// 1. Testa IdentityModeDevDirect (ActionMode 98) para todas as 15 classes e 6 tiers
	for cid := uint8(1); cid <= 15; cid++ {
		p.SetIdentityMode(protocol.TierLegendary, cid, protocol.IdentityModeDevDirect)
		if p.ClassID != cid {
			t.Fatalf("ActionMode 98 deveria definir ClassID=%d, obteve %d", cid, p.ClassID)
		}
		if p.ClassTier != protocol.TierLegendary {
			t.Fatalf("ActionMode 98 deveria definir ClassTier=%d, obteve %d", protocol.TierLegendary, p.ClassTier)
		}
	}

	// 2. Testa Despertar Secreto (ActionMode 2) para Classes 10 a 15
	secretClasses := []uint8{
		protocol.ClassAstralDancer,
		protocol.ClassAshInquisitor,
		protocol.ClassBoneNecromancer,
		protocol.ClassPrimordialTamer,
		protocol.ClassRiftKnight,
		protocol.ClassStormHerald,
	}

	for _, sc := range secretClasses {
		p.Level = 25
		p.XP = 500
		p.SetIdentityMode(protocol.RaceValerian, sc, protocol.IdentityModeSecretReset)

		if p.ClassID != sc {
			t.Fatalf("Esperava ClassID=%d, obteve %d", sc, p.ClassID)
		}
		if p.ClassTier != protocol.TierUnique {
			t.Fatalf("Classe secreta deveria iniciar no Tier 5 Única (%d), obteve %d", protocol.TierUnique, p.ClassTier)
		}
		if p.Level != 1 {
			t.Fatalf("Classe secreta deveria resetar para Nível 1, obteve Nível %d", p.Level)
		}

		// Testa ganho de +11 StatPoints por nível no Tier 5 Única
		ptsBefore := p.StatPoints
		p.AddLevel(1)
		ptsGained := p.StatPoints - ptsBefore
		if ptsGained != 11 {
			t.Fatalf("No Tier 5 Única deveria ganhar +11 StatPoints por nível, ganhou %d", ptsGained)
		}

		// Testa Evolução para Tier 6 Lendária mantendo nível
		lvlBeforeEvolve := p.Level
		p.SetIdentityMode(protocol.RaceValerian, sc, protocol.IdentityModeEvolveClass)
		if p.ClassTier != protocol.TierLegendary {
			t.Fatalf("Evolução de classe secreta deveria subir para Tier 6 Lendária (%d), obteve %d", protocol.TierLegendary, p.ClassTier)
		}
		if p.Level != lvlBeforeEvolve {
			t.Fatalf("Evolução não deveria alterar nível: antes=%d, depois=%d", lvlBeforeEvolve, p.Level)
		}

		// No Tier 6 Lendária ganha +15 StatPoints por nível
		ptsBeforeT6 := p.StatPoints
		p.AddLevel(1)
		ptsGainedT6 := p.StatPoints - ptsBeforeT6
		if ptsGainedT6 != 15 {
			t.Fatalf("No Tier 6 Lendária deveria ganhar +15 StatPoints por nível, ganhou %d", ptsGainedT6)
		}
	}

	// 3. Testa Rastreamento dos Desafios de Obtenção e Reset de UntouchedKills
	p.UntouchedKills = 10
	p.LowHPKills = 3
	p.PerfectAutopsiesStreak = 5
	p.SoloAlphaWolfKilled = true
	p.BlockedBossRupture = true

	if p.UntouchedKills != 10 || p.LowHPKills != 3 || p.PerfectAutopsiesStreak != 5 || !p.SoloAlphaWolfKilled || !p.BlockedBossRupture {
		t.Fatalf("Falha na inicialização dos campos de desafios do jogador")
	}

	// Ao sofrer dano, UntouchedKills deve zerar
	p.TakeDamage(10)
	if p.UntouchedKills != 0 {
		t.Fatalf("UntouchedKills deveria ter zerado após sofrer dano, valor atual: %d", p.UntouchedKills)
	}

	// 4. Testa Passiva de -30% Dano Recebido do Cavaleiro da Ruptura (Classe 14)
	p.SetIdentityMode(protocol.TierCommon, protocol.ClassRiftKnight, protocol.IdentityModeDevDirect)
	p.HP = 200
	p.TakeDamage(100) // 100 * 0.70 = 70 de dano efetivo
	expectedHP := uint16(200 - 70)
	if p.HP != expectedHP {
		t.Fatalf("Passiva Cavaleiro da Ruptura deveria reduzir 30%% do dano (esperava HP %d, obteve %d)", expectedHP, p.HP)
	}
}

func TestDevControlLevelAndStats(t *testing.T) {
	p := NewPlayer(1, nil, 0, 1.5, 0)
	p.ClassTier = protocol.TierCommon // 5 StatPoints por nível

	// Teste val = 1 (+1 nível)
	p.DevControlLevelAndStats(1)
	if p.Level != 2 || p.StatPoints != 5 {
		t.Fatalf("esperava Level 2 e 5 StatPoints, obteve Lvl %d e %d pts", p.Level, p.StatPoints)
	}

	// Teste val = 5 (+5 níveis)
	p.DevControlLevelAndStats(5)
	if p.Level != 7 || p.StatPoints != 30 {
		t.Fatalf("esperava Level 7 e 30 StatPoints, obteve Lvl %d e %d pts", p.Level, p.StatPoints)
	}

	// Teste val = 50 (Nível 50)
	p.DevControlLevelAndStats(50)
	if p.Level != 50 {
		t.Fatalf("esperava Level 50, obteve %d", p.Level)
	}

	// Teste val = 99 (Full Heal + 20 StatPoints)
	p.HP = 10
	p.Stamina = 5.0
	p.DevControlLevelAndStats(0) // Reseta para Nível 1
	p.DevControlLevelAndStats(99)
	if p.HP != p.MaxHP || p.Stamina != float32(p.MaxStamina) {
		t.Fatalf("esperava HP e Stamina cheios após val=99")
	}
	if p.StatPoints != 20 {
		t.Fatalf("esperava 20 StatPoints após val=99, obteve %d", p.StatPoints)
	}

	// Aloca alguns atributos antes do reset
	p.AllocateStat(protocol.StatIDSTR)
	p.AllocateStat(protocol.StatIDCON)
	if p.AllocSTR != 1 || p.AllocCON != 1 {
		t.Fatalf("atributos alocados incorretos")
	}

	// Teste val = 0 (Reset para Nível 1 e atributos zerados)
	p.DevControlLevelAndStats(0)
	if p.Level != 1 || p.StatPoints != 0 || p.AllocSTR != 0 || p.AllocCON != 0 {
		t.Fatalf("esperava Level 1 e atributos limpos após val=0, obteve Lvl %d, AllocSTR %d, AllocCON %d", p.Level, p.AllocSTR, p.AllocCON)
	}
}



func TestBasicClassDefensivePassives(t *testing.T) {
	// Guerreiro (Sangue de Batalha): +15% de Defesa Física -> 100 vira 85
	w := NewPlayer(1, nil, 0, 0, 0)
	w.SetIdentity(protocol.RaceValerian, protocol.ClassWarrior)
	hp := w.HP
	if newHP, _ := w.TakeDamage(100); newHP != hp-85 {
		t.Fatalf("Guerreiro: esperava HP %d, obteve %d", hp-85, newHP)
	}

	// Escudeiro (Fortaleza Viva): +35% de Defesa Total -> 100 vira 65
	sb := NewPlayer(2, nil, 0, 0, 0)
	sb.SetIdentity(protocol.RaceValerian, protocol.ClassShieldBearer)
	hp = sb.HP
	if newHP, _ := sb.TakeDamage(100); newHP != hp-65 {
		t.Fatalf("Escudeiro: esperava HP %d, obteve %d", hp-65, newHP)
	}
}

func TestIdentityOfferRequiresConfirmation(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.SetIdentity(protocol.RaceValerian, protocol.ClassWarrior)
	p.AddLevel(9)

	// Oferta pendente não muda nada sozinha (equivale a Cancelar no modal)
	p.OfferIdentity(p.RaceID, protocol.ClassEclipseReaper, protocol.IdentityModeSecretReset)
	if p.ClassID != protocol.ClassWarrior || p.Level != 10 {
		t.Fatalf("a oferta não deveria mudar nada antes da confirmação: classe %d, nível %d", p.ClassID, p.Level)
	}

	// Confirmar outra classe é recusado e descarta a oferta
	if p.AcceptIdentityOffer(protocol.ClassAstralDancer) {
		t.Fatal("confirmação de classe diferente da oferecida deveria ser recusada")
	}
	if p.AcceptIdentityOffer(protocol.ClassEclipseReaper) {
		t.Fatal("a oferta já descartada não deveria valer de novo")
	}

	// Oferta confirmada: Classe Única com reset para o nível 1
	p.OfferIdentity(p.RaceID, protocol.ClassEclipseReaper, protocol.IdentityModeSecretReset)
	if !p.AcceptIdentityOffer(protocol.ClassEclipseReaper) {
		t.Fatal("a confirmação da classe oferecida deveria ser aceita")
	}
	if p.ClassID != protocol.ClassEclipseReaper || p.ClassTier != protocol.TierUnique || p.Level != 1 {
		t.Fatalf("esperava Ceifador Tier 5 no nível 1, obteve classe %d tier %d nível %d", p.ClassID, p.ClassTier, p.Level)
	}
}

func TestEvolutionPathsMultipliersAndChoice(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.SetIdentity(protocol.RaceValerian, protocol.ClassShieldBearer)
	if p.NeedsPathChoice() {
		t.Fatal("no Tier 1 ainda não há Caminho a escolher")
	}
	p.AddLevel(9) // Nível 10 -> Tier 2 Incomum
	if p.ClassTier != protocol.TierUncommon || !p.NeedsPathChoice() {
		t.Fatalf("no Tier 2 o jogador deve escolher o Caminho (tier %d, precisa=%v)", p.ClassTier, p.NeedsPathChoice())
	}
	baseHP := p.MaxHP

	// Escudeiro Caminho 1 (Guardião ➔ Égide Imortal): +30% HP, +25% Defesa, -15% Dano
	p.SetIdentityMode(protocol.TierUncommon, protocol.ClassShieldBearer, protocol.IdentityModeDevDirect, 1)
	if p.SubPath != 1 || p.NeedsPathChoice() {
		t.Fatalf("Caminho 1 deveria estar ativo, obteve %d", p.SubPath)
	}
	if p.MaxHP != uint16(float32(baseHP)*1.30) {
		t.Fatalf("Guardião: esperava HP %d (+30%%), obteve %d", uint16(float32(baseHP)*1.30), p.MaxHP)
	}
	if m := p.PathDamageMult(); m != 0.85 {
		t.Fatalf("Guardião: esperava dano x0.85, obteve %.2f", m)
	}
	hp := p.HP
	// 100 de dano: defesa do caminho (/1.25 = 80) e depois a passiva do Escudeiro (x0.65 = 52)
	if newHP, _ := p.TakeDamage(100); newHP != hp-52 {
		t.Fatalf("Guardião: esperava HP %d após 100 de dano, obteve %d", hp-52, newHP)
	}

	// Trocar de classe exige escolher o Caminho de novo
	p.SetIdentityMode(0, protocol.ClassWarrior, protocol.IdentityModeInitialChange)
	if p.SubPath != 0 || !p.NeedsPathChoice() {
		t.Fatalf("depois de trocar de classe o Caminho deveria zerar (SubPath %d)", p.SubPath)
	}
}

func TestSecretVariantRequirementsKeepLevel(t *testing.T) {
	p := NewPlayer(1, nil, 0, 0, 0)
	p.SetIdentity(protocol.RaceValerian, protocol.ClassBlacksmith)
	p.AddLevel(29) // Nível 30

	if ok, _ := p.CanAwakenVariant(protocol.ClassRunicSpellblade); ok {
		t.Fatal("Ferreiro não pode despertar o Espadachim Rúnico (exige Guerreiro ou Mago)")
	}
	if ok, why := p.CanAwakenVariant(protocol.ClassCursedSmith); !ok {
		t.Fatalf("Ferreiro nível 30 deveria poder despertar o Forjador Amaldiçoado: %s", why)
	}

	p.SetIdentityMode(0, protocol.ClassCursedSmith, protocol.IdentityModeInitialChange)
	if p.ClassID != protocol.ClassCursedSmith || p.Level != 30 || p.ClassTier != protocol.TierRare {
		t.Fatalf("Variante deve manter o nível e entrar no Tier 3: classe %d nível %d tier %d", p.ClassID, p.Level, p.ClassTier)
	}
	if p.SubPath != 0 {
		t.Fatalf("Variantes não usam Caminho Evolutivo, SubPath %d", p.SubPath)
	}
	p.AddLevel(15) // Nível 45 -> Épico, +9 pts/nível
	if p.ClassTier != protocol.TierEpic || p.StatPointsPerLevel() != 9 {
		t.Fatalf("no nível 45 a Variante vira Épica com +9 pts/nível: tier %d, pts %d", p.ClassTier, p.StatPointsPerLevel())
	}

	low := NewPlayer(2, nil, 0, 0, 0)
	low.SetIdentity(protocol.RaceValerian, protocol.ClassWarrior)
	if ok, _ := low.CanAwakenVariant(protocol.ClassRunicSpellblade); ok {
		t.Fatal("Guerreiro nível 1 não deveria despertar Variante (exige nível 25)")
	}
}
