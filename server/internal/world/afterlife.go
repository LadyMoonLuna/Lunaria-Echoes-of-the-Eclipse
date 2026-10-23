package world

import (
	"fmt"
	"math/rand"
	"time"

	"lunaria/server/internal/protocol"
)

// Mundo Vivo (Fase 1, Parte 3): cemitério, Coveiro, zumbis, purificação, necromancia,
// caçadores da Igreja, rio e doenças.

// --- Cemitério ao lado da Igreja ---

const (
	GravediggerID   uint32 = 120
	SeraphinaID     uint32 = 107
	LyraID          uint32 = 103
	PaladinFirstID  uint32 = 400 // Paladinos da Luz: 400..409
	ClericFirstID   uint32 = 420 // Clérigas da Luz: 420..429
	ChurchHunterMax        = 10
)

var (
	CemeteryOrigin = [2]float32{-70, -26} // primeira cova; as demais seguem em fileiras
	ChurchDoor     = [2]float32{-46, -36} // porta da Igreja na Vila
	PlaceRiver     = [2]float32{96, 18}   // margem do Rio Prateado, a leste da vila
)

const cemeteryColumns = 5

// CemeterySlot devolve a posição da cova número i.
func CemeterySlot(i int) [2]float32 {
	return [2]float32{CemeteryOrigin[0] - float32(i%cemeteryColumns)*2.6, CemeteryOrigin[1] - float32(i/cemeteryColumns)*3.0}
}

func init() {
	NPCStarts[GravediggerID] = NPCStart{HP: 900, Gold: 200, Personality: PersonalityCautious}
	Professions[GravediggerID] = "Coveiro"
	for i := uint32(0); i < ChurchHunterMax; i++ {
		NPCStarts[PaladinFirstID+i] = NPCStart{HP: 2200, Gold: 50, Personality: PersonalityHonorable}
		NPCStarts[ClericFirstID+i] = NPCStart{HP: 1300, Gold: 50, Personality: PersonalityHonorable}
		Professions[PaladinFirstID+i] = "Paladino da Luz"
		Professions[ClericFirstID+i] = "Clériga da Luz"
		CombatNPCs[PaladinFirstID+i] = 75
		CombatNPCs[ClericFirstID+i] = 35
	}
	CombatNPCs[GravediggerID] = 40 // a pá também machuca
}

// IsChurchHunter: Paladinos e Clérigas enviados pela Igreja.
func IsChurchHunter(id uint32) bool {
	return (id >= PaladinFirstID && id < PaladinFirstID+ChurchHunterMax) || (id >= ClericFirstID && id < ClericFirstID+ChurchHunterMax)
}

// IsCleric: as Clérigas curam os aliados durante a caçada.
func IsCleric(id uint32) bool { return id >= ClericFirstID && id < ClericFirstID+ChurchHunterMax }

// IsLawman: Guardas e caçadores da Igreja perseguem criminosos.
func IsLawman(id uint32) bool {
	for _, g := range GuardNPCs {
		if g == id {
			return true
		}
	}
	return IsChurchHunter(id)
}

// --- Classes ---

// HolyClasses: o Acólito (hoje Guardião do Bastião, ensinado pela Irmã Seraphina) e suas vertentes sagradas.
var HolyClasses = map[uint8]bool{
	protocol.ClassShieldBearer: true, protocol.ClassVampireHunter: true,
	protocol.ClassAegisValkyrie: true, protocol.ClassAshInquisitor: true,
}

// IsNecromancer: a profissão secreta que reergue mortos.
func IsNecromancer(classID uint8) bool { return classID == protocol.ClassBoneNecromancer }

// --- Zumbis ---

const (
	ZombieRiseChance        = 0.05 // corpo não processado
	ZombieRiseChanceVictim  = 0.30 // morto por zumbi
	GraveRiseChanceUnburied = 0.03 // por verificação (a cada 2 min) enquanto o corpo do NPC não é enterrado
	GraveRiseChanceVictim   = 0.25
	UnprotectedGraveChance  = 0.01 // cova sem Coveiro nem Igreja (a cada 10 min)
	GraveCheckInterval      = 2 * time.Minute
	UnprotectedGraveCheck   = 10 * time.Minute

	ZombieSpeed         float32 = 1.7 // lentos
	ZombiePerception    float32 = 9   // enxergam pouco
	ZombieForgetAfter           = 4 * time.Second
	ZombieReach         float32 = 1.7
	ZombieHitInterval           = 1800 * time.Millisecond
	ZombieFollowOwner   float32 = 3.5
	ZombieServantLeash  float32 = 10
	NecroBaseChance             = 0.55
	NecroChancePerLevel         = 0.06
	NecroFailRiseChance         = 0.30 // a falha pode erguer um zumbi selvagem
	WitnessRange        float32 = 25
)

