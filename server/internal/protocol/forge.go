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
