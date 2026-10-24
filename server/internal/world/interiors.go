package world

import "fmt"

// Interiores dos prédios da Vila do Refúgio. Cada prédio tem uma porta: ao encostar nela o
// jogador é levado para a zona interna (sala de 26x26 m) e, ao sair pela porta interna,
// volta para a frente da mesma porta.
const (
	ZoneForgeInterior  uint8 = 17 // Forja do Garrick (bancadas de criação do ferreiro)
	ZoneTavernInterior uint8 = 18 // Taverna do Javali Dourado
	ZoneAlchemyLab     uint8 = 19 // Laboratório de Alquimia da Lyra
	ZoneBarracks       uint8 = 20 // Quartel da Guarda Real
	ZoneHunterLodge    uint8 = 21 // Posto do Caçador
	ZoneJewelerAtelier uint8 = 22 // Ateliê da Joalheira
	ZoneResidence      uint8 = 23 // Casa dos Moradores (todas as casas comuns)
)

// Sala interna: a porta fica na parede sul (z = -InteriorDoorZ); chega-se logo à frente dela.
const (
	InteriorHalf     float32 = 13
	InteriorDoorZ    float32 = 9
	InteriorArriveZ  float32 = -6
	doorOutsideReach float32 = 3.2 // distância da fachada onde o jogador aparece ao sair
)

// Postos dentro dos interiores (coordenadas da sala)
var (
	ForgeFirePos             = [2]float32{-7, 7} // fornalha acesa da Forja: só queima quem pisa nas brasas
	ForgeFireRadius  float32 = 1.6
	GarrickForgePost         = [2]float32{1.5, 3} // atrás da bigorna
	ForgeAnvilPos            = [2]float32{0, 1.6} // bigorna da Forja: abre a interface de forja
	LyraLabPost              = [2]float32{0, 4}   // bancada de alquimia
	TavernSeatA              = [2]float32{-4, 2}  // mesas da taverna (à noite)
	TavernSeatB              = [2]float32{4, 2}
	ResidenceBedA            = [2]float32{-5, 6} // camas da Casa dos Moradores (madrugada)
	ResidenceBedB            = [2]float32{5, 6}
)

// Building é um prédio da vila com porta para a sua zona interna.
type Building struct {
	Key       string
	Name      string
	Interior  uint8
	X, Z      float32 // centro na Vila
	W, D, H   float32 // largura (x), profundidade (z), altura das paredes
	Door      string  // lado da porta: "south" (-z), "north" (+z), "east" (+x), "west" (-x)
	InPortal  uint8
	OutPortal uint8
}

// VillageBuildings: prédios organizados em quadras ao redor das avenidas (x = 0 e z = 0),
// nos mesmos lugares das construções originais.
var VillageBuildings = []Building{
	{"forge", "Forja do Garrick", ZoneForgeInterior, 30, 25, 10, 8, 5.0, "south", 33, 34},
	{"tavern", "Taverna do Javali Dourado", ZoneTavernInterior, -30, 25, 12, 9, 5.5, "south", 35, 36},
	{"lab", "Laboratório de Alquimia da Lyra", ZoneAlchemyLab, 30, -20, 9, 8, 4.8, "north", 37, 38},
	{"barracks", "Quartel da Guarda Real", ZoneBarracks, 0, 48, 12, 9, 5.4, "south", 39, 40},
	{"hunter", "Posto do Caçador", ZoneHunterLodge, 25, -95, 8, 7, 4.2, "north", 41, 42},
	{"atelier", "Ateliê da Joalheira Selene", ZoneJewelerAtelier, 52, 22, 8, 7, 4.5, "south", 43, 44},
	{"house_ne", "Casa dos Moradores", ZoneResidence, -55, 22, 8, 7, 4.2, "south", 45, 46},
	{"house_sw", "Casa dos Moradores", ZoneResidence, -28, -20, 8, 7, 4.2, "north", 47, 48},
	{"house_se", "Casa dos Moradores", ZoneResidence, 55, -20, 8, 7, 4.2, "north", 49, 50},
	{"house_n", "Casa dos Moradores", ZoneResidence, -22, 50, 8, 7, 4.2, "south", 51, 52},
}

// DoorDir devolve o vetor (x, z) que aponta da porta para fora do prédio.
func (b Building) DoorDir() (float32, float32) {
	switch b.Door {
	case "north":
		return 0, 1
	case "east":
		return 1, 0
	case "west":
		return -1, 0
	}
	return 0, -1
}

// DoorPos: centro da porta na fachada.
func (b Building) DoorPos() (float32, float32) {
	dx, dz := b.DoorDir()
	return b.X + dx*b.W/2, b.Z + dz*b.D/2
}

// OutsidePos: onde o jogador aparece ao sair do prédio (de frente para a porta).
func (b Building) OutsidePos() (float32, float32) {
	x, z := b.DoorPos()
	dx, dz := b.DoorDir()
	return x + dx*doorOutsideReach, z + dz*doorOutsideReach
}

// BuildingByPortal encontra o prédio cuja porta usa o portal (de entrada ou de saída).
func BuildingByPortal(id uint8) (Building, bool) {
	for _, b := range VillageBuildings {
		if b.InPortal == id || b.OutPortal == id {
			return b, true
		}
	}
	return Building{}, false
}

// IsInteriorZone informa se a zona é o interior de um prédio da vila.
func IsInteriorZone(zone uint8) bool {
	return zone >= ZoneForgeInterior && zone <= ZoneResidence
}

func interiorName(zone uint8) string {
	for _, b := range VillageBuildings {
		if b.Interior == zone {
			if zone == ZoneResidence {
				return "Interior da Casa dos Moradores"
			}
			return "Interior: " + b.Name
		}
	}
	return "Interior"
}

func init() {
	for _, b := range VillageBuildings {
		ox, oz := b.OutsidePos()
		OfficialPortals[b.InPortal] = PortalDef{ID: b.InPortal, Name: fmt.Sprintf("Porta: %s", b.Name),
			FromZoneID: ZoneVillage, TargetZoneID: b.Interior, TargetX: 0, TargetY: 1.5, TargetZ: InteriorArriveZ}
		OfficialPortals[b.OutPortal] = PortalDef{ID: b.OutPortal, Name: fmt.Sprintf("Saída: %s", b.Name),
			FromZoneID: b.Interior, TargetZoneID: ZoneVillage, TargetX: ox, TargetY: 1.5, TargetZ: oz}
	}
}
