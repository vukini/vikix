// Shapes.java — classes, interfaces, records, and a closed family of types.
//
// Java organises code in types. Shape is an interface: anything that can
// tell its area. It is sealed, so only the three records below may be
// shapes, and the compiler knows that list is complete. A record is a
// class that just holds values: Java writes its constructor, accessors,
// equals and toString for you.
import java.util.List;

public class Shapes {
    sealed interface Shape permits Circle, Rectangle, Triangle {
        double area();
    }

    record Circle(double radius) implements Shape {
        public double area() { return Math.PI * radius * radius; }
    }

    record Rectangle(double width, double height) implements Shape {
        public double area() { return width * height; }
    }

    record Triangle(double base, double height) implements Shape {
        public double area() { return base * height / 2; }
    }

    // A pattern test: `instanceof Circle c` checks and names it at once.
    static String describe(Shape s) {
        if (s instanceof Circle c) return "a circle of radius " + c.radius();
        if (s instanceof Rectangle r && r.width() == r.height()) return "a square of side " + r.width();
        return "a " + s.getClass().getSimpleName().toLowerCase();
    }

    public static void main(String[] args) {
        List<Shape> shapes = List.of(new Circle(1), new Rectangle(2, 3), new Rectangle(2, 2), new Triangle(4, 5));
        double total = 0;
        for (Shape s : shapes) {
            System.out.printf("%-26s area %6.2f   %s%n", describe(s), s.area(), s);
            total += s.area();
        }
        System.out.printf("total area %.2f%n", total);
    }
}
