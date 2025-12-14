// loraxMod - Tree-sitter parsing infrastructure
// Standalone module extracted from vibe_tools

const { initParser, loadLanguage, getParser, isParserInitialized, resetParser } = require('./core/parser');
const { detectLanguage, getGrammarFile, getSupportedLanguages } = require('./core/language-map');
const { traverseWithAncestors, findAncestor, isTopLevel, getParentClassName } = require('./core/traversal');
const { TreeSitterExtractor, getCurrentContext, getDetectedSegments, resetSegments } = require('./extractors/base-extractor');
const { matchesExtractionContext, applyExtractionContext } = require('./filters/extraction-context');
const { ExtractorNotFoundError, UnknownLanguageError } = require('./errors');

// Auto-register all language extractors
require('./extractors/javascript');
require('./extractors/python');
require('./extractors/bash');
require('./extractors/powershell');
require('./extractors/r');
require('./extractors/csharp');
require('./extractors/rust');
require('./extractors/c');
require('./extractors/cpp');
require('./extractors/css');
require('./extractors/fortran');
require('./extractors/html');

/**
 * High-level API: Parse code and extract segments
 * @param {string} code - Source code to parse
 * @param {string} filePath - File path (for language detection)
 * @param {Object} extractionContext - Optional extraction context/filters
 * @param {Object} languageConfig - Optional language configuration
 * @returns {Promise<Array>} Array of code segments
 */
async function parseCode(code, filePath, extractionContext = null, languageConfig = null) {
  const language = detectLanguage(filePath);

  if (language === 'unknown') {
    throw new UnknownLanguageError(filePath);
  }

  // Initialize parser if needed
  await initParser();

  // Load language grammar
  const languageObj = await loadLanguage(language, languageConfig?.grammarDir);

  if (!languageObj) {
    throw new Error(`Failed to load grammar for language: ${language}`);
  }

  // Get parser and set language
  const parser = getParser();
  parser.setLanguage(languageObj);

  // Parse code
  const tree = parser.parse(code);

  // Extract segments using registered extractor
  const ExtractorClass = getExtractorClass(language);
  const extractor = new ExtractorClass();
  let segments = extractor.extract(tree, extractionContext);

  // Apply extraction context filtering
  segments = applyExtractionContext(segments, extractionContext, code);

  // Add content to segments
  const lines = code.split("\n");
  segments = segments.map(segment => ({
    ...segment,
    content: lines.slice(segment.startLine, segment.endLine + 1).join("\n"),
    lineCount: segment.endLine - segment.startLine + 1
  }));

  return segments;
}

/**
 * Get extractor class for language
 * @param {string} language - Language identifier
 * @returns {Class} Extractor class
 */
function getExtractorClass(language) {
  const extractors = {
    javascript: require('./extractors/javascript').JavaScriptExtractor,
    python: require('./extractors/python').PythonExtractor,
    bash: require('./extractors/bash').BashExtractor,
    powershell: require('./extractors/powershell').PowerShellExtractor,
    r: require('./extractors/r').RExtractor,
    csharp: require('./extractors/csharp').CSharpExtractor,
    rust: require('./extractors/rust').RustExtractor,
    c: require('./extractors/c').CExtractor,
    cpp: require('./extractors/cpp').CppExtractor,
    css: require('./extractors/css').CSSExtractor,
    fortran: require('./extractors/fortran').FortranExtractor,
    html: require('./extractors/html').HTMLExtractor
  };

  const ExtractorClass = extractors[language];
  if (!ExtractorClass) {
    throw new ExtractorNotFoundError(language);
  }

  return ExtractorClass;
}

/**
 * Parse code with custom extractor subset
 * @param {string} code - Source code
 * @param {string} filePath - File path
 * @param {Array<string>} languages - Language extractors to use
 * @param {Object} extractionContext - Optional extraction context
 * @returns {Promise<Array>} Array of code segments
 */
async function parseCodeWith(code, filePath, languages, extractionContext = null) {
  // Custom parsing with specific extractors
  // Implementation would allow mixing extractors
  throw new Error('parseCodeWith not yet implemented');
}

// Main exports
module.exports = {
  // High-level API
  parseCode,
  parseCodeWith,

  // Core functionality
  initParser,
  loadLanguage,
  getParser,
  isParserInitialized,
  resetParser,
  detectLanguage,
  getGrammarFile,
  getSupportedLanguages,

  // AST traversal utilities
  traverseWithAncestors,
  findAncestor,
  isTopLevel,
  getParentClassName,

  // Extractor classes
  TreeSitterExtractor,
  getExtractorClass,

  // Filtering
  applyExtractionContext,
  matchesExtractionContext,

  // State management (for advanced use)
  getCurrentContext,
  getDetectedSegments,
  resetSegments
};
