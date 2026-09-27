// WordFreq.java — the ten most common words in a text file.
//
// A word is a run of letters, compared in lower case. A HashMap counts
// them (merge adds one, or starts at one); a stream sorts the entries,
// most common first, and takes ten.
//
//   build/install/wordfreq/bin/wordfreq text.txt
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Map;

public class WordFreq {
    public static void main(String[] args) throws IOException {
        if (args.length != 1) {
            System.err.println("usage: wordfreq FILE");
            System.exit(2);
        }
        String text = Files.readString(Path.of(args[0])).toLowerCase();

        Map<String, Integer> counts = new HashMap<>();
        for (String word : text.split("[^a-z]+")) {
            if (!word.isEmpty()) {
                counts.merge(word, 1, Integer::sum);
            }
        }

        // The higher count first; the same count in alphabetical order.
        counts.entrySet().stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue(Comparator.reverseOrder())
                    .thenComparing(Map.Entry.comparingByKey()))
            .limit(10)
            .forEach(e -> System.out.printf("%4d %s%n", e.getValue(), e.getKey()));
    }
}
