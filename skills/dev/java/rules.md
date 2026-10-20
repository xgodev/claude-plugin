# Java -- language leaf

Java-concrete shapes of the language-agnostic LAWs in
`../engineering/rules.md` (read that first; the numbers below refer to
it). This file exists because rules.md is language-agnostic BY LAW --
the Java idioms live here, not there.

## Layout (LAW 29)

- The Maven/Gradle standard directory layout: `src/main/java`,
  `src/main/resources`, `src/test/java`, `src/test/resources`. Gradle
  follows the same convention; a build that relocates these directories
  is inventing a layout.

## Framework (LAW 30)

- Spring Boot is the framework. What it lacks is written as a Spring Boot
  extension (an auto-configuration or starter), never a parallel stack
  wired around it.

## Quality (LAW 40)

- Unsized input is streamed: `InputStream.transferTo`, `BufferedReader`,
  `Files.lines` inside try-with-resources, `FileChannel.map` for random
  access. `readAllBytes`, `Files.readAllBytes/readAllLines/readString` only
  on input with a checked, small upper bound (CWE-770). JDBC reads set
  `setFetchSize` and page; a Spring endpoint caps request size.
- Every `Closeable` is opened in try-with-resources (CWE-772, CWE-404).
- `HttpClient` sets `connectTimeout` and a per-request `timeout`
  (CWE-1088).
- SQL is a `PreparedStatement` (CWE-89); `ProcessBuilder` takes an
  argument list (CWE-78); `ObjectInputStream` never reads untrusted input
  (CWE-502).
