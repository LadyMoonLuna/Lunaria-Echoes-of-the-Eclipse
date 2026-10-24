package protocol

import (
	"encoding/binary"
	"errors"
	"math"
)

// Forja — Etapa 2 (Fornalha de Ligas e Forja por Blueprints)
const (
	PacketTypeForgeAlloy     uint8 = 0x51 // [Client -> Server] Fundir até 4 ingredientes (5 bytes)
	PacketTypeForgeBlueprint uint8 = 0x52 // [Client -> Server] Forjar blueprint escolhendo o material de cada peça (8 bytes)
	PacketTypeForgeAction    uint8 = 0x53 // [Client -> Server] Pedir estado da forja / comprar blueprint (3 bytes)
	PacketTypeForgeState     uint8 = 0x54 // [Server -> Client] Blueprints conhecidas e peças únicas (tamanho variável)

	ForgeAlloyPacketSize     = 5
	ForgeBlueprintPacketSize = 8
	ForgeActionPacketSize    = 3
	ForgeMaxParts            = 6

	ForgeActionState        uint8 = 0
	ForgeActionBuyBlueprint uint8 = 1
)

// ForgeCustomEntry: peça única (liga sintética ou equipamento forjado) enviada ao cliente.
type ForgeCustomEntry struct {
	ID, Kind, Slot, Rarity, ToolKind, ToolTier uint8
	Weight                                     float32
	ATK, DEF, HP, Durability                   uint16
	Thermal, Electric, Magic                   uint8
	Name, Desc, Resist                         string
}

func putString(buf []byte, s string) []byte {
	if len(s) > 65535 {
		s = s[:65535]
	}
	buf = binary.LittleEndian.AppendUint16(buf, uint16(len(s)))
	return append(buf, s...)
}

// SerializeForgeState: op | nBP u8 | nBP × id | nCustom u8 | entradas.
func SerializeForgeState(blueprints []uint8, custom []ForgeCustomEntry) []byte {
	buf := []byte{PacketTypeForgeState, uint8(len(blueprints))}
	buf = append(buf, blueprints...)
	buf = append(buf, uint8(len(custom)))
	for _, c := range custom {
		buf = append(buf, c.ID, c.Kind, c.Slot, c.Rarity, c.ToolKind, c.ToolTier)
		buf = binary.LittleEndian.AppendUint32(buf, math.Float32bits(c.Weight))
		buf = binary.LittleEndian.AppendUint16(buf, c.ATK)
		buf = binary.LittleEndian.AppendUint16(buf, c.DEF)
		buf = binary.LittleEndian.AppendUint16(buf, c.HP)
		buf = binary.LittleEndian.AppendUint16(buf, c.Durability)
		buf = append(buf, c.Thermal, c.Electric, c.Magic)
		buf = putString(buf, c.Name)
		buf = putString(buf, c.Desc)
		buf = putString(buf, c.Resist)
	}
	return buf
}

// DeserializeForgeState lê o pacote 0x54 (usado nos testes).
func DeserializeForgeState(data []byte) ([]uint8, []ForgeCustomEntry, error) {
	if len(data) < 3 || data[0] != PacketTypeForgeState {
		return nil, nil, errors.New("pacote de forja inválido")
	}
	i := 1
	n := int(data[i])
	i++
	if len(data) < i+n+1 {
		return nil, nil, errors.New("pacote de forja curto")
	}
	bps := append([]uint8(nil), data[i:i+n]...)
	i += n
	cn := int(data[i])
	i++
	readStr := func() (string, error) {
		if len(data) < i+2 {
			return "", errors.New("texto curto")
		}
		l := int(binary.LittleEndian.Uint16(data[i:]))
		i += 2
		if len(data) < i+l {
			return "", errors.New("texto curto")
		}
		s := string(data[i : i+l])
		i += l
		return s, nil
	}
	var out []ForgeCustomEntry
	for k := 0; k < cn; k++ {
		if len(data) < i+21 {
			return nil, nil, errors.New("entrada curta")
		}
		var c ForgeCustomEntry
		c.ID, c.Kind, c.Slot, c.Rarity, c.ToolKind, c.ToolTier = data[i], data[i+1], data[i+2], data[i+3], data[i+4], data[i+5]
		c.Weight = math.Float32frombits(binary.LittleEndian.Uint32(data[i+6:]))
		c.ATK = binary.LittleEndian.Uint16(data[i+10:])
		c.DEF = binary.LittleEndian.Uint16(data[i+12:])
		c.HP = binary.LittleEndian.Uint16(data[i+14:])
		c.Durability = binary.LittleEndian.Uint16(data[i+16:])
		c.Thermal, c.Electric, c.Magic = data[i+18], data[i+19], data[i+20]
		i += 21
		var err error
		if c.Name, err = readStr(); err != nil {
			return nil, nil, err
		}
		if c.Desc, err = readStr(); err != nil {
			return nil, nil, err
		}
		if c.Resist, err = readStr(); err != nil {
			return nil, nil, err
		}
		out = append(out, c)
	}
	return bps, out, nil
}