// LevelFromHP estima o nível de uma criatura pela vida máxima.
func LevelFromHP(maxHP int) uint8 {
	lvl := maxHP / 60
	if lvl < 1 {
		lvl = 1
	}
	if lvl > 60 {
		lvl = 60
	}
	return uint8(lvl)
}

// NewZombie cria um zumbi (sem ID: registre com MobManager.AddDynamicMob).
func NewZombie(name string, zone uint8, x, z float32, maxHP int, level uint8, owner uint32) *Mob {
	if maxHP < 120 {
		maxHP = 120
	}
	if maxHP > 4000 {
		maxHP = 4000
	}
	m := NewMobWithZone(0, name, protocol.MobTypeZombie, zone, x, 0, z, uint16(maxHP), ZombieSpeed)
	m.Undead, m.ZombieOwner, m.Level, m.NoRespawn = true, owner, level, true
	m.WanderX, m.WanderZ = x, z
	return m
}

// ZombieDamage: golpe de um zumbi.
func ZombieDamage(level uint8) int { return 10 + int(level)*3 }

// RiseRoll decide se um corpo não processado volta como zumbi.
func RiseRoll(killedByZombie bool, roll float64) bool {
	if killedByZombie {
		return roll < ZombieRiseChanceVictim
	}
	return roll < ZombieRiseChance
}

// NecroChance: chance do Necromante reerguer o corpo (cai se o zumbi for de nível maior).
func NecroChance(necroLevel, zombieLevel uint8) float64 {
	c := NecroBaseChance + NecroChancePerLevel*float64(int(necroLevel)-int(zombieLevel))
	return max(0.05, min(0.95, c))
}

// ZombieName monta o nome do zumbi a partir do corpo.
func ZombieName(of string) string { return fmt.Sprintf("Zumbi de %s", of) }

// --- Rio, Fonte e doenças ---

const (
	FountainDryTemp      float32 = 38    // a Fonte Central só seca num calor extremo
	FountainRefillTemp   float32 = 28    // e volta com chuva ou tempo mais fresco
	FountainDryChancePer float32 = 0.002 // por grau acima de 38 °C, a cada verificação
	RiverSicknessChance          = 0.20
	SickHPPerMinute      float32 = 10
	SickNeedsMult        float32 = 1.5
	HurtThreshold                = 0.5 // abaixo de 50% de HP o NPC procura cura
	ChurchCurePrice      uint32  = 150 // Igreja cura doenças (mais caro que o remédio)
	ChurchHealPrice      uint32  = 120 // Igreja cura ferimentos
	NPCPotionHealFrac            = 0.4 // uma poção cura 40% da vida de um NPC
)

var Diseases = []string{"Febre do Rio", "Infecção Intestinal", "Disenteria", "Verme do Lodo"}

// CatchRiverDisease: beber direto do rio pode adoecer.
func CatchRiverDisease(r *rand.Rand) (bool, string) {
	roll := rand.Float64
	pick := rand.Intn
	if r != nil {
		roll, pick = r.Float64, r.Intn
	}
	if roll() >= RiverSicknessChance {
		return false, ""
	}
	return true, Diseases[pick(len(Diseases))]
}

// --- Aprendizes falham ---

// CraftFailChance: só aprendizes formados falham; a chance cai com o nível do ofício.
func CraftFailChance(npc *NPC, r Recipe) float64 {
	if npc.Profession == 0 || npc.Profession == npc.ID || npc.ProfessionLevel >= 10 {
		return 0
	}
	return max(0, r.Difficulty*(1.2-0.1*float64(npc.ProfessionLevel)))
}

// Heal cura o NPC (até a vida máxima). Devolve o HP novo.
func (npc *NPC) Heal(amount int) int {
	npc.mu.Lock()
	defer npc.mu.Unlock()
	if npc.IsDead {
		return 0
	}
	npc.HP = min(npc.MaxHP, npc.HP+amount)
	return npc.HP
}
