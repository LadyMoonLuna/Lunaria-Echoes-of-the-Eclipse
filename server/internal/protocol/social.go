package protocol

import "encoding/binary"

// Fonte, mercado vivo, amizade e Guilda.
const (
	PacketTypeFountainUse  uint8 = 0x61 // [C->S] op | ação (1 beber, 2 encher frascos, 3 lavar-se) (2 bytes)
	PacketTypeMarketState  uint8 = 0x62 // [S->C] op | tamanho u16 | JSON (loja: comprar/vender)
	PacketTypeSocialAction uint8 = 0x63 // [C->S] op | npc u32 | ação | item u16 | qualidade (9 bytes)
	PacketTypeSocialState  uint8 = 0x64 // [S->C] op | tamanho u16 | JSON (corações, cooldowns, favor)
	PacketTypeGuildAction  uint8 = 0x65 // [C->S] op | ação | npc u32 | item u16 | qtd (9 bytes)
	PacketTypeGuildState   uint8 = 0x66 // [S->C] op | tamanho u16 | JSON (quadro de encomendas)

	PacketTypeDevGiveItem  uint8 = 0x67 // [C->S] op | item u16 (3 bytes) — Dev: dar qualquer item pelo ID
	DevGiveItemPacketSize        = 3
	FountainUsePacketSize        = 2
	SocialActionPacketSize       = 9
	GuildActionPacketSize        = 9
)

// Ações de amizade (0x63)
const (
	SocialActionState   uint8 = 0
	SocialActionTalk    uint8 = 1
	SocialActionGift    uint8 = 2
	SocialActionQuest   uint8 = 3 // pedir/aceitar um favor
	SocialActionTurnIn  uint8 = 4 // entregar o passo atual
	SocialActionAbandon uint8 = 5
)

// Ações da Guilda (0x65)
const (
	GuildActionOpen    uint8 = 0
	GuildActionDeliver uint8 = 1
)

// SerializeJSONPacket: op | tamanho u16 | bytes (JSON curto, até 64 KB).
func SerializeJSONPacket(op uint8, body []byte) []byte {
	if len(body) > 65535 {
		body = body[:65535]
	}
	b := make([]byte, 3+len(body))
	b[0] = op
	binary.LittleEndian.PutUint16(b[1:3], uint16(len(body)))
	copy(b[3:], body)
	return b
}
