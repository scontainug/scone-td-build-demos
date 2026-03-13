import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        // Print CLI arguments
        System.out.println("Java-args-env-file V3\n");
        System.out.println("Command Line Arguments:");
        for (int i = 0; i < args.length; i++) {
            System.out.printf("arg[%d]: %s%n", i, args[i]);
        }

        // Print environment variables
        System.out.println("\nEnvironment Variables:");
        for (Map.Entry<String, String> env : System.getenv().entrySet()) {
            System.out.printf("%s=%s%n", env.getKey(), env.getValue());
        }

        // Read and print /config/configs.yaml
        readAndPrintFile("/config/configs.yaml", "Config File");

        // Read and print /config/secrets
        readAndPrintFile("/config/secrets", "Secrets File");

        // Sleep for 1 hour
        System.out.println("\nSleeping for 30 seconds to keep the container alive...");
        try {
            Thread.sleep(30_000); // 30 seconds = 30000 ms
        } catch (InterruptedException e) {
            System.err.println("Sleep interrupted: " + e.getMessage());
        }

        System.out.println("Done.");

    }

    private static void readAndPrintFile(String path, String label) {
        System.out.printf("%n%s (%s):%n", label, path);
        try {
            Files.lines(Paths.get(path)).forEach(System.out::println);
        } catch (IOException e) {
            System.out.printf("Failed to read %s: %s%n", path, e.getMessage());
        }
    }
}
