package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/oguzhancelik/kita/pkg/game"
)

func printBoard(g *game.Game, mode string) {
	fmt.Println("\n" + g.Display(mode))
}

func printMoves(moves []game.Move) {
	for i, m := range moves {
		fmt.Printf("  [%2d] %s\n", i, m.String())
	}
}

func playTerminal(displayMode string) {
	fmt.Println("==================================================")
	fmt.Println("  KITA - 2-PLAYER TERMINAL MODE")
	fmt.Println("  White moves first. Players take turns.")
	fmt.Printf("  Current display mode: %s\n", strings.ToUpper(displayMode))
	fmt.Println("==================================================")

	g := game.NewGame()
	printBoard(g, displayMode)

	scanner := bufio.NewScanner(os.Stdin)

	for {
		status := g.GetStatus()
		if status != "ongoing" {
			fmt.Println("\n==================================================")
			fmt.Printf("  GAME OVER: %s\n", strings.ToUpper(status))
			fmt.Printf("  Total moves played: %d\n", g.MoveCount)
			fmt.Println("==================================================")
			break
		}

		moves := g.GetLegalMoves()
		if len(moves) == 0 {
			fmt.Printf("\n  %s has no legal moves left!\n", strings.ToUpper(g.Turn))
			break
		}

		fmt.Printf("\n%s's Turn - %d legal move(s):\n", strings.ToUpper(g.Turn), len(moves))
		printMoves(moves)

		var chosen game.Move
		for {
			fmt.Print("\nEnter move index ('d'=detailed, 's'=simple, 'q'=quit): ")
			if !scanner.Scan() {
				fmt.Println("\nQuit.")
				return
			}
			cmd := strings.ToLower(strings.TrimSpace(scanner.Text()))

			if cmd == "q" {
				fmt.Println("Exiting.")
				return
			}
			if cmd == "d" {
				displayMode = "detailed"
				printBoard(g, displayMode)
				continue
			}
			if cmd == "s" {
				displayMode = "simple"
				printBoard(g, displayMode)
				continue
			}

			idx, err := strconv.Atoi(cmd)
			if err == nil && idx >= 0 && idx < len(moves) {
				chosen = moves[idx]
				break
			}
			fmt.Printf("Invalid index. Enter a number between 0 and %d.\n", len(moves)-1)
		}

		g = g.ApplyMove(chosen)
		printBoard(g, displayMode)
	}
}

func showInfo() {
	g := game.NewGame()
	moves := g.GetLegalMoves()

	fmt.Println("=======================================================")
	fmt.Println("  KITA GAME ENGINE - BACKEND")
	fmt.Println("=======================================================")
	fmt.Printf("  Initial Turn     : %s\n", strings.ToUpper(g.Turn))
	fmt.Printf("  Legal Moves      : %d opening moves available\n", len(moves))
	fmt.Printf("  Game Status      : %s\n", g.GetStatus())
	fmt.Println("-------------------------------------------------------")
	fmt.Println("  Quick-start in Go:")
	fmt.Println("    import \"github.com/oguzhancelik/kita/pkg/game\"")
	fmt.Println("    g := game.NewGame()")
	fmt.Println("    moves := g.GetLegalMoves()")
	fmt.Println("    g = g.ApplyMove(moves[0])")
	fmt.Println("    // Display options:")
	fmt.Println("    g.Display(\"detailed\")  // full details")
	fmt.Println("    g.Display(\"simple\")    // board only")
	fmt.Println("=======================================================")
	printBoard(g, "detailed")
	fmt.Println("\nCommands:")
	fmt.Println("  go run cmd/cli/main.go play          -> Play 2-player game (detailed mode)")
	fmt.Println("  go run cmd/cli/main.go play simple   -> Play 2-player game (simple mode)")
	fmt.Println("  go run cmd/cli/main.go info          -> Show this overview")
}

func main() {
	args := os.Args[1:]
	mode := "info"
	if len(args) > 0 {
		mode = strings.ToLower(args[0])
	}

	if mode == "play" {
		displayMode := "detailed"
		if len(args) > 1 && (strings.ToLower(args[1]) == "simple" || strings.ToLower(args[1]) == "--simple" || strings.ToLower(args[1]) == "-s") {
			displayMode = "simple"
		}
		playTerminal(displayMode)
	} else {
		showInfo()
	}
}
