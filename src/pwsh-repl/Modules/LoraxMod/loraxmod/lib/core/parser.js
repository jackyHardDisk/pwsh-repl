// Tree-sitter parser initialization and language loading
// Extracted from vibe_tools for loraxMod

const fs = require('fs');
const path = require('path');
const TreeSitter = require('web-tree-sitter');
const { getGrammarFile } = require('./language-map');
const { GrammarNotFoundError, ParserInitError, LanguageLoadError } = require('../errors');

// Parser singleton
let parserInitialized = false;
let parser = null;
const loadedLanguages = new Map();

/**
 * Initialize tree-sitter parser (call once before use)
 * @returns {Promise<TreeSitter.Parser>} Initialized parser instance
 */
async function initParser() {
  if (parserInitialized) return parser;

  try {
    // web-tree-sitter requires init() first
    await TreeSitter.Parser.init();
    parser = new TreeSitter.Parser();
    parserInitialized = true;
  } catch (error) {
    throw new ParserInitError(error);
  }
  return parser;
}

/**
 * Load language grammar from WASM file
 * @param {string} language - Language identifier (javascript, python, etc.)
 * @param {string} grammarDir - Optional custom grammar directory path
 * @returns {Promise<TreeSitter.Language|null>} Language object or null if failed
 */
async function loadLanguage(language, grammarDir = null) {
  if (loadedLanguages.has(language)) {
    return loadedLanguages.get(language);
  }

  const grammarFile = getGrammarFile(language);
  if (!grammarFile) {
    // Return null for unsupported languages (not an error)
    return null;
  }

  // Default grammar directory is relative to this file
  const defaultGrammarDir = path.join(__dirname, '..', '..', 'grammars');
  const grammarPath = path.join(grammarDir || defaultGrammarDir, grammarFile);

  if (!fs.existsSync(grammarPath)) {
    throw new GrammarNotFoundError(language, grammarPath);
  }

  try {
    const languageObj = await TreeSitter.Language.load(grammarPath);
    loadedLanguages.set(language, languageObj);
    return languageObj;
  } catch (error) {
    throw new LanguageLoadError(language, grammarPath, error);
  }
}

/**
 * Get the initialized parser instance
 * @returns {TreeSitter.Parser|null} Parser instance or null if not initialized
 */
function getParser() {
  return parser;
}

/**
 * Check if parser is initialized
 * @returns {boolean} True if parser is ready
 */
function isParserInitialized() {
  return parserInitialized;
}

/**
 * Reset parser state (for testing)
 */
function resetParser() {
  parserInitialized = false;
  parser = null;
  loadedLanguages.clear();
}

module.exports = {
  initParser,
  loadLanguage,
  getParser,
  isParserInitialized,
  resetParser
};
