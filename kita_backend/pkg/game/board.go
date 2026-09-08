package game

type Pos struct {
	Col int
	Row int
}

var Tiles = map[Pos]int{
	{0, 0}: 2, {1, 0}: 3, {2, 0}: 1, {3, 0}: 2, {4, 0}: 1, {5, 0}: 3, {6, 0}: 2,
	{0, 1}: 3, {3, 1}: 1, {6, 1}: 3,
	{0, 2}: 3, {3, 2}: 1, {6, 2}: 3,
	{0, 3}: 2, {1, 3}: 3, {2, 3}: 1, {3, 3}: 2, {4, 3}: 1, {5, 3}: 3, {6, 3}: 2,
}

var AllTiles []Pos
var Adjacency = map[Pos][]Pos{}

func init() {
	for pos := range Tiles {
		AllTiles = append(AllTiles, pos)
	}

	directions := []Pos{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	for pos := range Tiles {
		var neighbors []Pos
		for _, d := range directions {
			nb := Pos{pos.Col + d.Col, pos.Row + d.Row}
			if _, exists := Tiles[nb]; exists {
				neighbors = append(neighbors, nb)
			}
		}
		Adjacency[pos] = neighbors
	}
}

func TileValue(pos Pos) int {
	return Tiles[pos]
}

type StackEntry struct {
	Pos     Pos
	Rem     int
	Visited map[Pos]bool
}

func FindReachable(start Pos, steps int, occupied map[Pos]bool, landable map[Pos]bool) []Pos {
	if steps == 0 {
		return []Pos{start}
	}

	destinationsSet := make(map[Pos]bool)
	startVisited := make(map[Pos]bool)
	startVisited[start] = true

	stack := []StackEntry{
		{Pos: start, Rem: steps, Visited: startVisited},
	}

	for len(stack) > 0 {
		entry := stack[len(stack)-1]
		stack = stack[:len(stack)-1]

		for _, nb := range Adjacency[entry.Pos] {
			if entry.Visited[nb] {
				continue
			}

			if entry.Rem == 1 {
				if !occupied[nb] || landable[nb] {
					destinationsSet[nb] = true
				}
			} else {
				if occupied[nb] {
					continue
				}
				newVisited := make(map[Pos]bool)
				for k, v := range entry.Visited {
					newVisited[k] = v
				}
				newVisited[nb] = true
				stack = append(stack, StackEntry{
					Pos:     nb,
					Rem:     entry.Rem - 1,
					Visited: newVisited,
				})
			}
		}
	}

	var destinations []Pos
	for k := range destinationsSet {
		destinations = append(destinations, k)
	}
	return destinations
}
