// main.go — the ten most common words in a text file.
//
// A word is a run of letters, compared in lower case. A map counts them;
// sort.Slice then orders them, most common first.
//
//	go run . text.txt
package main

import (
	"fmt"
	"os"
	"sort"
	"strings"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: wordfreq FILE")
		os.Exit(2)
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	counts := map[string]int{}
	notLetter := func(r rune) bool { return r < 'a' || r > 'z' }
	for _, word := range strings.FieldsFunc(strings.ToLower(string(data)), notLetter) {
		counts[word]++
	}

	type entry struct {
		word  string
		count int
	}
	var entries []entry
	for w, c := range counts {
		entries = append(entries, entry{w, c})
	}
	// The higher count first; the same count in alphabetical order.
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].count != entries[j].count {
			return entries[i].count > entries[j].count
		}
		return entries[i].word < entries[j].word
	})
	for i, e := range entries {
		if i == 10 {
			break
		}
		fmt.Printf("%4d %s\n", e.count, e.word)
	}
}
