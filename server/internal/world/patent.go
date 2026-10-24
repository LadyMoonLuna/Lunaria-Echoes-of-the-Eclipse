package world

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
	"sync"

	"lunaria/server/internal/protocol"
)

// Forja — Etapa 3: Criador de Equipamentos "Quebra-Cabeça" (grade 7x7) e Patentes Exclusivas.
// Ferreiros avançados montam o formato da arma encaixando módulos na grade, escolhem o material de
// cada módulo e registram a criação: a combinação formato + materiais passa a ter dono.

const (
	PuzzleGridSize       = 7
	PuzzleMaxPieces      = 20
	PuzzleMaxNameLen     = 32
	MasterpieceBonus     = 1.20 // +20% de atributos na Obra-Prima Autoral
	CustomBlueprintKind  = 3    // CustomItem.Kind da Blueprint Exclusiva (Soulbound)
	PatentDeniedMessage  = "⛔ Você não tem os Direitos Autorais Dessa Arma!"
	puzzleBaseATK        = 12
	puzzleMassPerCell    = 0.18
	puzzleDurScale       = 1.1
	PatentsFileDefault   = "patents.json"
	puzzleBladeCategory  = "lamina"
	puzzleGuardCategory  = "guarda"
	puzzleCoreCategory   = "nucleo"
	puzzleShaftCategory  = "cabo"
	puzzleSheathCategory = "bainha"
)

// PuzzleModule é uma peça geométrica do quebra-cabeça (células na rotação 0).
type PuzzleModule struct {
	ID       uint8
	Name     string
	Category string
	Cells    [][2]int
	Tags     []string
	Role     string
}

var bladeTags = []string{TagMetal, TagStoneEdge, TagFang}
var guardTags = []string{TagMetal, TagBone, TagCrystal}
var coreTags = []string{TagCrystal, TagEye, TagHeart}

