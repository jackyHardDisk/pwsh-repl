#!/usr/bin/env node
// Test script for loraxMod parsers
// Usage: node test-parser.js <language>

const lorax = require('./lib/index.js');

// Test code samples for each language
const testSamples = {
  javascript: `
class MyClass {
  constructor() {
    this.value = 42;
  }

  myMethod() {
    console.log("Hello");
  }
}

function topLevelFunc() {
  return "test";
}

const MY_CONSTANT = 100;
`,

  python: `
class MyClass:
    def __init__(self):
        self.value = 42

    def my_method(self):
        print("Hello")

def top_level_func():
    return "test"

MY_CONSTANT = 100
`,

  rust: `
struct MyStruct {
    value: i32,
}

impl MyStruct {
    fn new() -> Self {
        MyStruct { value: 42 }
    }

    fn my_method(&self) -> i32 {
        self.value
    }
}

fn top_level_func() -> String {
    String::from("test")
}

const MY_CONSTANT: i32 = 100;
`,

  c: `
struct MyStruct {
    int value;
};

typedef struct MyStruct MyStruct_t;

int top_level_func(void) {
    return 42;
}

#define MY_CONSTANT 100
#define MY_MACRO(x) ((x) * 2)
`,

  css: `
.my-class {
    color: red;
    background: blue;
}

#my-id {
    margin: 10px;
}

@keyframes slide-in {
    from { left: -100%; }
    to { left: 0; }
}

@media (max-width: 768px) {
    .responsive { display: none; }
}

:root {
    --primary-color: #007bff;
}
`,

  fortran: `
MODULE MyModule
    IMPLICIT NONE

CONTAINS

    SUBROUTINE MySubroutine(x)
        REAL, INTENT(IN) :: x
        PRINT *, "Value:", x
    END SUBROUTINE MySubroutine

    FUNCTION MyFunction(x) RESULT(y)
        REAL, INTENT(IN) :: x
        REAL :: y
        y = x * 2.0
    END FUNCTION MyFunction

END MODULE MyModule

PROGRAM TestProgram
    USE MyModule
    IMPLICIT NONE
    REAL :: value
    value = 42.0
    CALL MySubroutine(value)
END PROGRAM TestProgram
`,

  csharp: `
public class MyClass
{
    private int value;

    public MyClass()
    {
        value = 42;
    }

    public void MyMethod()
    {
        Console.WriteLine("Hello");
    }
}

public static class Utils
{
    public const int MY_CONSTANT = 100;
}
`,

  powershell: `
class MyClass {
    [int]$Value

    MyClass() {
        $this.Value = 42
    }

    [void]MyMethod() {
        Write-Host "Hello"
    }
}

function Get-TopLevelFunc {
    return "test"
}

$MY_CONSTANT = 100
`,

  bash: `
my_function() {
    echo "Hello"
    return 0
}

another_func() {
    local result="test"
    echo "$result"
}

MY_CONSTANT=100
`,

  r: `
MyClass <- R6::R6Class("MyClass",
    public = list(
        value = NULL,
        initialize = function() {
            self$value <- 42
        },
        my_method = function() {
            print("Hello")
        }
    )
)

top_level_func <- function() {
    return("test")
}

MY_CONSTANT <- 100
`
};

async function testLanguage(language) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Testing ${language.toUpperCase()} Parser`);
  console.log('='.repeat(60));

  const sample = testSamples[language];
  if (!sample) {
    console.error(`No test sample available for ${language}`);
    return;
  }

  try {
    const filename = `test.${getExtension(language)}`;
    console.log(`\nParsing sample code from ${filename}...`);

    const segments = await lorax.parseCode(sample, filename);

    console.log(`\n✓ Successfully parsed! Found ${segments.length} segments:\n`);

    segments.forEach((seg, idx) => {
      console.log(`${idx + 1}. [${seg.type.toUpperCase()}] ${seg.name}`);
      console.log(`   Lines: ${seg.startLine + 1}-${seg.endLine + 1} (${seg.lineCount} lines)`);
      if (seg.parent) console.log(`   Parent: ${seg.parent}`);
      if (seg.extends) console.log(`   Extends: ${seg.extends}`);
      console.log();
    });

  } catch (error) {
    console.error(`\n✗ Error parsing ${language}:`);
    console.error(error.message);
    if (error.stack) {
      console.error('\nStack trace:');
      console.error(error.stack);
    }
  }
}

function getExtension(language) {
  const extensions = {
    javascript: 'js',
    python: 'py',
    rust: 'rs',
    c: 'c',
    css: 'css',
    fortran: 'f90',
    csharp: 'cs',
    powershell: 'ps1',
    bash: 'sh',
    r: 'R'
  };
  return extensions[language] || language;
}

async function testAll() {
  const languages = lorax.getSupportedLanguages();

  console.log('loraxMod Parser Test Suite');
  console.log('==========================');
  console.log(`\nSupported languages: ${languages.join(', ')}`);

  for (const lang of languages) {
    if (testSamples[lang]) {
      await testLanguage(lang);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('Test suite complete!');
  console.log('='.repeat(60) + '\n');
}

// Main execution
const args = process.argv.slice(2);
const language = args[0];

if (language) {
  testLanguage(language.toLowerCase());
} else {
  testAll();
}
