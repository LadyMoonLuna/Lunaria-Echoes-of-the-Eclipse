package network

import (
	"encoding/binary"
	"fmt"
	"log"
	"math"
	"sync"
	"time"

	"lunaria/server/internal/protocol"
	"lunaria/server/internal/world"
)

// Arrastar corpos para um lugar seguro antes da autópsia (puxar, empurrar e o couro se estragando).
var drags = struct {
	sync.Mutex
	byPlayer map[uint32]uint32 // jogador -> corpo
	lastSend time.Time
}{byPlayer: map[uint32]uint32{}}

const dragBroadcastEvery = 100 * time.Millisecond // 10 Hz para quem está na zona

func (s *Server) handleCorpseDrag(playerID uint32, data []byte) {
	s.mu.RLock()
	p := s.players[playerID]
	s.mu.RUnlock()
	if p == nil || s.corpseManager == nil {
		return
	}
	corpseID := binary.LittleEndian.Uint32(data[1:5])
	if data[5] == 0 {
		s.releaseDrag(p, "")
		return
	}
	c, ok := s.corpseManager.GetCorpse(corpseID)
	if !ok || c.IsExpired() {
		return
	}
	p.Mu.RLock()
	px, py, pz, zone := p.PosX, p.PosY, p.PosZ, p.ZoneID
	p.Mu.RUnlock()
	if c.GetZone() != zone || c.DistanceTo(px, py, pz) > world.DragGrabRange {
		s.sendPlayerNPCSay(p, 0, "Chegue mais perto do corpo para agarrá-lo.")
		return
	}
	c.Mu.Lock()
	busy := c.DraggedBy != 0 && c.DraggedBy != p.ID
	mass := c.MassKg
	if !busy {
		c.DraggedBy = p.ID
	}
	c.Mu.Unlock()
	if busy {
		s.sendPlayerNPCSay(p, 0, "Outra pessoa já está arrastando esse corpo.")
		return
	}
	capKg := p.DragCapacityKg()
	if err := world.CanDrag(mass, capKg); err != nil {
		c.Mu.Lock()
		c.DraggedBy = 0
		c.Mu.Unlock()
		s.sendPlayerNPCSay(p, 0, "🪨 "+err.Error()+" (mais Força e Constituição ajudam).")
		return
	}
	s.releaseDrag(p, "") // solta outro corpo que estivesse arrastando
	drags.Lock()
	drags.byPlayer[p.ID] = corpseID
	drags.Unlock()
	c.Mu.Lock()
	c.DraggedBy = p.ID
	c.Mu.Unlock()
	s.sendPlayerNPCSay(p, 0, fmt.Sprintf("🪢 Você agarrou o corpo (%.0f kg). Ande para puxar; encoste nele para empurrar. [T] solta.", mass))
	s.broadcastDragState(c)
}

// releaseDrag solta o corpo (motivo vazio = o jogador soltou).
func (s *Server) releaseDrag(p *world.Player, reason string) {
	drags.Lock()
	cid, ok := drags.byPlayer[p.ID]
	delete(drags.byPlayer, p.ID)
	drags.Unlock()
	if !ok {
		return
	}
	if c, found := s.corpseManager.GetCorpse(cid); found {
		c.Mu.Lock()
		if c.DraggedBy == p.ID {
			c.DraggedBy = 0
		}
		integ := c.HideIntegrity
		c.Mu.Unlock()
		s.broadcastDragState(c)
		msg := fmt.Sprintf("Você soltou o corpo. Integridade do couro: %.0f%%.", integ*100)
		if reason != "" {
			msg = reason + " " + msg
		}
		s.sendPlayerNPCSay(p, 0, msg)
	}
}

// updateCorpseDrags (30 Hz): cada corpo segue quem o arrasta e o couro se desgasta.
func (s *Server) updateCorpseDrags(dt float32) {
	if s.corpseManager == nil {
		return
	}
	drags.Lock()
	pairs := make(map[uint32]uint32, len(drags.byPlayer))
	for pid, cid := range drags.byPlayer {
		pairs[pid] = cid
	}
	send := time.Since(drags.lastSend) >= dragBroadcastEvery
	if send {
		drags.lastSend = time.Now()
	}
	drags.Unlock()
	for pid, cid := range pairs {
		p := s.findPlayer(pid)
		c, ok := s.corpseManager.GetCorpse(cid)
		if p == nil || !ok || c.IsExpired() {
			if p != nil {
				s.releaseDrag(p, "")
			} else {
				drags.Lock()
				delete(drags.byPlayer, pid)
				drags.Unlock()
			}
			continue
		}
		p.Mu.RLock()
		px, pz, zone, hp := p.PosX, p.PosZ, p.ZoneID, p.HP
		p.Mu.RUnlock()
		c.Mu.RLock()
		cx, cz := c.PosX, c.PosZ
		c.Mu.RUnlock()
		far := float32(math.Sqrt(float64(dist2(px, pz, cx, cz))))
		if zone != c.GetZone() || hp == 0 || far > world.DragSnapDistance {
			s.releaseDrag(p, "A corda escapou!")
			continue
		}
		if moved, _ := c.StepDrag(px, pz); moved > 0 {
			c.Mu.Lock()
			c.ExpiresAt = c.ExpiresAt.Add(time.Duration(float64(dt) * float64(time.Second))) // enquanto arrasta, a decomposição espera
			c.Mu.Unlock()
		}
		if send {
			s.broadcastDragState(c)
		}
	}
}

// broadcastDragState (0x60) para os jogadores da zona do corpo.
func (s *Server) broadcastDragState(c *world.Corpse) {
	c.Mu.RLock()
	st := protocol.CorpseDragState{CorpseID: c.CorpseID, X: c.PosX, Z: c.PosZ, RotY: c.RotY,
		Integrity: uint8(c.HideIntegrity*100 + 0.5), DraggerID: c.DraggedBy, MassKg: uint16(min(65535, c.MassKg))}
	zone := c.ZoneID
	mass := c.MassKg
	c.Mu.RUnlock()
	st.SpeedPct = 100
	if st.DraggerID != 0 {
		if p := s.findPlayer(st.DraggerID); p != nil {
			st.SpeedPct = uint8(world.DragSpeedMult(mass, p.DragCapacityKg())*100 + 0.5)
		}
	}
	pkt := protocol.SerializeCorpseDragState(st)
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, p := range s.players {
		if p.GetZone() == zone {
			writeTCP(p, pkt)
		}
	}
}

// dragQualityFactor: o couro arrastado chega pior na autópsia.
func dragQualityFactor(c *world.Corpse, organType uint8) float32 {
	f := c.IntegrityQualityFactor(organType)
	if f < 1 {
		log.Printf("[ARRASTO] Corpo #%d: qualidade x%.2f pelo arrasto\n", c.CorpseID, f)
	}
	return f
}