// PuzzleModules: catálogo de módulos (lâminas/pontas, guardas/núcleos, eixos/cabos/conexões).
var PuzzleModules = []PuzzleModule{
	{1, "Ponta Reta", puzzleBladeCategory, [][2]int{{0, 0}, {0, 1}}, bladeTags, RoleDamage},
	{2, "Ponta Curva de Katana", puzzleBladeCategory, [][2]int{{0, 0}, {0, 1}, {1, 1}}, bladeTags, RoleDamage},
	{3, "Ponta Dupla de Lança", puzzleBladeCategory, [][2]int{{0, 0}, {2, 0}, {0, 1}, {1, 1}, {2, 1}}, bladeTags, RoleDamage},
	{4, "Gume Largo de Espadão", puzzleBladeCategory, [][2]int{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, bladeTags, RoleDamage},
	{5, "Gume Serrilhado", puzzleBladeCategory, [][2]int{{0, 0}, {0, 1}, {1, 1}, {1, 2}}, bladeTags, RoleDamage},
	{6, "Lâmina de Foice", puzzleBladeCategory, [][2]int{{0, 0}, {1, 0}, {2, 0}, {2, 1}}, bladeTags, RoleDamage},
	{7, "Cabeça de Martelo", puzzleBladeCategory, [][2]int{{0, 0}, {1, 0}, {2, 0}}, []string{TagMetal, TagStoneEdge}, RoleDamage},
	{8, "Cabeça de Machado Duplo", puzzleBladeCategory, [][2]int{{0, 0}, {1, 0}, {2, 0}, {0, 1}, {2, 1}}, []string{TagMetal, TagStoneEdge}, RoleDamage},
	{9, "Gancho Vorpal", puzzleBladeCategory, [][2]int{{0, 0}, {1, 0}, {0, 1}}, bladeTags, RoleDamage},
	{10, "Guarda Cruzada", puzzleGuardCategory, [][2]int{{1, 0}, {0, 1}, {1, 1}, {2, 1}}, guardTags, RoleFrame},
	{11, "Guarda em Anel", puzzleGuardCategory, [][2]int{{0, 0}}, guardTags, RoleFrame},
	{12, "Guarda de Asas", puzzleGuardCategory, [][2]int{{0, 0}, {0, 1}, {1, 1}, {2, 1}, {2, 0}}, guardTags, RoleFrame},
	{13, "Engaste de Olho / Coração", puzzleCoreCategory, [][2]int{{0, 0}}, coreTags, RoleCore},
	{14, "Reator Rúnico", puzzleCoreCategory, [][2]int{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, []string{TagCrystal, TagHeart}, RoleCore},
	{15, "Cabo Curto", puzzleShaftCategory, [][2]int{{0, 0}, {0, 1}}, []string{TagWood, TagBone}, RoleFrame},
	{16, "Haste Longa de Alabarda", puzzleShaftCategory, [][2]int{{0, 0}, {0, 1}, {0, 2}, {0, 3}}, []string{TagWood, TagBone, TagMetal}, RoleFrame},
	{17, "Elo de Corrente Flexível", puzzleShaftCategory, [][2]int{{0, 0}, {1, 0}, {1, 1}}, []string{TagMetal}, RoleFrame},
	{18, "Contrapeso de Pomo", puzzleShaftCategory, [][2]int{{0, 0}}, []string{TagMetal, TagCrystal, TagStoneEdge}, RoleCore},
	{19, "Bainha Lateral", puzzleSheathCategory, [][2]int{{0, 0}, {0, 1}, {0, 2}}, []string{TagHide, TagWood, TagLightMetal, TagSilk}, RoleFrame},
}

// PuzzleGripModules: módulos que contam como Cabo obrigatório (o Contrapeso sozinho não segura a arma).
var PuzzleGripModules = map[uint8]bool{15: true, 16: true, 17: true}

// GetPuzzleModule devolve o módulo pelo ID.
func GetPuzzleModule(id uint8) (PuzzleModule, bool) {
	for _, m := range PuzzleModules {
		if m.ID == id {
			return m, true
		}
	}
	return PuzzleModule{}, false
}

// PuzzlePlacement: um módulo encaixado na grade (âncora x,y; rotação 0-3) com o seu material.
type PuzzlePlacement struct {
	Module   uint8
	X, Y     uint8
	Rot      uint8
	Material uint8
}

// RotatedCells: células ocupadas (rotação de 90° por passo, normalizada para começar em 0,0).
func RotatedCells(m PuzzleModule, rot uint8) [][2]int {
	out := make([][2]int, len(m.Cells))
	minX, minY := 99, 99
	for i, c := range m.Cells {
		x, y := c[0], c[1]
		for r := uint8(0); r < rot%4; r++ {
			x, y = -y, x
		}
		out[i] = [2]int{x, y}
		minX, minY = min(minX, x), min(minY, y)
	}
	for i := range out {
		out[i][0] -= minX
		out[i][1] -= minY
	}
	return out
}

// ValidatePuzzle confere grade, sobreposição, conexão e componentes obrigatórios.
func ValidatePuzzle(pl []PuzzlePlacement) error {
	if len(pl) == 0 || len(pl) > PuzzleMaxPieces {
		return fmt.Errorf("use de 1 a %d módulos", PuzzleMaxPieces)
	}
	var grid [PuzzleGridSize][PuzzleGridSize]int
	has := map[string]bool{}
	grip := false
	for i, p := range pl {
		m, ok := GetPuzzleModule(p.Module)
		if !ok {
			return fmt.Errorf("módulo desconhecido")
		}
		if p.Material == 0 {
			return fmt.Errorf("escolha o material de %s", m.Name)
		}
		for _, c := range RotatedCells(m, p.Rot) {
			x, y := int(p.X)+c[0], int(p.Y)+c[1]
			if x < 0 || y < 0 || x >= PuzzleGridSize || y >= PuzzleGridSize {
				return fmt.Errorf("%s sai da grade 7x7", m.Name)
			}
			if grid[y][x] != 0 {
				return fmt.Errorf("%s está por cima de outra peça", m.Name)
			}
			grid[y][x] = i + 1
		}
		has[m.Category] = true
		if PuzzleGripModules[m.ID] {
			grip = true
		}
	}
	switch {
	case !has[puzzleBladeCategory]:
		return fmt.Errorf("falta a Lâmina / Cabeça de impacto")
	case !has[puzzleGuardCategory]:
		return fmt.Errorf("falta a Guarda")
	case !grip:
		return fmt.Errorf("falta o Cabo")
	case !has[puzzleSheathCategory]:
		return fmt.Errorf("falta a Bainha")
	}
	// Todas as peças precisam formar uma arma só (células ligadas lado a lado)
	seen := map[int]bool{}
	var stack [][2]int
	for y := 0; y < PuzzleGridSize && len(stack) == 0; y++ {
		for x := 0; x < PuzzleGridSize; x++ {
			if grid[y][x] != 0 {
				stack = append(stack, [2]int{x, y})
				break
			}
		}
	}
	visited := map[[2]int]bool{}
	for len(stack) > 0 {
		c := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if visited[c] {
			continue
		}
		visited[c] = true
		seen[grid[c[1]][c[0]]] = true
		for _, d := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
			n := [2]int{c[0] + d[0], c[1] + d[1]}
			if n[0] >= 0 && n[1] >= 0 && n[0] < PuzzleGridSize && n[1] < PuzzleGridSize && grid[n[1]][n[0]] != 0 && !visited[n] {
				stack = append(stack, n)
			}
		}
	}
	if len(seen) != len(pl) {
		return fmt.Errorf("todas as peças precisam estar encaixadas umas nas outras")
	}
	return nil
}

func sortedPlacements(pl []PuzzlePlacement) []PuzzlePlacement {
	s := append([]PuzzlePlacement(nil), pl...)
	sort.Slice(s, func(i, j int) bool {
		a, b := s[i], s[j]
		if a.Y != b.Y {
			return a.Y < b.Y
		}
		if a.X != b.X {
			return a.X < b.X
		}
		return a.Module < b.Module
	})
	return s
}

// ShapeSignature: matriz de peças montadas (módulo@x,y/rotação), em ordem fixa.
func ShapeSignature(pl []PuzzlePlacement) string {
	var parts []string
	for _, p := range sortedPlacements(pl) {
		parts = append(parts, fmt.Sprintf("%d@%d,%d/%d", p.Module, p.X, p.Y, p.Rot%4))
	}
	return strings.Join(parts, ";")
}

// MaterialSignature: material de cada peça (ex.: "Cabo Curto@3,4:102|Ponta Reta@3,0:175").
func MaterialSignature(pl []PuzzlePlacement) string {
	var parts []string
	for _, p := range sortedPlacements(pl) {
		m, _ := GetPuzzleModule(p.Module)
		parts = append(parts, fmt.Sprintf("%s@%d,%d:%d", m.Name, p.X, p.Y, p.Material))
	}
	return strings.Join(parts, "|")
}

// PatentKey = ShapeSignature + "|" + MaterialSignature.
func PatentKey(pl []PuzzlePlacement) string {
	return ShapeSignature(pl) + "|" + MaterialSignature(pl)
}

// --- Registro global de patentes ---

var (
	patentsMu sync.Mutex
	// RegisteredWeaponPatents: chave da patente -> criador original ("Jogador #ID").
	RegisteredWeaponPatents = map[string]string{}
	patentsFile             = PatentsFileDefault
)

// SetPatentsFile troca o arquivo de patentes (testes usam um temporário; "" desliga a gravação).
func SetPatentsFile(path string) { patentsFile = path }

// LoadPatents carrega as patentes salvas (as patentes sobrevivem aos reinícios do servidor).
func LoadPatents() error {
	if patentsFile == "" {
		return nil
	}
	data, err := os.ReadFile(patentsFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	patentsMu.Lock()
	defer patentsMu.Unlock()
	return json.Unmarshal(data, &RegisteredWeaponPatents)
}

func savePatentsLocked() {
	if patentsFile == "" {
		return
	}
	if data, err := json.MarshalIndent(RegisteredWeaponPatents, "", "  "); err == nil {
		_ = os.WriteFile(patentsFile, data, 0o644)
	}
}

// ClaimPatent registra a patente para owner; false se ela já pertence a outra pessoa.
func ClaimPatent(key, owner string) bool {
	patentsMu.Lock()
	defer patentsMu.Unlock()
	if cur, ok := RegisteredWeaponPatents[key]; ok {
		return cur == owner
	}
	RegisteredWeaponPatents[key] = owner
	savePatentsLocked()
	return true
}

// PatentOwner devolve o dono da patente ("" se livre).
func PatentOwner(key string) string {
	patentsMu.Lock()
	defer patentsMu.Unlock()
	return RegisteredWeaponPatents[key]
}

// --- Classes que desbloqueiam o Quebra-Cabeça ---

// CanUsePuzzleForge: Artesão Overgeared (Forjador Épico do Mestre Armeiro), Forjador Carmesim (17),
// Runomante Ancestral (22) ou Herdeiro da Forja Divina (31). O acesso Dev também libera.
func (p *Player) CanUsePuzzleForge() bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	if p.DevForgeAccess {
		return true
	}
	switch p.ClassID {
	case protocol.ClassCursedSmith, protocol.ClassMountainRunemancer, protocol.ClassPagmaDescendant:
		return true
	case protocol.ClassBlacksmith:
		return p.SubPath == 1 && p.ClassTier >= protocol.TierEpic
	}
	return false
}

// ExclusiveBlueprint: desenho registrado pelo jogador (pode ser forjado de novo só por ele).
type ExclusiveBlueprint struct {
	Name       string
	Key        string
	Placements []PuzzlePlacement
}

// ForgePuzzle: valida, confere a patente e forja a Obra-Prima Autoral (+20%), entregando também a
// Blueprint Exclusiva Soulbound na primeira vez.
func (p *Player) ForgePuzzle(name string, pl []PuzzlePlacement, owner string) (ForgeResult, error, bool) {
	return p.ForgePuzzleScored(name, pl, owner, CraftScores{})
}

// ForgePuzzleScored: como ForgePuzzle, com as notas dos mini-games (Nota de Criação no item).
func (p *Player) ForgePuzzleScored(name string, pl []PuzzlePlacement, owner string, cs CraftScores) (ForgeResult, error, bool) {
	name = strings.TrimSpace(name)
	if name == "" || len([]rune(name)) > PuzzleMaxNameLen {
		return ForgeResult{}, fmt.Errorf("dê um nome de 1 a %d letras para a arma", PuzzleMaxNameLen), false
	}
	if !p.CanUsePuzzleForge() {
		return ForgeResult{}, fmt.Errorf("só Ferreiros Avançados, Únicos ou Lendários usam o Criador Quebra-Cabeça"), false
	}
	if err := ValidatePuzzle(pl); err != nil {
		return ForgeResult{}, err, false
	}
	key := PatentKey(pl)
	if o := PatentOwner(key); o != "" && o != owner {
		return ForgeResult{}, fmt.Errorf("%s", PatentDeniedMessage), true
	}

	p.Mu.Lock()
	defer p.Mu.Unlock()
	bp := BlueprintDef{Name: name, Kind: BPWeapon, Slot: protocol.SlotMainHand, BaseATK: puzzleBaseATK, DurScale: puzzleDurScale}
	mats := make([]MaterialDef, len(pl))
	specials := map[uint16]string{}
	totalCells := 0
	for _, pc := range pl {
		m, _ := GetPuzzleModule(pc.Module)
		totalCells += len(m.Cells)
	}
	var used []uint8
	for i, pc := range pl {
		m, _ := GetPuzzleModule(pc.Module)
		mat, ok := p.materialLocked(pc.Material)
		part := BlueprintPart{Name: m.Name, Tags: m.Tags, Role: m.Role, Share: float32(len(m.Cells)) / float32(totalCells)}
		if !ok || !PartAccepts(part, mat) {
			return ForgeResult{}, fmt.Errorf("%s não serve para %s", p.itemInfoLocked(pc.Material).Name, m.Name), false
		}
		if !p.DiscoveredMaterials[uint16(pc.Material)] {
			return ForgeResult{}, fmt.Errorf("você ainda não conhece %s", mat.Name), false
		}
		bp.Parts = append(bp.Parts, part)
		mats[i] = mat
		if sp, ok := AlloySpecial[mat.ID]; ok {
			specials[mat.ID] = sp
		}
		used = append(used, pc.Material)
	}
	bp.MassScale = float32(totalCells) * puzzleMassPerCell
	if !p.hasEachLocked(used) {
		return ForgeResult{}, fmt.Errorf("faltam materiais na mochila (1 unidade por peça)"), false
	}
	// Patente só é registrada quando a forja vai mesmo acontecer
	if !ClaimPatent(key, owner) {
		return ForgeResult{}, fmt.Errorf("%s", PatentDeniedMessage), true
	}
	st := ComputeForged(bp, mats, specials)
	st = ApplyMasterpiece(st)
	st.Name = name
	st.Specials = append(st.Specials, fmt.Sprintf("Obra-Prima Autoral de %s (+20%% atributos)", owner))
	var craftQ float32
	if cs.FromClient {
		final := p.PuzzleSessionScores(pl, cs.Clamp()) // peças trabalhadas (e reforjadas) uma a uma
		craftQ = craftQualityFor(final, p.MAS, p.STR, p.DEX)
		defer p.EndForgeSession()
		st = ApplyCraftQuality(st, craftQ)
		st.Specials = append(st.Specials, fmt.Sprintf("Forja %s (nota %.2f)", CraftTier(craftQ), craftQ))
	}

	weaponID, ok := p.allocCustomLocked()
	if !ok {
		return ForgeResult{}, fmt.Errorf("você já guarda peças únicas demais (máx. 55)"), false
	}
	q := p.takeIngredientsLocked(used)
	if cs.FromClient {
		q = UnitQualityFromCraft(craftQ)
	}
	info := ItemInfo{Name: st.Name, Weight: st.Weight, Slot: protocol.SlotMainHand, BonusATK: uint16(st.ATK), BonusDEF: uint16(st.DEF), BonusHP: uint16(st.HP)}
	p.CustomItems[weaponID] = &CustomItem{ID: weaponID, Kind: CustomEquip, Name: st.Name, Info: info, Stats: st, Desc: ForgedDescription(st)}
	p.addUnitsLocked(weaponID, 1, q)

	msg := fmt.Sprintf("🏆 Obra-Prima forjada: %s (Qualidade %d)!", st.Name, q)
	if p.exclusiveIndexLocked(key) < 0 {
		p.ExclusiveBlueprints = append(p.ExclusiveBlueprints, ExclusiveBlueprint{Name: name, Key: key, Placements: append([]PuzzlePlacement(nil), pl...)})
		if bpID, ok := p.allocCustomLocked(); ok {
			bpName := fmt.Sprintf("📘 Blueprint Exclusiva: %s", name)
			p.CustomItems[bpID] = &CustomItem{ID: bpID, Kind: CustomBlueprintKind, Name: bpName, Soulbound: true, PatentKey: key,
				Info: ItemInfo{Name: bpName, Weight: 0.1, Slot: NoSlot},
				Desc: "Inegociável / Introcável / Direitos Autorais Exclusivos.\nDesenho registrado em seu nome: só você pode forjar esta arma."}
			p.addUnitsLocked(bpID, 1, 100)
		}
		msg += " A Blueprint Exclusiva foi registrada em seu nome."
	}
	return ForgeResult{ItemID: weaponID, Qty: 1, Quality: q, Name: name, Message: msg}, nil, false
}

// ApplyMasterpiece: +20% em dano, defesa, vida e durabilidade.
func ApplyMasterpiece(st ForgedStats) ForgedStats {
	st.ATK = int(float64(st.ATK)*MasterpieceBonus + 0.5)
	st.DEF = int(float64(st.DEF)*MasterpieceBonus + 0.5)
	st.HP = int(float64(st.HP)*MasterpieceBonus + 0.5)
	st.Durability = min(9999, int(float64(st.Durability)*MasterpieceBonus+0.5))
	return st
}

func (p *Player) exclusiveIndexLocked(key string) int {
	for i, b := range p.ExclusiveBlueprints {
		if b.Key == key {
			return i
		}
	}
	return -1
}

// GetExclusiveBlueprints devolve uma cópia dos desenhos registrados pelo jogador.
func (p *Player) GetExclusiveBlueprints() []ExclusiveBlueprint {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	return append([]ExclusiveBlueprint(nil), p.ExclusiveBlueprints...)
}

// IsSoulbound: itens que não podem ir ao chão, ser vendidos nem trocados.
func (p *Player) IsSoulbound(id uint8) bool {
	p.Mu.RLock()
	defer p.Mu.RUnlock()
	c, ok := p.CustomItems[id]
	return ok && c.Soulbound
}

// RevealAllMaterials (Dev): marca todos os materiais do catálogo como descobertos.
func (p *Player) RevealAllMaterials() {
	p.Mu.Lock()
	defer p.Mu.Unlock()
	if p.DiscoveredMaterials == nil {
		p.DiscoveredMaterials = make(map[uint16]bool)
	}
	for id := range MaterialsDB {
		if !p.DiscoveredMaterials[id] {
			p.DiscoveredMaterials[id] = true
			p.newDiscoveries = append(p.newDiscoveries, id)
		}
	}
}
