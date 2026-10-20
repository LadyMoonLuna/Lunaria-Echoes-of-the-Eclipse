package world

import (
	"testing"
	"time"

	"lunaria/server/internal/protocol"
)

func TestCorpseCreationAndOrgans(t *testing.T) {
	mob := NewMob(1, "Lobo da Bruma", protocol.MobTypeMistWolf, 10.0, 0.0, 20.0, 100, 3.5)
	cm := NewCorpseManager()

	corpse := cm.CreateCorpseFromMob(mob, 42, 0.05)
	if corpse == nil {
		t.Fatalf("esperava corpse não nulo")
	}

	if corpse.CorpseID < 1000 {
		t.Fatalf("esperava CorpseID >= 1000, obteve %d", corpse.CorpseID)
	}
	if corpse.MobID != 1 || corpse.MobType != protocol.MobTypeMistWolf {
		t.Fatalf("dados do mob divergentes no corpse: MobID=%d, MobType=%d", corpse.MobID, corpse.MobType)
	}
	if corpse.PosX != 10.0 || corpse.PosZ != 20.0 {
		t.Fatalf("posição divergente: (%.1f, %.1f)", corpse.PosX, corpse.PosZ)
	}
	if corpse.IsLooted {
		t.Fatalf("novo cadáver não deve estar saqueado (IsLooted=false)")
	}
	if len(corpse.Organs) < 3 {
		t.Fatalf("esperava ao menos 3 órgãos para Lobo da Bruma, obteve %d", len(corpse.Organs))
	}
	if corpse.RemainingSeconds() == 0 || corpse.RemainingSeconds() > 120 {
		t.Fatalf("tempo restante inválido: %d segundos", corpse.RemainingSeconds())
	}
}

func TestCorpseDistanceAndInteraction(t *testing.T) {
	c := NewCorpse(1001, 10, protocol.MobTypeOutcastRaider, "Saqueador", 0.0, 0.0, 0.0, 0.0, 1, 0.0)

	// Dentro do raio de 2.5m (dist = 2.0m)
	if !c.CanInteract(2.0, 0.0, 0.0) {
		t.Fatalf("jogador a 2.0m deveria conseguir interagir (<= 2.5m)")
	}

	// Exatamente no limite (2.5m)
	if !c.CanInteract(2.5, 0.0, 0.0) {
		t.Fatalf("jogador a 2.5m deveria conseguir interagir")
	}

	// Fora do raio (dist = 2.6m)
	if c.CanInteract(2.6, 0.0, 0.0) {
		t.Fatalf("jogador a 2.6m NÃO deveria conseguir interagir (> 2.5m)")
	}

	// Distância calculada
	dist := c.DistanceTo(3.0, 4.0, 0.0)
	if dist != 5.0 {
		t.Fatalf("esperava distância 5.0m, obteve %.2f", dist)
	}
}

func TestCorpseOrganExtraction(t *testing.T) {
	c := NewCorpse(1002, 20, protocol.MobTypeAlphaWolf, "Lobo Alfa", 5.0, 0.0, 5.0, 0.0, 1, 0.0)

	organCount := len(c.Organs)
	if organCount == 0 {
		t.Fatalf("esperava órgãos gerados")
	}

	// Extração do primeiro órgão com qualidade perfeita (Tier 1)
	organ0, ok := c.MarkOrganExtracted(0, QualityPerfect)
	if !ok {
		t.Fatalf("esperava sucesso na extração do órgão 0")
	}
	if !organ0.Extracted || organ0.QualityTier != QualityPerfect {
		t.Fatalf("estado incorreto do órgão extraído: %+v", organ0)
	}

	// Tentar extrair novamente deve falhar
	_, okAgain := c.MarkOrganExtracted(0, QualityCommon)
	if okAgain {
		t.Fatalf("extração duplicada não deveria ser permitida")
	}

	// Cadáver não deve estar totalmente saqueado ainda
	if c.IsLooted {
		t.Fatalf("cadáver não deveria estar totalmente saqueado com órgãos restantes")
	}

	// Extrai todos os demais órgãos
	for i := 1; i < organCount; i++ {
		_, okRem := c.MarkOrganExtracted(uint8(i), QualityCommon)
		if !okRem {
			t.Fatalf("falha ao extrair órgão %d", i)
		}
	}

	// Agora todos os órgãos foram extraídos
	c.Mu.RLock()
	isLooted := c.IsLooted
	c.Mu.RUnlock()

	if !isLooted {
		t.Fatalf("cadáver deveria estar marcado como IsLooted após todos os órgãos extraídos")
	}
}

func TestCorpseDecayAndCleanup(t *testing.T) {
	cm := NewCorpseManager()
	c1 := NewCorpse(1001, 1, protocol.MobTypeMistWolf, "Lobo 1", 0, 0, 0, 0, 1, 0)
	c2 := NewCorpse(1002, 2, protocol.MobTypeMistWolf, "Lobo 2", 10, 0, 10, 0, 1, 0)

	cm.mu.Lock()
	cm.corpses[c1.CorpseID] = c1
	cm.corpses[c2.CorpseID] = c2
	cm.mu.Unlock()

	if cm.Count() != 2 {
		t.Fatalf("esperava 2 cadáveres, obteve %d", cm.Count())
	}

	// Força c1 a expirar
	c1.Mu.Lock()
	c1.ExpiresAt = time.Now().Add(-1 * time.Second)
	c1.Mu.Unlock()

	if !c1.IsExpired() {
		t.Fatalf("c1 deveria estar expirado")
	}
	if c1.CanInteract(0, 0, 0) {
		t.Fatalf("não deve permitir interagir com cadáver expirado")
	}

	expired := cm.CleanupExpired()
	if len(expired) != 1 || expired[0] != 1001 {
		t.Fatalf("esperava expiração de [1001], obteve %v", expired)
	}

	if cm.Count() != 1 {
		t.Fatalf("esperava 1 cadáver restante, obteve %d", cm.Count())
	}

	_, exists := cm.GetCorpse(1001)
	if exists {
		t.Fatalf("cadáver 1001 não deveria mais existir")
	}
	_, exists2 := cm.GetCorpse(1002)
	if !exists2 {
		t.Fatalf("cadáver 1002 deveria permanecer")
	}
}
