package world

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"
)

// TestClientClassPathsMatchServer garante que client/scripts/ClassPaths.gd mostra os mesmos
// multiplicadores de Caminho Evolutivo que o servidor aplica (GetSubPathMultipliers).
func TestClientClassPathsMatchServer(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "client", "scripts", "ClassPaths.gd"))
	if err != nil {
		t.Skipf("ClassPaths.gd não encontrado: %v", err)
	}
	src := string(data)
	start := strings.Index(src, "const PATHS := {")
	end := strings.Index(src, "const VARIANTS := {")
	if start < 0 || end < 0 {
		t.Fatal("bloco PATHS não encontrado em ClassPaths.gd")
	}
	classRe := regexp.MustCompile(`(?m)^\t(\d+): \{$`)
	pathRe := regexp.MustCompile(`(?m)^\t\t(\d): \{.*"mult": \[([^\]]+)\]`)
	block := src[start:end]
	classIdx := classRe.FindAllStringSubmatchIndex(block, -1)
	if len(classIdx) != 12 {
		t.Fatalf("esperava 12 classes em PATHS, achou %d", len(classIdx))
	}
	checked := 0
	for i, ci := range classIdx {
		classID, _ := strconv.Atoi(block[ci[2]:ci[3]])
		segEnd := len(block)
		if i+1 < len(classIdx) {
			segEnd = classIdx[i+1][0]
		}
		for _, m := range pathRe.FindAllStringSubmatch(block[ci[1]:segEnd], -1) {
			sub, _ := strconv.Atoi(m[1])
			var got [5]float64
			for k, f := range strings.Split(m[2], ",") {
				got[k], _ = strconv.ParseFloat(strings.TrimSpace(f), 64)
			}
			hp, st, def, spd, dmg := GetSubPathMultipliers(uint8(classID), uint8(sub))
			want := [5]float32{hp, st, def, spd, dmg}
			for k := range want {
				if diff := float64(want[k]) - got[k]; diff > 0.001 || diff < -0.001 {
					t.Fatalf("classe %d caminho %d: multiplicador %d no cliente %.2f, servidor %.2f", classID, sub, k, got[k], want[k])
				}
			}
			checked++
		}
	}
	if checked != 48 {
		t.Fatalf("esperava 48 caminhos conferidos, conferiu %d", checked)
	}
}
