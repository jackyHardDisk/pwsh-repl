// Base extractor class for tree-sitter language parsing
// Extracted from vibe_tools for loraxMod

const { traverseWithAncestors, getParentClassName } = require('../core/traversal');

// Global state for segment collection
let detectedSegments = [];
let currentContext = null;

/**
 * Base class for language-specific extractors
 */
class TreeSitterExtractor {
  constructor(language) {
    this.language = language;
  }

  /**
   * Extract code segments from parsed tree
   * @param {TreeSitter.Tree} tree - Parsed syntax tree
   * @param {Object} extractionContext - Filtering context
   * @returns {Array} Array of detected segments
   */
  extract(tree, extractionContext) {
    detectedSegments = [];
    currentContext = extractionContext;

    const rootNode = tree.rootNode;

    // Use ancestor tracking to traverse the tree
    traverseWithAncestors(rootNode, [], (node, ancestors) => {
      this.processNode(node, ancestors);
    });

    return detectedSegments;
  }

  /**
   * Process individual AST node (override in subclasses)
   * @param {TreeSitter.SyntaxNode} node - Current node
   * @param {TreeSitter.SyntaxNode[]} ancestors - Ancestor nodes
   */
  processNode(node, ancestors) {
    // Override in language-specific extractors
    throw new Error('processNode must be implemented by language extractor');
  }

  /**
   * Add segment with context from ancestors
   * @param {TreeSitter.SyntaxNode} node - AST node
   * @param {string} type - Segment type (class, function, method, etc.)
   * @param {string} name - Segment name
   * @param {TreeSitter.SyntaxNode[]} ancestors - Ancestor nodes
   * @param {Object} options - Additional options (parent, extends, etc.)
   */
  addSegment(node, type, name, ancestors, options = {}) {
    const startPosition = node.startPosition;
    const endPosition = node.endPosition;

    let finalName = name || "anonymous";
    let parent = options.parent || null;
    let extendsClass = options.extends || null;

    // Use ancestor trick for context preservation
    if (type === "method" && currentContext && currentContext.PreserveContext) {
      // Find parent class from ancestors
      const parentClassName = getParentClassName(ancestors, this.language);
      if (parentClassName) {
        finalName = `${parentClassName}.${name}`;
        parent = parentClassName;
      }
    }

    detectedSegments.push({
      name: finalName,
      type,
      startLine: startPosition.row,
      endLine: endPosition.row,
      content: "", // Will be filled later
      parent: parent,
      extends: extendsClass,
    });
  }

  /**
   * Check if constant should be excluded
   * @param {string} name - Constant name
   * @returns {boolean} True if should exclude
   */
  shouldExcludeConstant(name) {
    if (/^[a-z]$/.test(name)) return true;
    if (['i', 'j', 'k', 'idx', 'index', 'temp', 'tmp'].includes(name.toLowerCase())) return true;
    if (name.startsWith('_')) return true;
    if (name.length <= 2 && name !== name.toUpperCase()) return true;
    return false;
  }
}

// Static registry for language processors
TreeSitterExtractor.registry = new Map();

/**
 * Register a language processor
 * @param {string} language - Language identifier
 * @param {Function} processor - Processor function(node, ancestors, extractor)
 */
TreeSitterExtractor.register = function(language, processor) {
  TreeSitterExtractor.registry.set(language, processor);
};

/**
 * Get registered processor for language
 * @param {string} language - Language identifier
 * @returns {Function|null} Processor function or null
 */
TreeSitterExtractor.getProcessor = function(language) {
  return TreeSitterExtractor.registry.get(language) || null;
};

module.exports = {
  TreeSitterExtractor,
  // Export functions for compatibility
  getCurrentContext: () => currentContext,
  getDetectedSegments: () => detectedSegments,
  resetSegments: () => { detectedSegments = []; currentContext = null; }
};
