/**
 * Custom error types for loraxMod
 *
 * Provides structured errors with codes for programmatic handling
 */

class LoraxError extends Error {
  constructor(message, code, details = {}) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.details = details;
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      details: this.details
    };
  }
}

class GrammarNotFoundError extends LoraxError {
  constructor(language, grammarPath) {
    super(
      `Grammar file not found for language '${language}'. Expected: ${grammarPath}`,
      'GRAMMAR_NOT_FOUND',
      { language, grammarPath }
    );
  }
}

class ExtractorNotFoundError extends LoraxError {
  constructor(language) {
    super(
      `No extractor available for language '${language}'`,
      'EXTRACTOR_NOT_FOUND',
      { language, availableLanguages: require('./core/language-map').getSupportedLanguages() }
    );
  }
}

class ParserInitError extends LoraxError {
  constructor(originalError) {
    super(
      `Failed to initialize tree-sitter parser: ${originalError.message}`,
      'PARSER_INIT_FAILED',
      { originalError: originalError.message }
    );
  }
}

class LanguageLoadError extends LoraxError {
  constructor(language, grammarPath, originalError) {
    super(
      `Failed to load grammar for '${language}': ${originalError.message}`,
      'LANGUAGE_LOAD_FAILED',
      { language, grammarPath, originalError: originalError.message }
    );
  }
}

class UnknownLanguageError extends LoraxError {
  constructor(filePath) {
    super(
      `Unable to detect language from file path: ${filePath}`,
      'UNKNOWN_LANGUAGE',
      { filePath }
    );
  }
}

module.exports = {
  LoraxError,
  GrammarNotFoundError,
  ExtractorNotFoundError,
  ParserInitError,
  LanguageLoadError,
  UnknownLanguageError
};
