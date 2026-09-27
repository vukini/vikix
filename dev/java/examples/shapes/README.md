# shapes (Java)

What Java is known for: programs built from types. An interface (Shape),
records that implement it (Circle, Rectangle, Triangle), and a sealed
interface, so the compiler knows those three are all the shapes there are.

    make run

Try: add a `record Square(double side)` and read what the compiler says
about `permits`; with Java 21 or newer (`java -version`), turn `describe`
into a `switch (s) { case Circle c -> ... }` that needs no default.
Docs: https://dev.java/learn/ (records, sealed classes, pattern matching).
