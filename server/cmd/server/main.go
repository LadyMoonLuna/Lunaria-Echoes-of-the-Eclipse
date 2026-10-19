package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"lunaria/server/internal/network"
)

func main() {
	log.Println("==================================================")
	log.Println("   Lunaria Online — Servidor Autoritativo (Marco 4)")
	log.Println("   Ecossistema Vivo, Mobs Taticos Lua & AoE Telegraph")
	log.Println("   Portas: 7000 (TCP) | 7001 (UDP) | Tick Rate: 30 Hz")
	log.Println("==================================================")

	srv := network.NewServer()
	if err := srv.Start(); err != nil {
		log.Fatalf("[FATAL] Falha ao iniciar servidor: %v\n", err)
	}

	// Captura de sinais para finalização graciosa
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	sig := <-sigChan
	log.Printf("[MAIN] Sinal de interrupcao recebido (%v). Encerrando...\n", sig)

	srv.Stop()
}