// Forja — Etapa 3 (Criador Quebra-Cabeça e Patentes). O 0x3D já é o SUBMIT_AUTOPSY_RESULT,
// então o registro de arma autoral usa o 0x55.
const (
	PacketTypeRegisterCustomWeapon uint8 = 0x55 // [Client -> Server] op | len u16 | nome + peças (tamanho variável)
	PacketTypeForgeAlert           uint8 = 0x56 // [Server -> Client] op | tipo | len u16 | mensagem (alerta grande)
	PacketTypePuzzleState          uint8 = 0x57 // [Server -> Client] op | liberado | blueprints exclusivas

	ForgeAlertPatentDenied uint8 = 1 // alerta vermelho: sem direitos autorais
	ForgeAlertInfo         uint8 = 2
	MaxRegisterWeaponBody        = 1 + 64 + 1 + 20*5
)

// PuzzlePiece: módulo, âncora x/y, rotação e material (5 bytes no fio).
type PuzzlePiece struct{ Module, X, Y, Rot, Material uint8 }

// RegisterCustomWeapon: nome digitado e peças montadas na grade.
type RegisterCustomWeapon struct {
	Name   string
	Pieces []PuzzlePiece
}

func appendPieces(buf []byte, pieces []PuzzlePiece) []byte {
	buf = append(buf, uint8(len(pieces)))
	for _, p := range pieces {
		buf = append(buf, p.Module, p.X, p.Y, p.Rot, p.Material)
	}
	return buf
}

func readPieces(data []byte, i int) ([]PuzzlePiece, int, error) {
	if len(data) < i+1 {
		return nil, i, errors.New("peças ausentes")
	}
	n := int(data[i])
	i++
	if len(data) < i+n*5 {
		return nil, i, errors.New("peças curtas")
	}
	out := make([]PuzzlePiece, n)
	for k := 0; k < n; k++ {
		b := data[i+k*5:]
		out[k] = PuzzlePiece{b[0], b[1], b[2], b[3], b[4]}
	}
	return out, i + n*5, nil
}

// SerializeRegisterCustomWeapon (cliente -> servidor; usado nos testes).
func SerializeRegisterCustomWeapon(pkt RegisterCustomWeapon) []byte {
	body := []byte{uint8(len(pkt.Name))}
	body = append(body, pkt.Name...)
	body = appendPieces(body, pkt.Pieces)
	buf := []byte{PacketTypeRegisterCustomWeapon}
	buf = binary.LittleEndian.AppendUint16(buf, uint16(len(body)))
	return append(buf, body...)
}

// DeserializeRegisterCustomWeaponBody lê o corpo (depois de op e tamanho).
func DeserializeRegisterCustomWeaponBody(body []byte) (RegisterCustomWeapon, error) {
	var pkt RegisterCustomWeapon
	if len(body) < 1 || len(body) < 1+int(body[0]) {
		return pkt, errors.New("nome ausente")
	}
	pkt.Name = string(body[1 : 1+int(body[0])])
	pieces, _, err := readPieces(body, 1+int(body[0]))
	pkt.Pieces = pieces
	return pkt, err
}

// SerializeForgeAlert: alerta grande na tela do cliente.
func SerializeForgeAlert(kind uint8, msg string) []byte {
	return putString([]byte{PacketTypeForgeAlert, kind}, msg)
}

// ExclusiveEntry: Blueprint Exclusiva (nome + desenho) para recarregar no quebra-cabeça.
type ExclusiveEntry struct {
	Name   string
	Pieces []PuzzlePiece
}

// SerializePuzzleState: op | liberado u8 | n u8 | n × (len u8 + nome, peças).
func SerializePuzzleState(unlocked bool, list []ExclusiveEntry) []byte {
	u := uint8(0)
	if unlocked {
		u = 1
	}
	buf := []byte{PacketTypePuzzleState, u, uint8(len(list))}
	for _, e := range list {
		name := e.Name
		if len(name) > 255 {
			name = name[:255]
		}
		buf = append(buf, uint8(len(name)))
		buf = append(buf, name...)
		buf = appendPieces(buf, e.Pieces)
	}
	return buf
}

// DeserializePuzzleState lê o 0x57 (testes).
func DeserializePuzzleState(data []byte) (bool, []ExclusiveEntry, error) {
	if len(data) < 3 || data[0] != PacketTypePuzzleState {
		return false, nil, errors.New("pacote inválido")
	}
	i := 3
	var out []ExclusiveEntry
	for k := 0; k < int(data[2]); k++ {
		if len(data) < i+1 || len(data) < i+1+int(data[i]) {
			return false, nil, errors.New("nome curto")
		}
		e := ExclusiveEntry{Name: string(data[i+1 : i+1+int(data[i])])}
		var err error
		if e.Pieces, i, err = readPieces(data, i+1+int(data[i])); err != nil {
			return false, nil, err
		}
		out = append(out, e)
	}
	return data[1] == 1, out, nil
}
