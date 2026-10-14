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
